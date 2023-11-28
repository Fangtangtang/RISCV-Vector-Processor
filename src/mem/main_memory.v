// #############################################################################################################################
// MAIN MEMORY
// 
// 和cache直接交互，带宽4bytes
// #############################################################################################################################
`include"src/defines.v"

module MAIN_MEMORY#(parameter ADDR_WIDTH = 17,
                    parameter LEN = 32,
                    parameter BYTE_SIZE = 8)
                   (input wire clk,
                    input [1:0] mem_vis_signal,
                    input [ADDR_WIDTH-1:0] mem_vis_addr,
                    input [LEN-1:0] writen_data,
                    output [LEN-1:0] mem_data,
                    output[1:0] mem_status);
    
    reg [BYTE_SIZE-1:0] storage [0:2**ADDR_WIDTH-1];
    
    initial begin
        for (integer i = 0;i<2**ADDR_WIDTH;i = i+1) begin
            storage[i] = 0;
        end
        $readmemh("/mnt/f/repo/ToyCPU/user/testspace/test.data", storage);
    end
    
    reg [LEN-1:0] read_data;
    assign mem_data = read_data;
    
    always @(posedge clk) begin
        if (mem_vis_signal == `WRITE) begin
            storage[mem_vis_addr+3] <= writen_data[31:24];
            storage[mem_vis_addr+2] <= writen_data[23:16];
            storage[mem_vis_addr+1] <= writen_data[15:8];
            storage[mem_vis_addr]   <= writen_data[7:0];
        end
        
            if (mem_vis_signal == `READ) begin
                read_data <= {storage[mem_vis_addr+3],storage[mem_vis_addr+2],storage[mem_vis_addr+1],storage[mem_vis_addr]};
            end
    end
    
endmodule
