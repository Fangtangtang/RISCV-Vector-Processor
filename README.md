# RISCV-Vector-Processor

## 简介
以支持更多RVV指令数量为探索方向，设计支持RISC-V Vector Extension Spec 1.0中部分指令的SIMD架构向量处理器。

## ISA

| ISNT TYPE | funct6 | funct3 | vs1  | vs2  |
| :-------: | :----: | :----: | :--: | :--: |
|  vadd.vv  | 000000 |        |      |      |
|  vsub.vv  | 000010 |        |      |      |
| vwaddu.vv | 110000 |        |      |      |
| vwsubu.vv | 110010 |        |      |      |
| vwadd.vv  | 110001 |        |      |      |
| vwsub.vv  | 110011 |        |      |      |
| vadc.vvm  | 010000 |        |      |      |
| vsbc.vvm  | 010010 |        |      |      |
|   vzext   |        |        |      |      |
|   vsext   |        |        |      |      |
| vmacc.vv  | 101101 |        |      |      |
| vnmsac.vv | 101111 |        |      |      |
| vmadd.vv  | 101001 |        |      |      |



### Vector Integer Add\Subtract
#### Integer add
```
vadd.vv vd, vs2, vs1, vm # Vector-vector
```

#### Integer subtract
```
vsub.vv vd, vs2, vs1, vm # Vector-vector
```

#### Widening unsigned integer add
2*SEW = SEW + SEW
```
vwaddu.vv vd, vs2, vs1, vm # vector-vector
```

#### Widening unsigned integer subtract
2*SEW = SEW - SEW
```
vwsubu.vv vd, vs2, vs1, vm # vector-vector
```

#### Widening signed integer add
2*SEW = SEW + SEW
```
vwadd.vv vd, vs2, vs1, vm # vector-vector
```

#### Widening signed integer subtract
2*SEW = SEW - SEW
```
vwsub.vv vd, vs2, vs1, vm # vector-vector
```

#### Vector Integer Add-with-Carry
vd[i] = vs2[i] + vs1[i] + v0.mask[i]
```
 vadc.vvm vd, vs2, vs1, v0 # Vector-vector
```

#### Vector Integer Subtract-with-Borrow
vd[i] = vs2[i] - vs1[i] - v0.mask[i]
```
 vsbc.vvm vd, vs2, vs1, v0 # Vector-vector
```

```
# Example multi-word arithmetic sequence, accumulating into v4
 vmadc.vvm v1, v4, v8, v0 # Get carry into temp register v1
 vadc.vvm v4, v4, v8, v0 # Calc new sum
 vmmv.m v0, v1 # Move temp carry into v0 for next word
```

### Vector Integer Extension
The vector integer extension instructions zero- or sign-extend a source vector integer operand with EEW less than SEW to fill SEW-sized elements in the destination. The EEW of the source is 1/2, 1/4, or 1/8 of SEW, while EMUL of the source is (EEW/SEW)*LMUL. The destination has EEW equal to SEW and EMUL equal to LMUL.

```
vzext.vf2 vd, vs2, vm # Zero-extend SEW/2 source to SEW destination
vsext.vf2 vd, vs2, vm # Sign-extend SEW/2 source to SEW destination
```

### Vector Single-Width Integer Multiply-Add
```
# Integer multiply-add, overwrite addend
vmacc.vv vd, vs1, vs2, vm # vd[i] = +(vs1[i] * vs2[i]) + vd[i]

# Integer multiply-sub, overwrite minuend
vnmsac.vv vd, vs1, vs2, vm # vd[i] = -(vs1[i] * vs2[i]) + vd[i]

# Integer multiply-add, overwrite multiplicand
vmadd.vv vd, vs1, vs2, vm # vd[i] = (vs1[i] * vd[i]) + vs2[i]
```
