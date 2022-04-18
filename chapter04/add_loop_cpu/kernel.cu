//add_loop_cpu

#include <stdio.h>

#define N 10

void add(int* a, int* b, int* c)
{
    int tid = 0;  // ���ǵ�0��CPU�����������0��ʼ
    while (tid < N)
    {
        c[tid] = a[tid] + b[tid];
        tid += 1;  // ��������ֻ��һ��CPU�����ÿ�ε���1
    }
}

int main()
{
    int a[N], b[N], c[N];

    // ��ʼ����������
    for (int i = 0; i < N; i++)
    {
        a[i] = -i;
        b[i] = i * i;
    }
    add(a, b, c);
    // ��ӡ���
    for (int i = 0; i < N; i++)
    {
        printf("%d + %d = %d\n", a[i], b[i], c[i]);
    }

    return 0;
}