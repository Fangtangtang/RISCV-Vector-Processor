// #############################################################################################################################
// VECTOR FUNCTION UNIT
// 
// 处理一条指令的execution
// - 组成部分
// | + Dispatcher
// |     将数据下放到各个lane
// |
// | + Lanes
// |     处理单组数据的运算，多个vector alu
// |
// | + Recaller
// |     收束，把数据收到一个result里面
// #############################################################################################################################
`include "src/defines.v"
`include "src/funct_unit/vector_alu.v"

module VECTOR_FUNCTION_UNIT#(parameter ADDR_WIDTH = 17,
                             parameter LEN = 32,
                             parameter BYTE_SIZE = 8,
                             parameter VECTOR_SIZE = 8,
                             parameter ENTRY_INDEX_SIZE = 3,
                             parameter LANE_SIZE = 2,
                             parameter LANE_INDEX_SIZE = 1)
                            ();
    
    
    // Dispatcher
    
    // Lanes
    
    // Recaller
    
endmodule
