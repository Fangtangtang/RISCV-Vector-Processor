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

- 7  unprivileged `CSR`s (`vstart, vxsat, vxrm, vcsr, vtype, vl, vlenb`)

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