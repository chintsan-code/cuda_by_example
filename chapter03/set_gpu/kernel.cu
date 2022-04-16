// set_gpu

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "../../common/book.h"

int main()
{
    cudaDeviceProp prop;
    int dev;

    HANDLE_ERROR(cudaGetDevice(&dev));
    printf("ID of current CUDA device:  %d\n", dev);

    memset(&prop, 0, sizeof(cudaDeviceProp));
    prop.major = 1;//����ѡ������������>1.3
    prop.minor = 3;
    HANDLE_ERROR(cudaChooseDevice(&dev, &prop));//������ƥ����豸id(�������豸��û�ﵽ������Ҳ�᷵��һ����ƥ���)
    printf("ID of CUDA device closest to revision 1.3:  %d\n", dev);

    HANDLE_ERROR(cudaSetDevice(dev));//����GPU�豸��֮�����е��豸���������ڴ��豸��ִ��

    return 0;
}
