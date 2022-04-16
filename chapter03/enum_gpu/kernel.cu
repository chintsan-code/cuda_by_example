// enum_gpu

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"

int main() {
    cudaDeviceProp prop;

    int count;
    // ��ȡCUDA�豸������
    HANDLE_ERROR(cudaGetDeviceCount(&count));
    for (int i = 0; i < count; i++) {
        HANDLE_ERROR(cudaGetDeviceProperties(&prop, i));
        // �豸���
        printf("   --- General Information for device %d ---\n", i);
        // ��ʶ�豸��ASCII�ַ���
        printf("Name:  %s\n", prop.name);
        // �豸������
        printf("Compute capability:  %d.%d\n", prop.major, prop.minor);
        // ʱ��Ƶ��(��λ: kHz)
        printf("Clock rate:  %d\n", prop.clockRate);
        // �豸�Ƿ����ͬʱ�����ڴ沢ִ���ں�
        printf("Device copy overlap:  ");
        if (prop.deviceOverlap)
            printf("Enabled\n");
        else
            printf("Disabled\n");
        // ָ���ں��Ƿ�������ʱ������
        printf("Kernel execution timeout :  ");
        if (prop.kernelExecTimeoutEnabled)
            printf("Enabled\n");
        else
            printf("Disabled\n");

        printf("   --- Memory Information for device %d ---\n", i);
        // �豸�Ͽ��õ�ȫ���ڴ�(��λ: byte)
        printf("Total global mem:  %ld\n", prop.totalGlobalMem);
        // �豸�Ͽ��õĺ㶨�ڴ�(��λ: byte)
        printf("Total constant Mem:  %ld\n", prop.totalConstMem);
        // ���ڴ渴�Ƶ�����������(��λ: byte)
        printf("Max mem pitch:  %ld\n", prop.memPitch);
        // ����Ķ���Ҫ��
        printf("Texture Alignment:  %ld\n", prop.textureAlignment);

        printf("   --- MP Information for device %d ---\n", i);
        // �豸�ϵĶദ��������
        printf("Multiprocessor count:  %d\n", prop.multiProcessorCount);
        // ÿ���߳̿�(Block)���õĹ����ڴ�(��λ: byte)
        printf("Shared mem per mp:  %ld\n", prop.sharedMemPerBlock);
        // ÿ���߳̿�(Block)����32λ�Ĵ���
        printf("Registers per mp:  %d\n", prop.regsPerBlock);
        // ��һ���߳���(Warp)�а������߳�����
        printf("Threads in warp:  %d\n", prop.warpSize);
        // ÿһ���߳̿�(Block)�ɰ���������߳�����
        printf("Max threads per block:  %d\n", prop.maxThreadsPerBlock);
        // �ڶ�ά�߳̿�(Block)�����У�ÿһά���԰������߳̿�����
        printf("Max thread dimensions:  (%d, %d, %d)\n",
            prop.maxThreadsDim[0],
            prop.maxThreadsDim[1],
            prop.maxThreadsDim[2]);
        // ��ÿһ���̸߳�(Grid)�У�ÿһά���԰������߳̿�(Block)����
        printf("Max grid dimensions:  (%d, %d, %d)\n",
            prop.maxGridSize[0],
            prop.maxGridSize[1],
            prop.maxGridSize[2]);

        printf("\n");
    }

    return 0;
}
