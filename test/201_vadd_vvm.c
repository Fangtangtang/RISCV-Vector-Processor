/*
    vd = vop(mask, maskedoff, arg1, arg2)
    vd[i] = maskedoff[i], if mask[i] == 0
    vd[i] = vop(arg1[i], arg2[2]), if mask[i] == 1
*/
#include <riscv_vector.h>
#include <stdio.h>

void vec_add_rvv(vbool32_t *mask,vint32m1_t *maskedoff,vint32m1_t *a, vint32m1_t *b, vint32m1_t *c, size_t vl) {
    *c = vadd_vv_i32m1_m(*mask,*maskedoff,*a, *b, vl);
}

int main() {
    // 定义向量长度
    size_t vl = 4;
    int a[4]={1,2,3,4};
    int b[4]={5,6,7,8};
    int m[4]={1,1,1,1}; // 当前位未激活时取值
    uint8_t ma[4] = {1,0,1,0};

    vint32m1_t va = vle32_v_i32m1(a, vl);
    vint32m1_t vb = vle32_v_i32m1(b, vl);
    vint32m1_t maskedoff = vle32_v_i32m1(m, vl);
    vbool32_t mask = vlm_v_b32(ma,vl);
    vint32m1_t c;

    // 执行向量加法操作
    vec_add_rvv(&mask,&maskedoff,&va, &vb, &c, vl);

    return 0;
}