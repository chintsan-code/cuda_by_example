// basic_single_stream

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "../../common/book.h"
#include <stdio.h>

#define N (1024*1024)
#define FULL_DATA_SIZE (N*20)

__global__ void kernel(int* a, int* b, int* c) {
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    if (id < N) {
        int id1 = (id + 1) % 256;
        int id2 = (id + 2) % 256;
        float as = (a[id] + a[id1] + a[id2]) / 3.0f;
        float bs = (b[id] + b[id1] + b[id2]) / 3.0f;
        c[id] = (as + bs) / 2;
    }
}

int main() {
    cudaDeviceProp prop;
    int whichDevice;
    HANDLE_ERROR(cudaGetDevice(&whichDevice));
    HANDLE_ERROR(cudaGetDeviceProperties(&prop, whichDevice));
    // ѡ��һ��֧���豸�ص�(Device Overlap)���ܵ��豸:
    // �ܹ���ִ��һ��CUDA C�˺�����ͬʱ���������豸������֮��ִ�и��Ʋ���
    if (!prop.deviceOverlap) {
        printf("Device will not handle overlaps, so no "
            "speed up from stream\n"); 
    }

    cudaEvent_t start, end;
    float elapsedTime;

    HANDLE_ERROR(cudaEventCreate(&start));
    HANDLE_ERROR(cudaEventCreate(&end));
    HANDLE_ERROR(cudaEventRecord(start, 0));

    // ��ʼ��Stream
    cudaStream_t stream;
    HANDLE_ERROR(cudaStreamCreate(&stream));

    int *host_a, *host_b, *host_c;
    int *dev_a, *dev_b, *dev_c;

    // ��GPU�Ϸ����ڴ�
    HANDLE_ERROR(cudaMalloc((void**)&dev_a, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_b, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_c, N * sizeof(int)));

    // ������Streamʹ�õ�Page-Locked�ڴ�
    HANDLE_ERROR(cudaHostAlloc((void**)&host_a,
                                FULL_DATA_SIZE * sizeof(int),
                                cudaHostAllocDefault));
    HANDLE_ERROR(cudaHostAlloc((void**)&host_b,
                                FULL_DATA_SIZE * sizeof(int),
                                cudaHostAllocDefault));
    HANDLE_ERROR(cudaHostAlloc((void**)&host_c,
                                FULL_DATA_SIZE * sizeof(int),
                                cudaHostAllocDefault));

    // ʹ�����������������ڴ�
    for (int i = 0; i < FULL_DATA_SIZE; i++) {
        host_a[i] = rand();
        host_b[i] = rand();
    }

    // ������������ѭ����ÿ�����ݿ�Ĵ�СΪN
    for (int offset = 0; offset < FULL_DATA_SIZE; offset +=N) {
        // ��Page-Locked Memory���첽��ʽ���Ƶ�Device��
        // ��һ�θ���
        HANDLE_ERROR(cudaMemcpyAsync(dev_a, 
                                host_a + offset,			// ����һ��ƫ��offset
                                N * sizeof(int), 
                                cudaMemcpyHostToDevice,
                                stream));					// �����stream�н��и���
        // �ڶ��θ���
        HANDLE_ERROR(cudaMemcpyAsync(dev_b,
                                host_b + offset, 
                                N * sizeof(int),
                                cudaMemcpyHostToDevice,
                                stream));

        kernel<<<N / 256, 256>>>(dev_a, dev_b, dev_c);
        
        // �����θ���
        // �����ݴ�Device���Ƶ�Page-Locked Memory
        HANDLE_ERROR(cudaMemcpyAsync(host_c + offset,
                                dev_c,
                                N * sizeof(int),
                                cudaMemcpyDeviceToHost,
                                stream));
    }

    // ����������ҳ�����ڴ渴�Ƶ������ڴ�
    HANDLE_ERROR(cudaStreamSynchronize(stream));

    HANDLE_ERROR(cudaEventRecord(end, 0));
    HANDLE_ERROR(cudaEventSynchronize(end));
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, end));

    HANDLE_ERROR(cudaFreeHost(host_a));
    HANDLE_ERROR(cudaFreeHost(host_b));
    HANDLE_ERROR(cudaFreeHost(host_c));
    HANDLE_ERROR(cudaFree(dev_a));
    HANDLE_ERROR(cudaFree(dev_b));
    HANDLE_ERROR(cudaFree(dev_c));
    HANDLE_ERROR(cudaEventDestroy(start));
    HANDLE_ERROR(cudaEventDestroy(end));
    HANDLE_ERROR(cudaStreamDestroy(stream));  // �ͷ���

    return 0;
}