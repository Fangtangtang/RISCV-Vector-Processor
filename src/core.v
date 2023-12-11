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
module CORE#(parameter ADDR_WIDTH = 17,
             parameter LEN = 32,
             parameter BYTE_SIZE = 8,
             parameter VECTOR_SIZE = 8,
             parameter ENTRY_INDEX_SIZE = 3)
            ();
    
endmodule
