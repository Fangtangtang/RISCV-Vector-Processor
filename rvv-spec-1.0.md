# Implementation-defined Constant Parameters

基于物理元件？一些代码应该遵循的参数。

### `ELEN`

单个向量元素的最大长度

2的幂次，至少8



### `VLEN`

单个向量寄存器长度

2的幂次，至多$2^{16}$

`VLEN` $\ge$ `ELEN`



# Vector Extension Programmer’s Model

- 32 scalar registers

- 32 vector registers:` v0-v31`

  - Each vector register has a fixed `VLEN` bits of state

- 7  unprivileged `CSR`s

  Control and Status Register

   (`vstart, vxsat, vxrm, vcsr, vtype, vl, vlenb`)
  
  - `vstart`:vector start position	`0x008`

    - Normally, vstart is only written by hardware on a trap on a vector instruction,
    - All vector instructions are defined to begin execution with the element number given in the vstart CSR, leaving earlier elements in the destination vector undisturbed, and to reset the vstart CSR to zero at the end of execution.
    - 定义了一条向量指令执行时的第一个元素在向量中的索引号
    - 一条向量指令结束时会将`vstart`归零
    - `vstart`之前的向量值将保持undisturbed
    
  - `vcsr`:vector control and status register	`0x00F`
  
  - `vl`:vector length  `0xC20`
    
    - 只能通过`vset{i}vl{i}`指令赋值
      
    - 单条向量指令要处理的元素个数
    
  - `vtype`:vector data type register  `0xC21`
  
    - 只能通过`vset{i}vl{i}`指令赋值
    
    - vector registers中数据（向量）类型
  
    - ```tex
      31  30      				8  7   6  5  3 2   0
      +----+-----------------------+---+---+----+-----+
    |vill|           0           |vma|vta|vsew|vlmul|
      ```
    
    - `vill`:Illegal value if set
    - `vma`:Vector mask agnostic
    - `vta`:Vector tail agnostic
    - `vsew`[2:0]:Selected element width (SEW) setting
    
       - 向量元素的位宽
       - By default, a vector register is viewed as being divided into VLEN/SEW elements.
    - `vlmul`[2:0]:vector register group multiplier (LMUL) setting
    
      - 将多个vector register划分为组，一组作为一个操作数
    
  - `LMUL*VLEN/SEW` represents the maximum number of elements that can be operated on with a single vector instruction
    
  - `vlenb`:`VLEN`/8 (vector register length in bytes)  `0xC22`



#  Mapping of Vector Elements to Vector Register State



# Vector Instruction Formats

21



## Scalar Operands

can be immediates, or taken from the x registers, the f registers, or element 0 of a vector register

written to an x or f register or to element 0 of a vector register



##  Vector Operands

Each vector operand has an **effective element width** (EEW) and an **effective LMUL** (EMUL) that is used to determine the size and location of all the elements within a vector register group.

By default, for most operands of most instructions, EEW=SEW and EMUL=LMUL.



##  Vector Masking

The mask value used to control execution of a masked vector instruction is always supplied by **vector register v0**.

将mask信息用1bit存放在v0，标示指令中是否使用对应数据。

将mask从低位向高位存放。

Each element is allocated a single mask bit in a mask vector register. The mask bit for element i is located in bit i of the mask register, independent of SEW or LMUL.

The destination vector register group for a masked vector instruction cannot overlap the source mask register (v0), unless the destination vector register is being written with a mask value (e.g., compares) or the scalar result of a reduction.



vm=0:vector result, only where v0.mask[i] = 1

 ## Prestart, Active, Inactive, Body, and Tail Element Definitions

// todo:23



# Configuration-Setting Instructions

根据指令里给出的各项参数和硬件参数配置 **vtype** , **vl** 

set the **vtype** and **vl** CSRs based on their arguments, and write the new value of vl into rd

the hardware responds via a general purpose register with the (frequently smaller) number of elements that the hardware will handle per iteration (stored in vl), based on the microarchitectural implementation and the vtype setting

The new vtype setting is encoded in the immediate field of vsetvli and vsetivli, and in the rs2 register for vsetvl.

### AVL

**Application Vector Length(AVL)**

total number of elements to be processed(new vector length), candidate value for vl

#### Encoding

- When rs1 is not x0, the AVL is an unsigned integer held in the x register specified by rd
- When rs1=x0 but rd!=x0, the maximum unsigned integer value (~0) is used as the AVL, and the resulting VLMAX is written to vl and also to the x register specified by rd
- When rs1=x0 and rd=x0, the instruction operates as if the current vector length in vl is used as the AVL, and the resulting value is written to vl, but not to a destination register. This form can only be used when VLMAX and hence vl is not actually changed by the new SEW/LMUL ratio. Use of the instruction with a new SEW/LMUL ratio that would result in a change of VLMAX is reserved. Implementations may set vill in this case

### VL

设置受到AVL影响

set VLMAX(受LMUL影响) according to their vtype argument, then set vl obeying some constraints



# Vector Arithmetic Instructions

42

```

31 29 28 27 26 25 24           20 19         15 14  12 11          7 6       0
+----+---+---+---+---------------+-------------+------+-------------+---------+
|    funct6  | vm|       vs2     | vs1/rs1/imm |funct3|   vd/rd     | opcode  |


```

### scalar source operand

-  5-bit immediate, sign-extended to SEW bits, unless otherwise specified.
- taken from the scalar x register specified by rs1. XLEN>SEW, the least significant SEW bits of the x register are used. XLEN<SEW, sign-extended to SEW bits, unless otherwise specified.

## Widening Vector 

形成双宽和之前，先对较窄的源操作数进行扩展

widening operations where the destination vector register group has EEW=2*SEW and EMUL=2*LMUL

目标寄存器的元素位宽和grouping都是我的两倍

```
# Double-width result, two single-width sources
# 2*SEW = SEW op SEW
vwop.vv vd, vs2, vs1, vm # integer vector-vector vd[i] = vs2[i] op vs1[i]
vwop.vx vd, vs2, rs1, vm # integer vector-scalar vd[i] = vs2[i] op x[rs1]

# Double-width result, first source double-width, second source single-width
# 2*SEW = 2*SEW op SEW
vwop.wv vd, vs2, vs1, vm # integer vector-vector vd[i] = vs2[i] op vs1[i]
vwop.wx vd, vs2, rs1, vm # integer vector-scalar vd[i] = vs2[i] op x[rs1]

```

## Vector Integer Extension

zero- or sign-extend a source vector integer operand with EEW less than SEW to fill SEW-sized elements in the destination

The EEW of the source is 1/2, 1/4, or 1/8 of SEW, while EMUL of the source is (EEW/SEW)*LMUL. The destination has EEW equal to SEW and EMUL equal to LMUL

```
vzext.vf2 vd, vs2, vm # Zero-extend SEW/2 source to SEW destination
vsext.vf2 vd, vs2, vm # Sign-extend SEW/2 source to SEW destination

```



## Vector Integer Add-with-Carry / Subtract-with-Borrow

用于多字整数运算(执行高精度运算或需要处理大整数...)

加减法的进位退位为0/1，可以使用mask表示。

masked instructions, but they operate on and write back all body elements

add or subtract the source operands and the carry-in or borrow-in, and write the result to vector register vd.

For each operation (add or subtract), **two instructions are provided**: 

- one to provide the result (SEW width),
- the second to generate the carry output (single bit encoded as a mask boolean).



**carry input** must come from the implicit **v0** register

carry outputs can be written to any vector register that respects the source/destination overlap restrictions.



vmadc and vmsbc add or subtract the source operands, optionally add the carry-in or subtract the borrow-in if masked (vm=0), and write the result back to mask register vd. If unmasked (vm=1), there is no carry-in or borrow-in. 

These instructions operate on and write back all body elements, even if masked. 

Because these instructions produce a mask value, they always operate with a tail-agnostic policy.



实质：

- vadc:三个数据相加减，可能有进位退位，结果写到指定位置

- vmadc:三个数据相加减，进位退位写到指定寄存器



```
 # Example multi-word arithmetic sequence, accumulating into v4
 vmadc.vvm v1, v4, v8, v0 # Get carry into temp register v1, v0 is implicit
 vadc.vvm v4, v4, v8, v0 # Calc new sum
 vmmv.m v0, v1 # Move temp carry into v0 for next word

```



# Vector Load and Store

masked?



Vector memory unit-stride and constant-stride operations directly encode EEW(element width) of the data to be transferred statically in the instruction to reduce the number of vtype changes when accessing memory in a mixed-width routine.

 Indexed operations use the explicit EEW encoding in the instruction to set the size of the indices used, and use SEW/LMUL to specify the data width.



## L/S Addressing Modes

### Mask

对于未激活的元素，被mask的load指令不产生异常，且在目标寄存器组中，不被更新，除非vtype.vma=1。

被mask的store指令，只会更新激活元素的内存。

### Basic unit-stride vector addressing modes

Vector **unit-stride** operations access elements stored contiguously in memory starting from the base effective address. 

Vector **constant-strided** operations access the first memory element at the base effective address, and then access subsequent elements at address increments given by the byte offset contained in the x register specified by rs2. 以地址增量访问后续元素，地址增量由 rs2 指定的 x 寄存器中包含的字节偏移量给出。（可以以固定步长跳？）

Vector **indexed** operations add the contents of each element of the vector offset operand specified by vs2 to the base effective address to give the effective address of each element. 指定的向量偏移操作数的每个元素的内容添加到基有效地址，以给出每个元素的有效地址（从内存分散空间获得？）The data vector register group has EEW=SEW, EMUL=LMUL, while the offset vector register group has EEW encoded in the instruction and EMUL=(EEW/SEW)*LMULvs2.



### Additional unit-stride vector addressing modes

- whole register load
- mask load, EEW=8
- fault-only-first



# 一些缩写

EEW: element width