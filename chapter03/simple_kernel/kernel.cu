//simple_kernel

#include <stdio.h>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

__global__ void kernel() {
}

int main() {
	kernel <<<1, 1>>> ();// �����C�����еĺ���һ�����ú˺���
	printf("hello world!\n");

	return 0;
}