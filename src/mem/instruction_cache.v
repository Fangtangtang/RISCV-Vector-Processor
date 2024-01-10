// #############################################################################################################################
// INSTRUCTION CACHE
// 
// - cache size = 2，暂时仅作为memory controller
// - inst_fetch_enable能中断flash
// 
// 从内存中读出的数据在这里转变为正确顺序
// #############################################################################################################################
`include"src/defines.v"

module INSTRUCTION_CACHE#(parameter ADDR_WIDTH = 17,
                          parameter LEN = 32,
                          parameter BYTE_SIZE = 8,
                          parameter I_CACHE_SIZE = 2,
                          parameter INDEX_SIZE = 1)
                         (input wire clk,
                          input [ADDR_WIDTH-1:0] inst_addr,     // instruction fetch
                          input inst_fetch_enabled,
                          output [LEN-1:0] instruction,
                          output reg [1:0] inst_fetch_status,
                          input [LEN-1:0] mem_data,             // interact with main memory
                          input [1:0] mem_status,
                          output [ADDR_WIDTH-1:0] mem_vis_addr, // 访存地址
                          output reg [1:0] mem_vis_signal);
    
    // reordered data
    wire reorder_mem_data = {mem_data[7:0],mem_data[15:8],mem_data[23:16],mem_data[31:24]};
    
    // 全关联cache
    reg valid [I_CACHE_SIZE-1:0];
    reg [ADDR_WIDTH-1:0] inst_address [I_CACHE_SIZE-1:0];
    reg [LEN-1:0] inst [I_CACHE_SIZE-1:0];
    
    reg [1:0] CNT = 0;
    
    reg [LEN-1:0] _instruction;
    assign instruction = _instruction;
    
    reg _hit;
    reg _flash;
    reg [INDEX_SIZE-1:0] _current_index = 0; // 当前地址对应的entry下标
    reg [ADDR_WIDTH-1:0] _requested_addr;
    reg [ADDR_WIDTH-1:0] _current_addr = 0;
    
    assign mem_vis_addr = _current_addr;
    
    reg [1:0] mem_vis_type = 0;
    
    always @(posedge clk) begin
        case (CNT)
            2:begin
                // 处理真取指令请求
                if (_hit) begin
                    CNT               <= 0;
                    mem_vis_signal    <= `MEM_NOP;
                    inst_fetch_status <= `IF_FINISHED;
                    mem_vis_type      <= `MEM_NOP;
                    _hit = `FALSE;
                end
                else begin
                    inst_address[0] <= _requested_addr;
                    valid[0]        <= `TRUE;
                    _current_addr   <= _requested_addr;
                    _current_index  <= 0;
                    case (mem_status)
                        // 可以访存
                        `MEM_RESTING:begin
                            CNT               <= 1;
                            mem_vis_signal    <= `MEM_READ;
                            inst_fetch_status <= `I_CACHE_WORKING;
                        end
                        // 加stall
                        `MEM_INST_WORKING:begin
                            CNT               <= 2;
                            mem_vis_signal    <= `MEM_NOP;
                            inst_fetch_status <= `I_CACHE_STALL;
                        end
                        `MEM_DATA_WORKING:begin
                            CNT               <= 2;
                            mem_vis_signal    <= `MEM_NOP;
                            inst_fetch_status <= `I_CACHE_STALL;
                        end
                        default:
                        $display("[ERROR]:unexpected mem_status when cnt == 2 in instruction cache\n");
                    endcase
                end
                // 处理flash
                if (_flash) begin
                    if (inst_fetch_enabled) begin
                        CNT    <= 0;
                        _flash <= `FALSE;
                    end
                    else begin
                        case (mem_status)
                            // 可以访存
                            `MEM_RESTING:begin
                                CNT               <= 1;
                                mem_vis_signal    <= `MEM_READ;
                                inst_fetch_status <= `I_CACHE_WORKING;
                            end
                            // 加stall
                            `MEM_INST_WORKING:begin
                                CNT               <= 2;
                                mem_vis_signal    <= `MEM_NOP;
                                inst_fetch_status <= `I_CACHE_STALL;
                            end
                            `MEM_DATA_WORKING:begin
                                CNT               <= 2;
                                mem_vis_signal    <= `MEM_NOP;
                                inst_fetch_status <= `I_CACHE_STALL;
                            end
                            default:
                            $display("[ERROR]:unexpected mem_status when cnt == 2 in instruction cache\n");
                        endcase
                    end
                end
            end
            1:begin
                case (mem_status)
                    `MEM_INST_WORKING: begin
                        mem_vis_signal <= `MEM_NOP;
                        // 取指令
                        if (!_flash) begin
                            _instruction      <= reorder_mem_data;
                            CNT               <= 2;
                            inst_fetch_status <= `IF_FINISHED;
                            _flash            <= `TRUE;
                        end
                        // flash
                        inst[_current_index] <= reorder_mem_data;
                        // flash结束
                        if (_current_index == I_CACHE_SIZE-1) begin
                            CNT               <= 0;
                            inst_fetch_status <= `I_CACHE_RESTING;
                            _flash            <= `FALSE;
                            mem_vis_type      <= `MEM_NOP;
                        end
                        // 继续flash
                        else begin
                            inst_address[_current_index+1] <= _current_addr+4;
                            valid[_current_index+1]        <= `TRUE;
                            _current_index                 <= _current_index+1;
                            _current_addr                  <= _current_addr+4;
                            CNT                            <= 2;
                            if (_flash) begin
                                inst_fetch_status <= `I_CACHE_WORKING;
                            end
                        end
                    end
                    // 数据读取优先，加stall
                    `MEM_DATA_WORKING:begin
                        CNT               <= 2;
                        mem_vis_signal    <= `MEM_NOP;
                        inst_fetch_status <= `I_CACHE_STALL;
                    end
                    default:
                    $display("[ERROR]:unexpected mem_status when cnt == 1 in instruction cache\n");
                endcase
                
            end
            0:begin
                mem_vis_signal <= `MEM_NOP;
                // 真取指令请求
                if (inst_fetch_enabled) begin
                    CNT               <= 2;
                    _requested_addr   <= inst_addr;
                    inst_fetch_status <= `I_CACHE_WORKING;
                    mem_vis_type      <= `MEM_READ;
                    // 判断是否hit
                    _hit = `FALSE;
                    for (integer ind = 0 ;ind < I_CACHE_SIZE ; ind = ind + 1) begin
                        if (inst_addr == inst_address[ind]&&valid[ind]) begin
                            _hit = `TRUE;
                            _instruction <= inst[ind];
                        end
                    end
                end
            end
            default:
            $display("[ERROR]:unexpected cnt in instruction cache\n");
        endcase
    end
    
    
endmodule
