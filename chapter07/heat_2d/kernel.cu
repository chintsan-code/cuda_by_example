// heat_2d

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"
#include "../../common/cpu_anim.h"

#define DIM 1024
#define MAX_TEMP 1.0f
#define MIN_TEMP 0.0001f
#define SPEED   0.25f

// �����������ã���Щ������λ��GPU��
texture<float, 2>  texConstSrc;
texture<float, 2>  texIn;
texture<float, 2>  texOut;

__global__ void copy_const_kernel(float* iptr) {
    // ��threadIdx/BlockIdxӳ�䵽����λ��
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int offset = y * gridDim.x * blockDim.x + x;

    // ���¶Ȳ�Ϊ0ʱ���Ż�ִ�и��ơ�����Ϊ��ά�ַ���Դ��λ����һ�μ���õ����¶�ֵ
    float center = tex2D(texConstSrc, x, y);
    if (center != 0)
        iptr[offset] = center;
}

__global__ void blend_kernel(float* dst, bool dstOut) {
    // ��threadIdx/BlockIdxӳ�䵽����λ��
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int offset = y * gridDim.x * blockDim.x + x;

    float t, l, c, r, b;
    if (dstOut) {
        t = tex2D(texIn, x, y - 1); // top
        l = tex2D(texIn, x - 1, y); // left
        c = tex2D(texIn, x, y);     // center
        r = tex2D(texIn, x + 1, y); // right
        b = tex2D(texIn, x, y + 1); // bottom
    }
    else {
        t = tex2D(texOut, x, y - 1);
        l = tex2D(texOut, x - 1, y);
        c = tex2D(texOut, x, y);
        r = tex2D(texOut, x + 1, y);
        b = tex2D(texOut, x, y + 1);
    }
    // ���¹�ʽ��T_new = T_old + k * sum(T_neighbor - T_old)
    dst[offset] = c + SPEED * (t + b + l + r - 4 * c);
}

// ���º�������Ҫ��ȫ�ֱ���
struct DataBlock
{
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
    // ����tex��ȫ�ֲ������н�ģ������Ҫͨ��һ����ʶ��ѡ��
    // ÿ�ε������ĸ�������/���
    volatile bool dstOut = true;
    for (int i = 0; i < 90; i++) {
        float* in, * out;
        if (dstOut) {
            in = data->dev_inSrc;
            out = data->dev_outSrc;
        }
        else {
            in = data->dev_outSrc;
            out = data->dev_inSrc;
        }

        // Ϊ�˼򵥣���Դ��Ԫ������¶Ƚ����ֲ��䡣���ǣ��������ԴӸ��ȵĵ�Ԫ����������ĵ�Ԫ
        copy_const_kernel<<<blocks, threads>>>(in);
        // ����ÿһ����Ԫ
        blend_kernel<<<blocks, threads>>>(out, dstOut);
        // ������������룬�����μ���������Ϊ�´μ��������
        dstOut = !dstOut;
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
    // ȡ�������ڴ�İ�
    HANDLE_ERROR(cudaUnbindTexture(texConstSrc));
    HANDLE_ERROR(cudaUnbindTexture(texIn));
    HANDLE_ERROR(cudaUnbindTexture(texOut));

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

    // �������ڴ�󶨵�֮ǰ����������Ӧ��
    cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();
    HANDLE_ERROR(cudaBindTexture2D(NULL, texConstSrc, data.dev_constSrc, desc, DIM, DIM, sizeof(float) * DIM));
    HANDLE_ERROR(cudaBindTexture2D(NULL, texIn, data.dev_inSrc, desc, DIM, DIM, sizeof(float) * DIM));
    HANDLE_ERROR(cudaBindTexture2D(NULL, texOut, data.dev_outSrc, desc, DIM, DIM, sizeof(float) * DIM));

    float* temp = (float*)malloc(bitmap.image_size());
    // �������һЩ��Դ
    for (int i = 0; i < DIM * DIM; i++) {
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