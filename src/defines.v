// #############################################################################################################################
// DEFINE
// 
// 为二进制编码重命名，增加可读性
// #############################################################################################################################

// logic
`define     FALSE               1'b0
`define     TRUE                1'b1

// sign bit
`define     ZERO                2'b00
`define     POS                 2'b01
`define     NEG                 2'b11

// IMPLEMENTATION-DEFINED CONSTANT PARAMETERS
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// maximum size in bits of a vector element
`define     ELEN                32
// number of bits in a single vector register
`define     VLEN                256

// SIGNAL
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// MAIN Memory
// -------------------------------------------------------------------------
// task type
`define     MEM_NOP             2'b00
`define     MEM_READ            2'b01
`define     MEM_READ_BURST      2'b10
`define     MEM_WRITE           2'b11

// working status
`define     MEM_RESTING         2'b00
`define     MEM_INST_WORKING    2'b01
`define     MEM_DATA_WORKING    2'b10
`define     MEM_FINISHED        2'b11


// INSTRUCTION CACHE
// -------------------------------------------------------------------------
`define     I_CACHE_STALL        2'b00
`define     I_CACHE_WORKING      2'b01
`define     IF_FINISHED          2'b10
`define     I_CACHE_RESTING      2'b11



// DATA CACHE
// -------------------------------------------------------------------------
// task type
`define     D_CACHE_NOP          2'b00
`define     D_CACHE_LOAD         2'b01
`define     D_CACHE_STORE        2'b10
`define     D_CACHE_REST         2'b11


// working status
`define     D_CACHE_STALL        2'b00
`define     D_CACHE_WORKING      2'b01
`define     L_S_FINISHED         2'b10
`define     D_CACHE_RESTING      2'b11


// Reg File
// -------------------------------------------------------------------------
// working status
`define     RF_NOP                  2'b00
`define     SCALAR_RF_WRITE         2'b01
`define     VECTOR_RF_WRITE         2'b01
`define     RF_FINISHED             2'b11

// ALU
// ----------------------------------------------------------
// 计算控制信号
`define     ALU_NOP                 3'b000
`define     BINARY                  3'b001
`define     IMM_BINARY              3'b010
`define     BRANCH_COND             3'b011
`define     MEM_ADDR                3'b100
`define     PC_BASED                3'b101
`define     IMM                     3'b110

`define     SET_CFG                 3'b111

// vector运算类型
`define     NOT_VEC_ARITH           2'b00
`define     VEC_VEC                 2'b01
`define     VEC_IMM                 2'b10
`define     VEC_SCALAR              2'b11

// vector alu working status
`define     VEC_ALU_NOP             2'b00
`define     VEC_ALU_WORKING         2'b01
`define     VEC_ALU_FINISHED        2'b10

// binary
`define     ADD                     4'b0000

// IMM
`define     ADDI                    3'b000
`define     SLTI                    3'b010

// DECODE
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Type Code
// ----------------------------------------------------------
`define     V_TYPE                  7'b1000000
`define     R_TYPE                  7'b0100000
`define     I_TYPE                  7'b0010000
`define     S_TYPE                  7'b0001000
`define     B_TYPE                  7'b0000100
`define     U_TYPE                  7'b0000010
`define     J_TYPE                  7'b0000001

// Vector Opcode
`define     VL                      7'b0000111
`define     VS                      7'b0100111
`define     VARITH                  7'b1010111

// Data Size
// ----------------------------------------------------------
// 访存数据类型
`define     NOT_ACCESS              2'b00
`define     BYTE                    2'b01
`define     HALF                    2'b10
`define     WORD                    2'b11

// vector访存形式
`define     STRIDE                  2'b01
`define     WHOLE_REG               2'b10
`define     MASK                    2'b11

// BRANCH
// ----------------------------------------------------------
`define     NOT_BRANCH              2'b00
`define     UNCONDITIONAL           2'b01
`define     CONDITIONAL             2'b10
`define     UNCONDITIONAL_RESULT    2'b11 // jalr

// WB 写寄存器
// ----------------------------------------------------------
`define     WB_NOP                  2'b00
`define     MEM_TO_REG              2'b01
`define     ARITH                   2'b10
`define     INCREASED_PC            2'b11

// ENCODING
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Vector L\S Encoding
// ----------------------------------------------------------
// vector addressing modes
// (mop[1:0])
// unit-stride, indexed-unordered, strided, indexed-ordered
`define     VLE                 2'b00
`define     VLUXEI              2'b01
`define     VLSE                2'b10
`define     VLOXEI              2'b11

`define     VSE                 2'b00
`define     VSUXEI              2'b01
`define     VSSE                2'b10
`define     VSOXEI              2'b11

// additional unit-stride vector addressing modes
// (lumop[4:0],sumop[4:0])
`define     E_BASIC             5'b00000
`define     E_WHOLE_REG         5'b01000
`define     E_MASK              5'b01011


// Vector Arithmetic/Configuration Encoding
// ----------------------------------------------------------
// operand type and source locations
// (funct3[2:0])
`define     OPIVV               3'b000
`define     OPFVV               3'b001
`define     OPMVV               3'b010
`define     OPIVI               3'b011
`define     OPIVX               3'b100
`define     OPFVF               3'b101
`define     OPMVX               3'b110
`define     OPCFG               3'b111 // configuration


