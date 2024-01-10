# RISCV-Vector-Processor

## 简介
以支持更多RVV指令数量为探索方向，设计支持RISC-V Vector Extension Spec 1.0中部分指令的SIMD架构向量处理器。

## ISA
### RV64I
##### add
```text
|     ADD     | Add                                      |

31           25 24         20 19         15 14 12 11          7 6       0
+--------------+-------------+-------------+-----+-------------+---------+
|   0000000    |     rs2     |     rs1     | 000 |     rd      | 0110011 | ADD

```

```text
|    ADDI     | Add Immediate                            |

31           25 24         20 19         15 14 12 11          7 6       0
+--------------+-------------+-------------+-----+-------------+---------+
|         imm[11:0]          |     rs1     | 000 |     rd      | 0010011 | ADDI


```

##### branch
```text
|     BEQ     | Branch if Equal                          |

31           25 24         20 19         15 14 12 11          7 6       0
+--------------+-------------+-------------+-----+-------------+---------+
| imm[12|10:5] |     rs2     |     rs1     | 000 | imm[4:1|11] | 1100011 | BEQ

```

##### load
```text
|     LW      | Load Word                                |

31           25 24         20 19         15 14 12 11          7 6       0
+--------------+-------------+-------------+-----+-------------+---------+
|         imm[11:0]          |     rs1     | 010 |     rd      | 0000011 | LW

```

##### store
```text
|     SW      | Store Word                               |

31           25 24         20 19         15 14 12 11          7 6       0
+--------------+-------------+-------------+-----+-------------+---------+
|  imm[11:5]   |     rs2     |     rs1     | 010 |  imm[4:0]   | 0100011 | SW

```
### RV64v

#### Vector Integer Add\Subtract
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


##### Integer add
```
vadd.vv vd, vs2, vs1, vm # Vector-vector
```

```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     vs1     | 000 |     vd      | opcode  | VADD
|    000000  |  1|      11000    |    11010    | 000 |    11000    | 1010111 | vadd.vv
```


##### Integer subtract
```
vsub.vv vd, vs2, vs1, vm # Vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     vs1     | 000 |     vd      | opcode  | VSUB
|    000010  |  1|      11000    |    11010    | 000 |    11000    | 1010111 | vsub.vv
```


##### Widening unsigned integer add
Widening unsigned integer add/subtract, 2*SEW = SEW + SEW, vector-vector

无符号数，0拓展

将位宽为SEW的做加法运算后存入为2*SEW
```
vwaddu.vv vd, vs2, vs1, vm # vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VWADDU
|    110000  |  1|               |             | 000 |             | 1010111 | vwaddu
```
##### Widening unsigned integer subtract
Widening unsigned integer add/subtract, 2*SEW = SEW - SEW, vector-vector

无符号数，0拓展

将位宽为SEW的做减法运算后存入为2*SEW
```
vwsubu.vv vd, vs2, vs1, vm # vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VWSUBU
|    110010  |  1|               |             | 000 |             | 1010111 | vwsubu
```
##### Widening signed integer add
符号位拓展

2*SEW = SEW + SEW

```
vwadd.vv vd, vs2, vs1, vm # vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VWADD
|    110001  |  1|               |             | 000 |             | 1010111 | vwadd
```
##### Widening signed integer subtract
符号位拓展

2*SEW = SEW - SEW
```
vwsub.vv vd, vs2, vs1, vm # vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VWSUB
|    110011  |  1|               |             | 000 |             | 1010111 | vwsub
```
##### Vector Integer Add-with-Carry
Produce sum with carry. 

vd[i] = vs2[i] + vs1[i] + v0.mask[i]

```
 vadc.vvm vd, vs2, vs1, v0 # Vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VADC
|    010000  |  0|               |             | 000 |             | 1010111 | vadc
```

Produce carry out in mask register format.

vd.mask[i] = carry_out(vs2[i] + vs1[i])

```
vmadc.vv    vd, vs2, vs1
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VMADC
|    010001  |  1|               |             | 000 |             | 1010111 | vmadc
```
##### Vector Integer Subtract-with-Borrow
Produce difference with borrow. 

vd[i] = vs2[i] - vs1[i] - v0.mask[i]
```
 vsbc.vvm vd, vs2, vs1, v0 # Vector-vector
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VSBC
|    010010  |  0|               |             | 000 |             | 1010111 | vsbc
```

Produce borrow out in mask register format. 

vd.mask[i] = borrow_out(vs2[i] - vs1[i] - v0.mask[i])

```
vmsbc.vvm   vd, vs2, vs1, v0
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |     rs1     | 000 |     vd      | opcode  | VMSBC
|    010011  |  0|               |             | 000 |             | 1010111 | vmsbc

```
```
# Example multi-word arithmetic sequence, accumulating into v4
 vmadc.vvm v1, v4, v8, v0 # Get carry into temp register v1
 vadc.vvm v4, v4, v8, v0 # Calc new sum
 vmmv.m v0, v1 # Move temp carry into v0 for next word
```

#### Vector Integer Extension
The vector integer extension instructions zero- or sign-extend a source vector integer operand with EEW less than SEW to fill SEW-sized elements in the destination. The EEW of the source is 1/2, 1/4, or 1/8 of SEW, while EMUL of the source is (EEW/SEW)*LMUL. The destination has EEW equal to SEW and EMUL equal to LMUL.

```
vzext.vf2 vd, vs2, vm # vs1=00110	Zero-extend SEW/2 source to SEW destination
vsext.vf2 vd, vs2, vm # vs1=00111	Sign-extend SEW/2 source to SEW destination
vzext.vf4 vd, vs2, vm # vs1=00100	Zero-extend SEW/4 source to SEW destination
vsext.vf4 vd, vs2, vm # vs1=00101	Sign-extend SEW/4 source to SEW destination
vzext.vf8 vd, vs2, vm # vs1=00010	Zero-extend SEW/8 source to SEW destination
vsext.vf8 vd, vs2, vm # vs1=00011	Sign-extend SEW/8 source to SEW destination
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |  type code  | 010 |     vd      | opcode  | 
|    010010  |  0|               |             | 010 |             | 1010111 | 

```
#### Vector Single-Width Integer Multiply-Add
```
# Integer multiply-add, overwrite addend
vmacc.vv vd, vs1, vs2, vm # vd[i] = +(vs1[i] * vs2[i]) + vd[i]

# Integer multiply-sub, overwrite minuend
vnmsac.vv vd, vs1, vs2, vm # vd[i] = -(vs1[i] * vs2[i]) + vd[i]

# Integer multiply-add, overwrite multiplicand
vmadd.vv vd, vs1, vs2, vm # vd[i] = (vs1[i] * vd[i]) + vs2[i]
```
```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
|    funct   | vm|       vs2     |  type code  | 010 |     vd      | opcode  | 
|    101101  |  0|               |             | 010 |             | 1010111 | vmacc
|    101111  |  0|               |             | 010 |             | 1010111 | vnmsac
|    101001  |  0|               |             | 010 |             | 1010111 | vmadd
```

#### Vector Load
```
# Vector Load/Store Whole Register Instructions
# Load vd-vd+1 with VLEN/32 words held at address in rs1
vl2re32.v	v24,(a0)
```

```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
| nf |mew|mop| vm|   lumop       |     rs1     |width|     vd      | 0000111 | VL
| 001|  0| 00|  1|   01000       |    01010    | 110 |   11000     | 0000111 | vl2re32.v
```
- nf:specifies the number of fields in each segment, for segment load/stores (001:2)
- mew:extended memory element width.     
- mop:specifies memory addressing mode
- vm:specifies whether vector masking is enabled (0 = mask enabled, 1 = mask disabled)
- lumop:additional fields encoding variants of unit-stride instructions



#### Vector Store
```
vs2r.v	v24,(a2)
```

```
31 29 28 27 26 25 24           20 19         15 14 12 11          7 6       0
+----+---+---+---+---------------+-------------+-----+-------------+---------+
| nf |mew|mop| vm|   sumop       |     rs1     |width|     vs      | 0100111 | 

```

#### Configure Setting
```
 vsetvli rd, rs1, vtypei # rd = new vl, rs1 = AVL, vtypei = new vtype setting
 vsetvli zero,a3,e32,m2,ta,mu
```

 ```
31    30                       20 19         15 14 12 11          7 6       0
+----+---------------------------+-------------+-----+-------------+---------+
|  0 |             vsew vlmul    |     rs1     | 111 |     rd      | 1010111 | VSETVLI
|  0 |    00001     010 001      |    01101    | 111 |   00000     | 1010111 | vsetvli

 ```
Suggested assembler names used for vset{i}vl{i} vtypei immediate
```
selected element width (SEW)
a vector register is viewed as being divided into VLEN/SEW elements.

 e8     # SEW=8b
 e16    # SEW=16b
 e32    # SEW=32b  32位数   010
 e64    # SEW=64b

vector register group multiplier (LMUL)

one or more vector registers used as a single operand to a vector instruction（多个向量寄存器组成一组，成为单条向量指令的一组操作数）
when greater than 1, represents the default number of vector registers that are combined to form a vector register group

LMUL=2^(vlmul[2:0])
 mf8    # LMUL=1/8
 mf4    # LMUL=1/4
 mf2    # LMUL=1/2
 m1     # LMUL=1, assumed if m setting absent
 m2     # LMUL=2    001
 m4     # LMUL=4
 m8     # LMUL=8
```

## Example
### VADD
vl2re32.v把两个向量寄存器绑在一起作为一个group，然后a3中的AVL不会超过MAXVL(受LMUL作用)
vsetvli会根据指令里面的vtype等等计算VLMAX，根据VLMAX和指令里面的AVL设置VL。
add就对寄存器中vl个做加法。
vs2r.v把绑成一组的两个寄存器数据都写回内存

```
0000000000001000 <vec_add_rvv>:
    1000:	22856c07          	vl2re32.v	v24,(a0)            // 从内存指定位置读，从a0中地址开始，读数据到打包在一起的两个vec register(v24,v25)
    1004:	2285ed07          	vl2re32.v	v26,(a1)
    1008:	0516f057          	vsetvli	zero,a3,e32,m2,ta,mu    // 设置vtype\vl 两个vec register被打包成一个，单个数据位宽32
    100c:	038d0c57          	vadd.vv	v24,v24,v26             // 向量加法
    1010:	22860c27          	vs2r.v	v24,(a2)                // 结果再写入内存，打包在一起的两个vec register(v24,v25)中数据存入内存
    1014:	00008067          	ret
```