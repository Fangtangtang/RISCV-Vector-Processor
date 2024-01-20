// 纯mask register
#include <riscv_vector.h>
#include <stdio.h>

int main() {
    // 定义向量长度
    size_t vl = 4;
    uint8_t mask[4] = {1,0,1,0};
    vbool32_t vmask = vlm_v_b32(mask,vl);
    return 0;
}
