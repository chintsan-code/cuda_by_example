// add_loop_long_blocks

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"

#define N (33*1024)  // ��ô���N�����ֻ��һ��Block�������˵�

__global__ void add(int* a, int* b, int* c) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid < N) {
        c[tid] = a[tid] + b[tid];
    }
}

// ��N�ܴ�ʱҪ�޸���Ŀ����->��������->������->ϵͳ->��ջ������С(��λ: byte)
// ���߷�����ȫ���������
// int a[N], b[N], c[N];  // ������ȫ����
int main() {
    //int a[N], b[N], c[N];  // ������ջ��
    int* a, * b, * c;
    a = (int*)malloc(N * sizeof(int));  // �����ڶ��������ǵ�Ҫ�ͷ�
    b = (int*)malloc(N * sizeof(int));
    c = (int*)malloc(N * sizeof(int));

    int* dev_a, * dev_b, * dev_c;

    HANDLE_ERROR(cudaMalloc((void**)&dev_a, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_b, N * sizeof(int)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_c, N * sizeof(int)));

    for (int i = 0; i < N; i++)
    {
        a[i] = -i;
        b[i] = i * i;
    }

    HANDLE_ERROR(cudaMemcpy(dev_a, a, N * sizeof(int), cudaMemcpyHostToDevice));
    HANDLE_ERROR(cudaMemcpy(dev_b, b, N * sizeof(int), cudaMemcpyHostToDevice));

    // (127 + N) / 128 : N/128����ȡ��
    // ÿ��Block��128��Thread
    // ע��( N + 127 ) / 128���ܳ���maxGridSize������
    add<<<(127 + N) / 128, 128>>>(dev_a, dev_b, dev_c);  

    HANDLE_ERROR(cudaMemcpy(c, dev_c, sizeof(int) * N, cudaMemcpyDeviceToHost));

    for (int i = 0; i < N; i++)
    {
        printf("%d + %d = %d\n", a[i], b[i], c[i]);
    }

    HANDLE_ERROR(cudaFree(dev_a));
    HANDLE_ERROR(cudaFree(dev_b));
    HANDLE_ERROR(cudaFree(dev_c));

    free(a);  // �ͷ�֮ǰ����Ķ����ڴ�
    free(b);
    free(c);

    return 0;
}