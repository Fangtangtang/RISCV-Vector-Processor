# RISC-V Vector Processor

SIMD向量处理器，选用pipeline。

## 设计简图

<img src="F:\repo\RISCV-Vector-Processor\doc\diagram.jpg" style="zoom:50%;" />



## 组成部分

### Main Memory

random access memory。和cache直接交互，带宽为4 bytes。



### Cache

#### Instruction Cache

全关联cache。处理根据PC取指令访存请求。



#### Data Cache

直接映射cache。接受来自memory controller的访存请求，针对memory controller请求的起始地址和不同数据类型，返回4 bytes数据。



### Memory Controller

连接core和data cache，控制数据访存。

core发来标量或向量访存请求，由memory controller拆成相对应的数据类型和首地址访存。其中，向量访存被拆解为单个元素访存，如果是带mask的向量访存，仅load/store被激活的数据位。



### Core

流水线，拆解为`instruction fetch,instruction decode,execute,memory access,write back`五个阶段。

#### Special Register

##### PC

program counter。



##### CSRs

 Control and Status Register，用于说明向量指令用到的一些性质。

- `vl`:vector length。单条向量指令要处理的元素个数

- `vtype`:vector data type register。vector registers中数据（向量）类型。

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



#### Register File

#### scalar register file

32个32位标量寄存器。



#### vector register file

32个向量寄存器，每个向量长度由常量`VLEN`决定。不同数据类型元素，所占位宽不同。各个元素在寄存器中紧密排列。

其中`v0`会被用于存放mask信息。



#### Decoder

使用组合逻辑将instruction解码为各种信号和数据。



#### Function unit

##### scalar ALU

用于标量指令的算术和逻辑单元。



##### vector function units

用于向量指令的execution。分为`Dispatcher,Lanes,Recaller`三个部分。

- `Dispatcher:`将待操作数据下放到各个lane
- `Lanes:`由多个（`LANE_SIZE`个）vector ALU组成。每个vector ALU能对一组操作元素做算术和逻辑计算。
- `Recaller:`收束，把数据收到一个result（为一个向量）里面



## rvv拓展

### 单条指令操作多数据（SIMD）

对向量指令，一条指令能操作`vl`个数据。



### MASK

向量指令第25位（`inst[25]`）为`vm`标记，用于说明该条指令是否使用masking（0 = mask enabled, 1 = mask disabled）。

对使用mask的指令，对数据操作时，根据指令对于的`v0`中存放的mask信号，控制被操作向量每一个元素是否被激活执行。

对于计算指令，仅被激活的数据做运算，不被激活的在计算和result write back阶段均不做操作。对于load指令，memory controller只为被激活的数据向data cache发访存请求，未激活数据使用默认值补位或不处理（是无效数据），load的数据write back到寄存器时，仅操作被激活的位置。对store指令，memory controller只为被激活的数据向data cache发访存请求。

有专门操作mask的指令，如vector integer add-with-carry通过`vmadc,vadc,vmmv`实现。



### 多数据类型

对于标量数据类型，用于运算的都作32位，访存由指令决定是对多少字节进行操作。

对于向量，数据类型由 Control and Status Register `vtype`决定。其中，`vsew`说明一个向量寄存器里的数据应该被解释为何种类型（拆分方式）；`vlmul`说明以多少个向量寄存器作为一个group，充当一个大向量。

向量指令对数据的操作依赖于对应的`vtype`解释。如果出现grouping将多个向量合在一起，整体的部分流水阶段需要被重复（暂未设计）。运算阶段，vector function units中的`Dispatcher`根据`vsew`将一个向量拆成元素发给各个`Lane`。访存阶段，memory controller根据`vsew`将一个向量拆成被store的元素或者load数据放入寄存器对应位置。

`vtype`能通过Configure Setting指令修改。



## Repositories

普通cpu：[Fangtangtang/ToyCPU (github.com)](https://github.com/Fangtangtang/ToyCPU)

vector processor：[Fangtangtang/RISCV-Vector-Processor (github.com)](https://github.com/Fangtangtang/RISCV-Vector-Processor)