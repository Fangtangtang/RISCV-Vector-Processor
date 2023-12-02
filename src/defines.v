// #############################################################################################################################
// DEFINE
// 
// 为二进制编码重命名，增加可读性
// #############################################################################################################################

`define     FALSE               1'b0
`define     TRUE                1'b1

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

