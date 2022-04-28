// shared_bitmap

#ifdef __INTELLISENSE__

// in here put whatever is your favorite flavor of intellisense workarounds
void __syncthreads(void);

#endif

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "math.h"
#include "../../common/book.h"
#include "../../common/cpu_bitmap.h"

#define DIM 1024
#define PI 3.1415926535897932f

__global__ void kernel(unsigned char* ptr) {
    // ��threadIdx/blockIdxӳ�䵽����λ��
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int offset = y * gridDim.x * blockDim.x + x;

    // ����һ��������������ΪҪ��CUDA Runtime������block��(16,16)���̣߳����л�������СҲ����Ϊ16*16��
    // ��ÿ���߳��ڸû������ж���һ����Ӧ��λ��
    __shared__ float shared[16][16];

    // ���ڼ������λ���ϵĵ�ֵ
    const float period = 128.0f;
    
    shared[threadIdx.x][threadIdx.y] =
        255 * (sinf(x * 2.0f * PI / period) + 1.0f) *
        (sinf(y * 2.0f * PI / period) + 1.0f) / 4.0f;

    __syncthreads();
    // ��󣬰���Щֵ��������أ�����x��y�Ĵ���
    ptr[offset * 4 + 0] = 0;
    // ע�����������Ϊ(threadIdx.x, threadIdx.y)��Thread��ɶԻ�����shared��д���Ҫ�������
    // shared[15 - threadIdx.x][15 - threadIdx.y]���ж�ȡʱ��
    // ����Ϊ(15 - threadIdx.x, 15 - threadIdx.y)��Thread���ܻ�û��ɶԻ�����shared��д�룬
    // �����Ҫ��֮ǰ����__syncthreads();
    ptr[offset * 4 + 1] = shared[15 - threadIdx.x][15 - threadIdx.y];
    ptr[offset * 4 + 2] = 0;
    ptr[offset * 4 + 3] = 255;
}

int main() {
    CPUBitmap bitmap(DIM, DIM);
    unsigned char* dev_ptr;

    HANDLE_ERROR(cudaMalloc((void**)&dev_ptr, bitmap.image_size()));

    dim3 threads(16, 16);
    dim3 blocks(DIM / 16, DIM / 16);
    kernel<<<blocks, threads>>>(dev_ptr);
    
    HANDLE_ERROR(cudaMemcpy(bitmap.get_ptr(), dev_ptr, bitmap.image_size(), cudaMemcpyDeviceToHost));

    bitmap.display_and_exit();

    HANDLE_ERROR(cudaFree(dev_ptr));

    return 0;
}