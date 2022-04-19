// julia_cpu

#include <stdio.h>
#include "../../common/cpu_bitmap.h"

#define DIM 1000

struct cuComplex
{
    float r;  // ������ʵ������
    float i;  // ��������������

    cuComplex(float a, float b) :r(a), i(b) { }

    float magnitude2(void)
    {
        return r * r + i * i;  // ������ģ��ƽ��
    }

    cuComplex operator * (const cuComplex& a)
    {
        return cuComplex(r * a.r - i * a.i, i * a.r + r * a.i);
    }

    cuComplex operator + (const cuComplex& a)
    {
        return cuComplex(r + a.r, i + a.i);
    }
};

int julia(int x, int y)
{
    const float scale = 1.5;
    // DIM / 2 - x��DIM / 2 - y��ԭ�㶨λ��ͼ������
    // ����(DIM / 2)��Ϊ��ȷ��ͼ��ķ�ΧΪ[-1.0, 1.0]
    // scale����������ͼ��ģ����������޸�
    float jx = scale * (float)(DIM / 2 - x) / (DIM / 2);
    float jy = scale * (float)(DIM / 2 - y) / (DIM / 2);

    cuComplex c(-0.8, 0.156);  // ����C = -0.8 + 0.156i
    cuComplex z(jx, jy);

    int i = 0;
    for (i = 0; i < 200; i++)
    {
        z = z * z + c; //Zn+1 = Zn^2 + C
        if (z.magnitude2() > 1000)
        {
            // ����200�Σ�ÿ�ε����궼�жϽ���Ƿ񳬹���ֵ(������1000)����������Ͳ�����julia��
            return 0;
        }
    }
    return 1;  // ����Julia��
}

void kernel(unsigned char* ptr)
{
    for (int y = 0; y < DIM; y++)
    {
        for (int x = 0; x < DIM; x++)
        {
            int offset = x + y * DIM;  // �������ڴ��е�����ƫ�ƣ���Ϊͼ�����ڴ���ʵ����һά�洢��

            int juliaValue = julia(x, y);  // �жϵ�(x, y)�Ƿ�����Julia���ϣ����ڷ���1�������ڷ���0
            // juliaValueΪ0ʱΪ��ɫ(0,0,0)��Ϊ1ʱΪ��ɫ(255,0,0)
            ptr[offset * 4 + 0] = 255 * juliaValue; // redͨ��
            ptr[offset * 4 + 1] = 0;                // greenͨ��
            ptr[offset * 4 + 2] = 0;                // blueͨ��
            ptr[offset * 4 + 3] = 255;              // alphaͨ��
        }
    }
}

int main()
{
    CPUBitmap bitmap(DIM, DIM);
    unsigned char* ptr = bitmap.get_ptr();
    kernel(ptr);  // ��ָ��ͼ���ָ�봫�ݸ��˺���
    bitmap.display_and_exit();

    getchar();
    return 0;
}