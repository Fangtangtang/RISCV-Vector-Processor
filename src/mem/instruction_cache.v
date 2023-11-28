// #############################################################################################################################
// INSTRUCTION CACHE
// 
// - cache size = 2，暂时仅作为memory controller
// #############################################################################################################################
`include"src/defines.v"

module INSTRUCTION_CACHE#(parameter ADDR_WIDTH = 17,
                          parameter LEN = 32,
                          parameter BYTE_SIZE = 8,
                          parameter ICACHE_SIZE = 2,
                          parameter INDEX_SIZE = 1)
                         (input wire clk,
                          input [ADDR_WIDTH-1:0] inst_addr,     // instruction fetch
                          input inst_fetch_enabled,
                          output [LEN-1:0] instruction,
                          output reg [1:0] inst_fetch_status,
                          input [LEN-1:0] mem_data,             // interact with main memory
                          input [1:0] mem_status,
                          output [ADDR_WIDTH-1:0] mem_vis_addr, // 访存地址
                          output [1:0] mem_vis_signal);
    
    // 全关联cache
    reg [ADDR_WIDTH-1:0] inst_address [ICACHE_SIZE-1:0];
    reg [LEN-1:0] inst [ICACHE_SIZE-1:0];
    
    reg [1:0] CNT = 0;
    
    reg [LEN-1:0] _instruction;
    assign instruction = _instruction;
    
    reg _hit;
    reg [INDEX_SIZE-1:0] _current_index; // 当前地址对应的entry下标
    reg [ADDR_WIDTH-1:0] _current_addr;
    assign mem_vis_addr = _current_addr;
    
    
    always @(posedge clk) begin
        case (CNT)
            2:begin
                if (_hit) begin
                    CNT               <= 0;
                    inst_fetch_status <= `IF_FINISHED;
                    _hit = `FALSE;
                end
                else begin
                    inst_address[0] <= _current_addr;
                    case (mem_status)
                        // 可以访存
                        `MEM_RESTING:begin
                            CNT               <= 1;
                            inst_fetch_status <= `ICACHE_WORKING;
                        end
                        // 加stall
                        `MEM_WORKING:begin
                            CNT               <= 2;
                            inst_fetch_status <= `ICACHE_NOP;
                        end
                        default:
                        $display("[ERROR]:unexpected mem_status when cnt == 2 in instruction cache\n");
                    endcase
                end
            end
            1:begin
                CNT               <= 0;
                inst_fetch_status <= `IF_FINISHED;
                inst[0]           <= mem_data;
                _instruction      <= mem_data;
            end
            0:begin
                // 真取指请求
                if (inst_fetch_enabled) begin
                    CNT               <= 2;
                    _current_addr     <= inst_addr;
                    inst_fetch_status <= `ICACHE_WORKING;
                    // 判断是否hit
                    _hit = `FALSE;
                    for (integer ind = 0 ;ind < ICACHE_SIZE ; ind = ind + 1) begin
                        if (inst_addr == inst_address[ind]) begin
                            _hit = `TRUE;
                            _instruction <= inst[ind];
                        end
                    end
                end
                // 尝试在main memory空闲时填补cache
                else begin
                    // todo
                end
            end
            default:
            $display("[ERROR]:unexpected cnt in instruction cache\n");
        endcase
    end
endmodule
