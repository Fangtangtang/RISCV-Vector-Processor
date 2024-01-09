// #############################################################################################################################
// DATA CACHE
// 
// 存放向量数据
// - write through
// - 向量数据read burst
// - 同时包含向量数据和标量数据
// - 享有访存优先
// 
// todo: scalar data type
// #############################################################################################################################
`include"src/defines.v"

module DATA_CACHE#(parameter ADDR_WIDTH = 17,
                   parameter LEN = 32,
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter S_CACHE_SIZE = 4,
                   parameter S_CACHE_INDEX_SIZE = 2,
                   parameter V_CACHE_SIZE = 1,
                   parameter V_CACHE_INDEX_SIZE = 1)
                  (input wire clk,
                   input [ADDR_WIDTH-1:0] data_addr,
                   input mem_access_enabled,
                   input is_vector,                                // 是否为向量访存
                   input [1:0] d_cache_vis_signal,
                   input [ENTRY_INDEX_SIZE:0] length,
                   output reg [LEN-1:0] scalar_data,
                   output reg [LEN*VECTOR_SIZE-1:0] vector_data,
                   input [LEN-1:0] writen_scalar_data,
                   input [LEN*VECTOR_SIZE-1:0] writen_vector_data,
                   output reg [1:0] mem_vis_status,                // interact with main memory
                   input [LEN-1:0] mem_data,
                   input [1:0] mem_status,
                   output reg [LEN-1:0] mem_writen_data,           // 写入memory的数据
                   output [ENTRY_INDEX_SIZE:0] write_length,
                   output [ADDR_WIDTH-1:0] mem_vis_addr,           // 访存地址
                   output reg [1:0] mem_vis_signal);
    genvar i;
    
    reg visit_vector;
    
    // 标量数据
    reg s_valid [S_CACHE_SIZE-1:0];
    reg [ADDR_WIDTH-1:0] s_addr [S_CACHE_SIZE-1:0];
    reg [LEN-1:0] s_data[S_CACHE_SIZE-1:0];
    
    // s_cache相关
    wire s_cache_hit;
    reg [S_CACHE_INDEX_SIZE-1:0] s_cache_hit_index; // attention:是否导致延迟更新？
    generate
    for (i = 0;i < S_CACHE_SIZE; i = i + 1) begin
        assign s_cache_hit = |((data_addr == s_addr[i]&&s_valid[i])? `TRUE : `FALSE);
    end
    endgenerate
    always @(*) begin
        for (integer j = 0;j < S_CACHE_SIZE; j = j + 1) begin
            if (data_addr == s_addr[j]&&s_valid[j]) begin
                s_cache_hit_index = j;
            end
        end
    end
    
    reg s_cache_victim = 0; // 队列型
    
    // 向量数据
    reg [ADDR_WIDTH-1:0] starting_addr;
    reg valid[VECTOR_SIZE-1:0];
    reg [LEN-1:0] v_data[VECTOR_SIZE-1:0];
    
    
    wire [LEN*VECTOR_SIZE-1:0] _data;
    generate
    for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        assign _data[(i+1)*LEN-1 -: LEN] = v_data[i]; // (i+1)*LEN-1 计算切片的起始位置。-: 操作符表示选择从起始位置开始的连续 LEN 个位
    end
    endgenerate
    
    wire [LEN-1:0] _writen_data[VECTOR_SIZE-1:0];
    generate
    for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        assign _writen_data[i] = writen_vector_data[((VECTOR_SIZE-i)*LEN)-1 : (VECTOR_SIZE-i-1)*LEN];
    end
    endgenerate
    
    reg [1:0] CNT = 0;
    reg [1:0] task_type;
    
    reg [ENTRY_INDEX_SIZE:0] _requested_length;
    
    reg [ENTRY_INDEX_SIZE-1:0] _current_index;
    reg [V_CACHE_INDEX_SIZE-1:0] _current_v_cache_line;
    reg [ADDR_WIDTH-1:0] _current_addr;
    
    assign mem_vis_addr = _current_addr;
    assign write_length = length;
    
    always @(posedge clk) begin
        case (CNT)
            // 等待开始工作
            2:begin
                case (mem_status)
                    `MEM_INST_WORKING:begin
                        CNT            <= 2;
                        mem_vis_signal <= `MEM_NOP;
                        mem_vis_status <= `D_CACHE_STALL;
                    end
                    `MEM_DATA_WORKING:begin
                        CNT            <= 2;
                        mem_vis_signal <= `MEM_NOP;
                        mem_vis_status <= `D_CACHE_STALL;
                    end
                    `MEM_RESTING:begin
                        CNT            <= 1;
                        mem_vis_status <= `D_CACHE_WORKING;
                        case (task_type)
                            `D_CACHE_LOAD:begin
                                if (visit_vector) begin
                                    mem_vis_signal <= `MEM_READ_BURST; // 批量读取
                                end
                                else begin
                                    mem_vis_signal <= `MEM_READ; // 读取单个数据
                                end
                            end
                            `D_CACHE_STORE:begin
                                mem_vis_signal <= `MEM_WRITE;
                                if (visit_vector) begin
                                    mem_writen_data <= _writen_data[0]; // 第一个待写数据
                                end
                                else begin
                                    mem_writen_data <= writen_scalar_data;
                                end
                            end
                            default:
                            $display("[ERROR]:unexpected task_type when cnt == 2 in data cache\n");
                        endcase
                    end
                    default:
                    $display("[ERROR]:unexpected mem_status when cnt == 2 in data cache\n");
                endcase
            end
            // 工作中，处理mem数据，再次发起访存
            1:begin
                case (task_type)
                    `D_CACHE_LOAD:begin
                        // vector
                        if (visit_vector) begin
                            v_data[_current_index] <= mem_data;
                            valid[_current_index]  <= 1;
                            // data burst未完成
                            if (_current_index+1 < VECTOR_SIZE) begin
                                _current_index <= _current_index + 1;
                                CNT            <= 1;
                                mem_vis_signal <= `MEM_READ_BURST;
                                // 需要的数据已经取到
                                if (_current_index+1 == _requested_length) begin
                                    vector_data    <= _data; // todo:要不要只取length个
                                    mem_vis_status <= `L_S_FINISHED;
                                end
                                else begin
                                    mem_vis_status <= `D_CACHE_WORKING;
                                end
                            end
                            // data burst完成
                            else begin
                                CNT <= 0;
                                // 需要的数据已经取到
                                if (_current_index+1 == _requested_length) begin
                                    vector_data    <= _data; // todo:要不要只取length个
                                    mem_vis_status <= `L_S_FINISHED;
                                end
                                else begin
                                    mem_vis_signal <= `MEM_NOP;
                                    mem_vis_status <= `D_CACHE_RESTING;
                                end
                            end
                        end
                        // scalar
                        else begin
                            CNT                     <= 0;
                            scalar_data             <= mem_data;
                            s_data[s_cache_victim]  <= mem_data;
                            s_valid[s_cache_victim] <= `TRUE;
                            s_cache_victim          <= s_cache_victim+1;
                            mem_vis_status          <= `L_S_FINISHED;
                        end
                    end
                    `D_CACHE_STORE:begin
                        // vector
                        if (visit_vector)begin
                            // 未结束
                            if (_current_index+1 < VECTOR_SIZE)begin
                                _current_index  <= _current_index + 1;
                                mem_writen_data <= _writen_data[_current_index+1];
                                CNT             <= 1;
                                mem_vis_signal  <= `MEM_WRITE;
                                mem_vis_status  <= `D_CACHE_WORKING;
                            end
                            // 结束
                            else begin
                                CNT            <= 0;
                                mem_vis_status <= `L_S_FINISHED;
                                mem_vis_signal <= `MEM_NOP;
                            end
                        end
                        // scalar
                        else begin
                            CNT            <= 0;
                            mem_vis_status <= `L_S_FINISHED;
                        end
                    end
                    default:
                    $display("[ERROR]:unexpected task_type when cnt == 1 in data cache\n");
                endcase
            end
            // 工作完成或任务发布
            0:begin
                mem_vis_signal <= `MEM_NOP;
                // data cache处于空闲状态
                if (task_type == `D_CACHE_REST) begin
                    if (mem_access_enabled) begin
                        task_type    <= d_cache_vis_signal;
                        visit_vector <= is_vector;
                        case (d_cache_vis_signal)
                            `D_CACHE_NOP:begin
                                CNT            <= 0;
                                mem_vis_status <= `L_S_FINISHED;
                            end
                            `D_CACHE_LOAD:begin
                                // load vector
                                if (is_vector) begin
                                    // todo:hit(可以进一步优化)，当前版本基本只是mem controler
                                    if (data_addr == starting_addr&&valid[length-1]) begin
                                        vector_data    <= _data; // todo:要不要只取length个
                                        CNT            <= 0;
                                        mem_vis_status <= `L_S_FINISHED;
                                    end
                                    else begin
                                        CNT               <= 2;
                                        mem_vis_status    <= `D_CACHE_WORKING;
                                        _requested_length <= length;
                                        starting_addr     <= data_addr;
                                        _current_addr     <= data_addr;
                                        _current_index    <= 0;
                                        for (integer i = 0;i < VECTOR_SIZE;i = i + 1) begin
                                            valid[i] <= 0;
                                        end
                                    end
                                end
                                // load scalar
                                else begin
                                    // hit
                                    if (s_cache_hit)begin
                                        scalar_data    <= s_data[s_cache_hit_index];
                                        CNT            <= 0;
                                        mem_vis_status <= `L_S_FINISHED;
                                    end
                                    else begin
                                        CNT                    <= 2;
                                        mem_vis_status         <= `D_CACHE_WORKING;
                                        _current_addr          <= data_addr;
                                        s_addr[s_cache_victim] <= data_addr;
                                    end
                                end
                            end
                            `D_CACHE_STORE:begin
                                CNT            <= 2;
                                mem_vis_status <= `D_CACHE_WORKING;
                                _current_addr  <= data_addr;
                                // vector
                                if (visit_vector) begin
                                    _requested_length <= length;
                                    _current_index    <= 0;
                                    // update cache
                                    // hit
                                    if (data_addr == starting_addr&&valid[length-1]) begin
                                        for (integer i = 0;i < length;i = i + 1) begin
                                            valid[i]  <= 1;
                                            v_data[i] <= _writen_data[i];
                                        end
                                    end
                                    else begin
                                        starting_addr <= data_addr;
                                        for (integer i = 0;i < length;i = i + 1) begin
                                            valid[i]  <= 1;
                                            v_data[i] <= _writen_data[i];
                                        end
                                        for (integer i = length;i < VECTOR_SIZE;i = i + 1) begin
                                            valid[i] <= 0;
                                        end
                                    end
                                end
                                // scalar
                                else begin
                                    // hit
                                    if (s_cache_hit)begin
                                        s_data[s_cache_hit_index] <= writen_scalar_data;
                                    end
                                end
                            end
                            default:
                            $display("[ERROR]:unexpected vis_signal in data cache\n");
                        endcase
                    end
                end
                else begin
                    task_type      <= `D_CACHE_REST;
                    mem_vis_status <= `D_CACHE_RESTING;
                end
            end
            default:
            $display("[ERROR]:unexpected cnt in data cache\n");
        endcase
    end
    
endmodule
