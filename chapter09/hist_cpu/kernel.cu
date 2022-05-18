// hist_cpu

#include "../../common/book.h"
#include "time.h"

#define SIZE (100*1024*1024)

int main() {
    // �������100MB���������
    unsigned char* buffer = (unsigned char*)big_random_block(SIZE);
    // ÿ���ֽڵ�ȡֵ��ΧΪ0x00-0xFF,���ʹ�ô�СΪ256���������洢��Ӧ��ֵ��buffer�г��ֵĴ���,
    // ���ڼ���ֱ��ͼ
    unsigned int histo[256] = { 0 };
    // ����ʱ��
    clock_t start, stop;
    start = clock();
    for (int i = 0; i < SIZE; i++) {
        histo[buffer[i]]++;
    }
    stop = clock();
    float elapsedTime = (float)(stop - start) / (float)CLOCKS_PER_SEC * 1000.0f;
    printf("Time to generate:  %3.1f ms\n", elapsedTime);
    // ��ֱ֤��ͼ������Ԫ�ؼ������Ƿ������ȷ��ֵ(Ӧ�õ���SIZE)
    long histoCount = 0;
    for (int i = 0; i < 256; i++) {
        histoCount += histo[i];
    }
    printf("Histogram Sum:  %ld\n", histoCount);

    // �ͷ��ڴ�
    free(buffer);

    return 0;
}