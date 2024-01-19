#include <riscv_vector.h>
#include <stdio.h>

void vec_add_rvv(vint32m1_t *a, vint32m1_t *b, vint32m1_t *c, size_t vl) {
 *c = vadd_vv_i32m1(*a, *b, vl);
}

int main() {
    // 定义向量长度
    size_t vl = 4;
    int a[4]={1,2,3,4};
    int b[4]={5,6,7,8};
    vint32m1_t va = vle32_v_i32m1(a, vl);
    vint32m1_t vb = vle32_v_i32m1(b, vl);
    vint32m1_t c;

    // 执行向量加法操作
    vec_add_rvv(&va, &vb, &c, vl);

    return 0;
}
