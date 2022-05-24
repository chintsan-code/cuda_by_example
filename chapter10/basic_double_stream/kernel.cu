// basic_double_stream

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

    // ��ʼ����
    cudaStream_t stream0, stream1;
    HANDLE_ERROR(cudaStreamCreate(&stream0));
    HANDLE_ERROR(cudaStreamCreate(&stream1));

    int* host_a, * host_b, * host_c;
    int* dev_a0, * dev_b0, * dev_c0;  // Ϊstream0�����GPU�ڴ�
    int* dev_a1, * dev_b1, * dev_c1;  // Ϊstream1�����GPU�ڴ�

    // ��GPU�Ϸ����ڴ�
    HANDLE_ERROR(cudaMalloc((void**)&dev_a0, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_b0, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_c0, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_a1, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_b1, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_c1, N * sizeof(int)));

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
    for (int offset = 0; offset < FULL_DATA_SIZE; offset+=N*2) {  // ��2���������ÿ��ѭ����ƫ��2N
        // ��Page-Locked Memory���첽��ʽ���Ƶ�Device��
        // ��һ�θ���(stream0)
        HANDLE_ERROR(cudaMemcpyAsync(dev_a0,
                                     host_a + offset,
                                     N * sizeof(int),
                                     cudaMemcpyHostToDevice,
                                     stream0));
        // �ڶ��θ���(stream0)
        HANDLE_ERROR(cudaMemcpyAsync(dev_b0,
                                     host_b + offset,
                                     N * sizeof(int),
                                     cudaMemcpyHostToDevice,
                                     stream0));
        // ִ�к˺���
        kernel<<<N / 256, 256, 0, stream0>>>(dev_a0, dev_b0, dev_c0);

        // �����ݴ�Device���ƻ�Page-Locked Memory
        HANDLE_ERROR(cudaMemcpyAsync(host_c + offset,
                                     dev_c0,
                                     N * sizeof(int),
                                     cudaMemcpyDeviceToHost,
                                     stream0));

        // �����θ���(stream1)
        HANDLE_ERROR(cudaMemcpyAsync(dev_a1,
                                     host_a + offset + N,
                                     N * sizeof(int),
                                     cudaMemcpyHostToDevice,
                                     stream1));
       
        // ���Ĵθ���(stream1)
        HANDLE_ERROR(cudaMemcpyAsync(dev_b1,
                                     host_b + offset + N,
                                     N * sizeof(int),
                                     cudaMemcpyHostToDevice,
                                     stream1));

        // ִ�к˺���
        kernel<<<N / 256, 256, 0, stream1>>>(dev_a1, dev_b1, dev_c1);

        // �����ݴ�Device���ƻ�Page-Locked Memory
        HANDLE_ERROR(cudaMemcpyAsync(host_c + offset + N,
                                     dev_c1,
                                     N * sizeof(int),
                                     cudaMemcpyDeviceToHost,
                                     stream1));
    }
    // ��������ͬ��
    HANDLE_ERROR(cudaStreamSynchronize(stream0));
    HANDLE_ERROR(cudaStreamSynchronize(stream1));

    HANDLE_ERROR(cudaEventRecord(end, 0));
    HANDLE_ERROR(cudaEventSynchronize(end));
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, end));
    printf("Time taken: %3.1f ms\n", elapsedTime);

    HANDLE_ERROR(cudaFreeHost(host_a));
    HANDLE_ERROR(cudaFreeHost(host_b));
    HANDLE_ERROR(cudaFreeHost(host_c));
    HANDLE_ERROR(cudaFree(dev_a0));
    HANDLE_ERROR(cudaFree(dev_b0));
    HANDLE_ERROR(cudaFree(dev_c0));
    HANDLE_ERROR(cudaFree(dev_a1));
    HANDLE_ERROR(cudaFree(dev_b1));
    HANDLE_ERROR(cudaFree(dev_c1));
    HANDLE_ERROR(cudaEventDestroy(start));
    HANDLE_ERROR(cudaEventDestroy(end));
    HANDLE_ERROR(cudaStreamDestroy(stream0));  // �ͷ���
    HANDLE_ERROR(cudaStreamDestroy(stream1));

	return 0;
}