// simple_kernel_params

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"

__global__ void add(int a, int b, int* c) {
	*c = a + b;
}

int main() {
	int c;
	int* dev_c;
	// �����Դ�
	HANDLE_ERROR(cudaMalloc((void**)&dev_c, sizeof(int)));
	// �����C�����еĺ���һ�����ú˺���
	add <<<1, 1 >>> (2, 7, dev_c);
	// ��������ֱ�Ӷ�dev_c��ָ���Դ���������Ӧ�ø��ƻ������ڴ�
	HANDLE_ERROR(cudaMemcpy(&c, dev_c, sizeof(int), cudaMemcpyDeviceToHost));

	printf("2 + 7 = %d\n", c);
	// ���Ҫ�ͷ�֮ǰ������Դ�
	cudaFree(dev_c);

	return 0;
}