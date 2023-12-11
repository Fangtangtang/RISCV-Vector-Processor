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
      - `vsew`:Selected element width (SEW) setting
        - 向量元素的位宽
        - By default, a vector register is viewed as being divided into VLEN/SEW elements.
      - `vlmul`:vector register group multiplier (LMUL) setting
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

// todo:23



 ## Prestart, Active, Inactive, Body, and Tail Element Definitions

// todo:23



# Configuration-Setting Instructions





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



