
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"
#include "../../common/cpu_anim.h"

#define DIM 1024
#define PI 3.1415926535897932f

__global__ void kernel(unsigned char* ptr, int ticks) {
    // ��threadIdx/blockIdxӳ�䵽����λ��
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int offset = y * blockDim.x * gridDim.x + x;

    // ����Ĵ����붯���йأ����ù���
    float fx = x - DIM / 2;
    float fy = y - DIM / 2;
    float d = sqrtf(fx * fx + fy * fy);
    unsigned char grey = (unsigned char)(128.0f + 127.0f *
                                         cos(d / 10.0f - ticks / 7.0f) /
                                         (d / 10.0f + 1.0f));
    ptr[offset * 4 + 0] = grey;
    ptr[offset * 4 + 1] = grey;
    ptr[offset * 4 + 2] = grey;
    ptr[offset * 4 + 3] = 255;

}

struct DataBlock
{
    unsigned char* dev_bitmap;
    CPUAnimBitmap* bitmap;
};

void generate_frame(DataBlock* d, int ticks) {
    // (DIM/16, DIM/16)��Block���һ��Grid
    // ÿ��Block����(16, 16)��Thread
    // ����һ����(DIM, DIM)��Thread����ӦDIM*DIM�ߴ��ͼ��ÿһ��������һ��Thread����
    dim3 blocks(DIM / 16, DIM / 16);
    dim3 threads(16, 16);
    kernel<<<blocks, threads>>>(d->dev_bitmap, ticks);

    HANDLE_ERROR(cudaMemcpy(d->bitmap->get_ptr(),
                            d->dev_bitmap,
                            d->bitmap->image_size(),
                            cudaMemcpyDeviceToHost));
}

// �ͷ���GPU�Ϸ�����Դ�
void cleanup(DataBlock* d) {
    HANDLE_ERROR(cudaFree(d->dev_bitmap));
}

int main() {
    DataBlock data;
    CPUAnimBitmap bitmap(DIM, DIM, &data);
    data.bitmap = &bitmap;

    HANDLE_ERROR(cudaMalloc((void**)&data.dev_bitmap, bitmap.image_size()));

    // ÿ������һ֡ͼ�񣬵���һ��generate_frame��֮�󽫷�����Դ��ͷŵ�
    bitmap.anim_and_exit((void(*)(void*, int))generate_frame,
                         (void(*)(void*))cleanup);

    return 0;
}