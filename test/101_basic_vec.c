#include <riscv_vector.h>
#include <stdio.h>

int main() {
    // 定义向量长度
    size_t vl = 4;
    int a[4]={1,2,3,4};
    //int32_t LMUL = 1
    vint32m1_t va=vle32_v_i32m1(a, vl);
    return 0;
}
