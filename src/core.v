// #############################################################################################################################
// CORE
// 
// vector processor core
// pipeline
// 
// - 组成部分
// | + Register
// |     PC
// |     scalar registers file, vector register file, 7 unprivileged CSRs
// |
// | + Storage
// |     main memory
// |     instruction cache, data cache
// |
// | + Function Unit
// |     alu
// #############################################################################################################################
`include"src/defines.v"
`include"src/decoder.v"
`include"src/funct_unit/scalar_alu.v"
`include"src/funct_unit/vector_function_unit.v"
`include"src/reg/scalar_register_file.v"
`include"src/reg/vector_register_file.v"


module CORE#(parameter ADDR_WIDTH = 17,
             parameter LEN = 32,
             parameter BYTE_SIZE = 8,
             parameter VECTOR_SIZE = 8,
             parameter ENTRY_INDEX_SIZE = 3)
            (input clk,
             input rst,
             input rdy_in,
             input [LEN-1:0] instruction,
             input [LEN-1:0] mem_read_scalar_data,
             input [LEN*VECTOR_SIZE-1:0] mem_read_vector_data,
             input [1:0] mem_vis_status,
             output [LEN-1:0] mem_write_scalar_data,
             output [LEN*VECTOR_SIZE-1:0] mem_write_vector_data,
             output [ENTRY_INDEX_SIZE:0] vector_length,
             output [ADDR_WIDTH-1:0] mem_inst_addr,
             output [ADDR_WIDTH-1:0] mem_data_addr,
             output inst_fetch_enabled,
             output mem_vis_enabled,
             output [1:0] memory_vis_signal,
             output [2:0] data_type);
    
    // REGISTER
    // ---------------------------------------------------------------------------------------------
    // Program Counter
    reg [LEN-1:0]   PC;
    
    // Control and Status Register
    
    // vl:vector length
    reg [31:0] VL;
    
    // vlenb:`VLEN`/8 (vector register length in bytes), read only
    reg [31:0] VLENB = LEN*VECTOR_SIZE/BYTE_SIZE;
    
    // vtype:vector data type register
    reg [31:0] VTYPE;
    // vsew[2:0]:Selected element width (SEW) setting
    wire [2:0] VSEW = VTYPE[5:3];
    // vlmul[2:0].:vector register group multiplier (LMUL) setting
    wire [2:0] VLMUL = VTYPE[2:0];
    
    // Transfer Register
    // if-id
    
    // id-exe
    
    // exe-mem
    
    // mem-wb
    
    
    
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // PIPELINE
    
    // STATE CONTROLER
    // 
    // stall or not
    // 可能因为访存等原因stall
    
    reg         IF_STATE_CTR  = 0;
    reg         ID_STATE_CTR  = 0;
    reg         EXE_STATE_CTR = 0;
    reg         MEM_STATE_CTR = 0;
    reg         WB_STATE_CTR  = 0;
    
endmodule
