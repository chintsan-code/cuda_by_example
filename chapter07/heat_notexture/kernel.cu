// heat_notexture

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"
#include "../../common/cpu_anim.h"

#define DIM 1024
#define MAX_TEMP 1.0f
#define MIN_TEMP 0.0001f
#define SPEED   0.25f

__global__ void copy_const_kernel(float* iptr, const float* cptr) {
    // ��threadIdx/BlockIdxӳ�䵽����λ��
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int offset = y * gridDim.x * blockDim.x + x;

    // ���¶Ȳ�Ϊ0ʱ���Ż�ִ�и��ơ�����Ϊ��ά�ַ���Դ��λ����һ�μ���õ����¶�ֵ
    if (cptr[offset] != 0)
        iptr[offset] = cptr[offset];
}

__global__ void blend_kernel(float* outSrc, const float* inSrc) {
    // ��threadIdx/BlockIdxӳ�䵽����λ��
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int offset = y * gridDim.x * blockDim.x + x;

    // ÿ��Thread���������һ����Ԫ(һ������)����ȡ��Ӧ��Ԫ�������ڵ�Ԫ���¶�ֵ��
    // Ȼ��ִ�и������㣬���õ�����ֵ���µ���Ӧ�ĵ�Ԫ��
    int left = offset - 1;
    int right = offset + 1;
    if (x == 0)
        left++;  // ��Ե������ͬ
    if (x == DIM - 1)
        right--;

    int top = offset - DIM;
    int bottom = offset + DIM;
    if (y == 0)
        top += DIM;
    if (y == DIM - 1)
        bottom -= DIM;

    // ���¹�ʽ��T_new = T_old + k * sum(T_neighbor - T_old)
    outSrc[offset] = inSrc[offset] + SPEED * (inSrc[left] + inSrc[right] 
                                            + inSrc[top] + inSrc[bottom]
                                            - inSrc[offset] * 4);
}

// ���º�������Ҫ��ȫ�ֱ���
struct DataBlock{
    unsigned char* dev_bitmap;
    float* dev_inSrc;  // ���뻺����
    float* dev_outSrc;  // ���������
    float* dev_constSrc;  // ��ʼ������Դ
    CPUAnimBitmap* bitmap;

    cudaEvent_t start, stop;
    float totalTime;
    float frames;
};

// ÿһ֡����������anim_gpu()
void anim_gpu(DataBlock* data, int ticks) {
    HANDLE_ERROR(cudaEventRecord(data->start, 0));
    
    // ÿ��Block��(16, 16)��Thread��(DIM/16, DIM/16)��֯��һ��Grid
    dim3 blocks(DIM / 16, DIM / 16);
    dim3 threads(16, 16);
    CPUAnimBitmap* bitmap = data->bitmap;
    
    // ÿһ֡������������90�ֵ������㣬�����޸����ֵ
    for (int i = 0; i < 90; i++) {
        // Ϊ�˼򵥣���Դ��Ԫ������¶Ƚ����ֲ��䡣���ǣ��������ԴӸ��ȵĵ�Ԫ����������ĵ�Ԫ
        copy_const_kernel<<<blocks, threads>>>(data->dev_inSrc, data->dev_constSrc);
        // ����ÿһ����Ԫ
        blend_kernel<<<blocks, threads>>>(data->dev_outSrc, data->dev_inSrc);
        // ������������룬�����μ���������Ϊ�´μ��������
        swap(data->dev_inSrc, data->dev_outSrc);
    }

    // ���¶�תΪ��ɫ
    float_to_color<<<blocks, threads>>>(data->dev_bitmap, data->dev_inSrc);
    // ��������ƻ�CPU
    HANDLE_ERROR(cudaMemcpy(bitmap->get_ptr(),
                            data->dev_bitmap,
                            bitmap->image_size(),
                            cudaMemcpyDeviceToHost));

    HANDLE_ERROR(cudaEventRecord(data->stop, 0));
    HANDLE_ERROR(cudaEventSynchronize(data->stop));
    float elapsedTime;
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, data->start, data->stop));  // ����ÿһ֡������Ҫ��ʱ��

    data->totalTime += elapsedTime;
    data->frames++;
    printf("Average Time per frame:  %3.1f ms\n", data->totalTime / data->frames);
}

void anim_exit(DataBlock* data) {
    HANDLE_ERROR(cudaFree(data->dev_inSrc));
    HANDLE_ERROR(cudaFree(data->dev_outSrc));
    HANDLE_ERROR(cudaFree(data->dev_constSrc));

    HANDLE_ERROR(cudaEventDestroy(data->start));
    HANDLE_ERROR(cudaEventDestroy(data->stop));
}

int main() {
    DataBlock data;
    CPUAnimBitmap bitmap(DIM, DIM, &data);
    data.bitmap = &bitmap;
    data.totalTime = 0;
    data.frames = 0;

    HANDLE_ERROR(cudaEventCreate(&data.start));
    HANDLE_ERROR(cudaEventCreate(&data.stop));

    HANDLE_ERROR(cudaMalloc((void**)&data.dev_bitmap, bitmap.image_size()));

    // ����float���͵Ĵ�СΪ4���ַ�(��rgba)
    HANDLE_ERROR(cudaMalloc((void**)&data.dev_inSrc, bitmap.image_size()));
    HANDLE_ERROR(cudaMalloc((void**)&data.dev_outSrc, bitmap.image_size()));
    HANDLE_ERROR(cudaMalloc((void**)&data.dev_constSrc, bitmap.image_size()));

    float* temp = (float*)malloc(bitmap.image_size());
    // �������һЩ��Դ
    for (int i = 0; i < DIM*DIM; i++) {
        temp[i] = 0;
        int x = i % DIM;
        int y = i / DIM;
        if ((x > 300) && (x < 600) && (y > 310) && (y < 601))
            temp[i] = MAX_TEMP;
    }
    temp[DIM * 100 + 100] = (MAX_TEMP + MIN_TEMP) / 2;
    temp[DIM * 700 + 100] = MIN_TEMP;
    temp[DIM * 300 + 300] = MIN_TEMP;
    temp[DIM * 200 + 700] = MIN_TEMP;
    for (int y = 800; y < 900; y++) {
        for (int x = 400; x < 500; x++) {
            temp[x + y * DIM] = MIN_TEMP;
        }
    }
    HANDLE_ERROR(cudaMemcpy(data.dev_constSrc,
                            temp,
                            bitmap.image_size(),
                            cudaMemcpyHostToDevice));

    for (int y = 800; y < DIM; y++) {
        for (int x = 0; x < 200; x++) {
            temp[x + y * DIM] = MAX_TEMP;
        }
    }
    HANDLE_ERROR(cudaMemcpy(data.dev_inSrc, 
                            temp,
                            bitmap.image_size(),
                            cudaMemcpyHostToDevice));
    free(temp);
    // ÿ����Ҫ����һ֡ͼ�񣬾͵���һ��anim_gpu��֮���ٵ���anim_exit��������Դ��ͷŵ�
    bitmap.anim_and_exit((void (*)(void*, int))anim_gpu,
        (void (*)(void*))anim_exit);

    return 0;
}