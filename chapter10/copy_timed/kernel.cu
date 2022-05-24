// copy_timed

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "../../common/book.h"

#include <stdio.h>

#define SIZE    (64*1024*1024)

float cuda_malloc_test(int size, bool up) {
    cudaEvent_t start, end;
    int *a, *dev_a;
    float elapsedTime;

    HANDLE_ERROR(cudaEventCreate(&start));
    HANDLE_ERROR(cudaEventCreate(&end));
    
    // ����������������GPU������
    a = (int*)malloc(size * sizeof(int));  // ʹ�ñ�׼C����malloc()������ɷ�ҳ�����ڴ�
    HANDLE_NULL(a);
    HANDLE_ERROR(cudaMalloc((void**)&dev_a, size * sizeof(int)));

    HANDLE_ERROR(cudaEventRecord(start, 0));
    // ִ��100�θ��Ʋ��������ɲ���upָ�����Ʒ���
    for (int i = 0; i < 100; i++) {
        if (up) {
            // cudaMemcpyHostToDevice
            HANDLE_ERROR(cudaMemcpy(dev_a, a, size * sizeof(int), cudaMemcpyHostToDevice));
        }else{
            // cudaMemcpyDeviceToHost
            HANDLE_ERROR(cudaMemcpy(a, dev_a, size * sizeof(int), cudaMemcpyDeviceToHost));
        }
    }
    HANDLE_ERROR(cudaEventRecord(end, 0));
    HANDLE_ERROR(cudaEventSynchronize(end));
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, end));

    free(a);
    HANDLE_ERROR(cudaFree(dev_a));
    HANDLE_ERROR(cudaEventDestroy(start));
    HANDLE_ERROR(cudaEventDestroy(end));

    return elapsedTime;
}

float cuda_host_alloc_test(int size, bool up) {
    cudaEvent_t start, end;
    int* a, * dev_a;
    float elapsedTime;

    HANDLE_ERROR(cudaEventCreate(&start));
    HANDLE_ERROR(cudaEventCreate(&end));

    // ����������������GPU������
    HANDLE_ERROR(cudaHostAlloc((void**)&a, size * sizeof(int), cudaHostAllocDefault));  // ʹ��cudaHostAlloc()������̶��ڴ�
    HANDLE_NULL(a);
    HANDLE_ERROR(cudaMalloc((void**)&dev_a, size * sizeof(int)));

    HANDLE_ERROR(cudaEventRecord(start, 0));
    // ִ��100�θ��Ʋ��������ɲ���upָ�����Ʒ���
    for (int i = 0; i < 100; i++) {
        if (up) {
            // cudaMemcpyHostToDevice
            HANDLE_ERROR(cudaMemcpy(dev_a, a, size * sizeof(int), cudaMemcpyHostToDevice));
        }
        else {
            // cudaMemcpyDeviceToHost
            HANDLE_ERROR(cudaMemcpy(a, dev_a, size * sizeof(int), cudaMemcpyDeviceToHost));
        }
    }
    HANDLE_ERROR(cudaEventRecord(end, 0));
    HANDLE_ERROR(cudaEventSynchronize(end));
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, end));

    HANDLE_ERROR(cudaFreeHost(a));  // ʹ��cudaFreeHost()�ͷ���cudaHostAlloc()������ڴ�
    HANDLE_ERROR(cudaFree(dev_a));
    HANDLE_ERROR(cudaEventDestroy(start));
    HANDLE_ERROR(cudaEventDestroy(end));

    return elapsedTime;
}

int main() {
    float elapsedTime;
    float MB = (float)100 * SIZE * sizeof(int) / 1024 / 1024;

    // ���Դ�Host��Device�ĸ�������(ʹ��malloc������ڴ�)
    elapsedTime = cuda_malloc_test(SIZE, true);
    printf("Time using malloc: %3.1f ms\n", elapsedTime);
    printf("\tMB/s during copy up: %3.1f\n", MB / (elapsedTime / 1000));

    // ���Դ�Device��Host�ĸ�������(ʹ��malloc������ڴ�)
    elapsedTime = cuda_malloc_test(SIZE, false);
    printf("Time using malloc: %3.1f ms\n", elapsedTime);
    printf("\tMB/s during copy down: %3.1f\n", MB / (elapsedTime / 1000));

    // ���Դ�Host��Device�ĸ�������(ʹ��cudaHostAlloc������ڴ�)
    elapsedTime = cuda_host_alloc_test(SIZE, true);
    printf("Time using cudaHostAlloc: %3.1f ms\n", elapsedTime);
    printf("\tMB/s during copy up: %3.1f\n", MB / (elapsedTime / 1000));

    // ���Դ�Device��Host�ĸ�������(ʹ��cudaHostAlloc������ڴ�)
    elapsedTime = cuda_host_alloc_test(SIZE, false);
    printf("Time using cudaHostAlloc: %3.1f ms\n", elapsedTime);
    printf("\tMB/s during copy down: %3.1f\n", MB / (elapsedTime / 1000));


    return 0;
}