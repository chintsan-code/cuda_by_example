// hist_gpu_gmem_atomics

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "../../common/book.h"

#include <stdio.h>

#define SIZE (100*1024*1024)

__global__ void histo_kernel(unsigned char* buffer,
                             long size, 
                             unsigned int* histo) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    while (tid < size) {
        // ��ʾ��CUDA C��ʹ��ԭ�Ӳ����ķ�ʽ����������atomicAdd(address, val)
        // ������һ��ԭ�ӵ����в���������������а�����ȡ��ַaddress����ֵ����val���ӵ����ֵ�ϣ�
        // �Լ����������ص�ַaddress���ײ�Ӳ����ȷ����ִ����Щ����ʱ��
        // �����κ��̶߳������ȡ��д���ַaddress�ϵ�ֵ����������ȷ���õ�Ԥ�ƵĽ����
        atomicAdd(&(histo[buffer[tid]]), 1);
        tid += stride;
    }
}

int main() {
    // �������100MB���������
    unsigned char* buffer = (unsigned char*)big_random_block(SIZE);

    // ��ʼ����ʱ�¼�
    cudaEvent_t start, end;
    HANDLE_ERROR(cudaEventCreate(&start));
    HANDLE_ERROR(cudaEventCreate(&end));
    HANDLE_ERROR(cudaEventRecord(start, 0));

    // ��GPU��Ϊ�ļ������ݷ����ڴ�
    unsigned char* dev_buffer;
    unsigned int* dev_histo;
    HANDLE_ERROR(cudaMalloc((void**)&dev_buffer, SIZE * sizeof(char)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_histo, 256 * sizeof(int)));
    HANDLE_ERROR(cudaMemcpy(dev_buffer, buffer, SIZE * sizeof(char), cudaMemcpyHostToDevice));
    HANDLE_ERROR(cudaMemset(dev_histo, 0, 256 * sizeof(int)));

    cudaDeviceProp prop;
    HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
    int blocks = prop.multiProcessorCount * 2; // ��Block����������ΪGPU�д�����������2��
    histo_kernel<<<blocks, 256>>>(dev_buffer, SIZE, dev_histo);

    unsigned int histo[256];
    HANDLE_ERROR(cudaMemcpy(histo, dev_histo, 256 * sizeof(int), cudaMemcpyDeviceToHost));

    // �õ�ֹͣʱ�䲢��ʾ��ʱ���
    HANDLE_ERROR(cudaEventRecord(end, 0));
    HANDLE_ERROR(cudaEventSynchronize(end));
    float elapsedTime;
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, end));
    printf("Time to generate:  %3.1f ms\n", elapsedTime);

    // ��ֱ֤��ͼ������Ԫ�ؼ������Ƿ������ȷ��ֵ(Ӧ�õ���SIZE)
    long histoCount = 0;
    for (int i = 0; i < 256; i++) {
        histoCount += histo[i];
    }
    printf("Histogram Sum:  %ld\n", histoCount);

    // ��֤��CPU�õ�������ͬ�ļ���ֵ
    for (int i = 0; i < SIZE; i++) {
        histo[buffer[i]]--;
    }
    for (int i = 0; i < 256; i++) {
        if (histo[i] != 0) {
            printf("Failure at %d!  Off by %d\n", i, histo[i]);
        }
    }

    // �ͷ��¼����ڴ�
    HANDLE_ERROR(cudaEventDestroy(start));
    HANDLE_ERROR(cudaEventDestroy(end));
    HANDLE_ERROR(cudaFree(dev_buffer));
    HANDLE_ERROR(cudaFree(dev_histo));
    free(buffer);

    return 0;
}