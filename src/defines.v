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

// binary
`define     ADD                     4'b0000

// IMM
`define     ADDI                    3'b000
`define     SLTI                    3'b010