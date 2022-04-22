// dot

#ifdef __INTELLISENSE__

// in here put whatever is your favorite flavor of intellisense workarounds
void __syncthreads(void);

#endif

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"

#define imin(a,b) (a<b?a:b)
#define sum_squares(x)  (x*(x+1)*(2*x+1)/6)

// Ĭ������32��Block��ÿ��Block����256��Thread
// ��NС��8192ʱ�����������ͻ����Thread���˷ѣ���Ҫ����������Block������
// ��NС�ڻ����8192ʱ��ÿ��Thread����һ��ʸ��Ԫ�أ���N����8192ʱ������Thread������ʸ��Ԫ��
const int N = 33 * 1024;
const int threadsPerBlock = 256;
const int blocksPerGrid = imin(32, (N + threadsPerBlock - 1) / threadsPerBlock);

__global__ void dot(float* a, float* b, float* c) {
    __shared__ float cache[threadsPerBlock];  // ʹ�ùؼ���__shared__����һ������פ���ڹ����ڴ���
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    int cacheIndex = threadIdx.x;

    float temp = 0;
    while (tid < N) {
        // һ��Thread��Ҫ������ʸ��Ԫ�صĳ˻�
        temp += a[tid] * b[tid];
        tid += blockDim.x * gridDim.x;
    }
    // cache����ӦthreadIdx��Thread�����Ķ��ʸ��Ԫ�صĳ˻��ۼ�����
    cache[cacheIndex] = temp;

    // ��Block�е�Thread����ͬ��
    __syncthreads();

    // ��Լ(Reduction)�㷨���
    // ���ڹ�Լ������˵�����´���Ҫ��threadsPerBlock������2�ı���
    int i = blockDim.x / 2;
    while (i != 0) {
        if (cacheIndex < i)
            cache[cacheIndex] += cache[cacheIndex + i];
        __syncthreads();
        i /= 2;
    }

    if (cacheIndex == 0)
        c[blockIdx.x] = cache[0];
}

int main() {
    float *a, *b, *partial_c;
    float *dev_a, *dev_b, *dev_partial_c;
    float c;

    a = (float*)malloc(N * sizeof(float));
    b = (float*)malloc(N * sizeof(float));
    partial_c = (float*)malloc(blocksPerGrid * sizeof(float));

    HANDLE_ERROR(cudaMalloc((void**)&dev_a, N * sizeof(float)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_b, N * sizeof(float)));
    HANDLE_ERROR(cudaMalloc((void**)&dev_partial_c, blocksPerGrid * sizeof(float)));

    // ������ʸ����ʼ��Ϊ��������У�����֮��ʹ��ƽ����������͹�ʽ��֤
    for (int i = 0; i < N; i++) {
        a[i] = i;
        b[i] = i * 2;
    }

    HANDLE_ERROR(cudaMemcpy(dev_a, a, N * sizeof(float), cudaMemcpyHostToDevice));
    HANDLE_ERROR(cudaMemcpy(dev_b, b, N * sizeof(float), cudaMemcpyHostToDevice));

    dot<<<blocksPerGrid, threadsPerBlock>>>(dev_a, dev_b, dev_partial_c);

    HANDLE_ERROR(cudaMemcpy(partial_c, dev_partial_c, blocksPerGrid * sizeof(float), cudaMemcpyDeviceToHost));

    // ��CPU��������յ��������
    c = 0;
    for (int i = 0; i < blocksPerGrid; i++)
    {
        c += partial_c[i];  // partial_c[i]���ǵ�i��Block���ص�Ԫ�س˻�֮�ͣ�һ����blocksPerGrid��Block�������Ǽ������õ����ս��
    }

    // ��֤�����Ӧ���빫ʽ����Ľ��һ��
    printf("Does GPU value %.6g = %.6g?\n", c, 2 * sum_squares((float)(N - 1)));

    HANDLE_ERROR(cudaFree(dev_a));
    HANDLE_ERROR(cudaFree(dev_b));
    HANDLE_ERROR(cudaFree(dev_partial_c));

    free(a);
    free(b);
    free(partial_c);

    return 0;
}