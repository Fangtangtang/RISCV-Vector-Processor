// #############################################################################################################################
// DATA CACHE
// 
// 直接映射cache
// cache line为4byte
// 
// 接受来自memory controller的访存请求
// - 组合逻辑判断是否hit并反馈
// 如果miss，向memory发请求
// 
// cache中数据保持memory中顺序
// 传出数据时转为正常顺序
// #############################################################################################################################
`include"src/defines.v"

module DATA_CACHE#(parameter ADDR_WIDTH = 17,
                   parameter DATA_LEN = 32,
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter CACHE_SIZE = 16,
                   parameter CACHE_INDEX_SIZE = 4)
                  (input wire clk,
                   input [ADDR_WIDTH-1:0] data_addr,
                   input [2:0] data_type,                    // vsew
                   input [DATA_LEN-1:0] cache_written_data,
                   input [1:0] cache_vis_signal,
                   input [ENTRY_INDEX_SIZE:0] length,        // 1：单个
                   output cache_hit,
                   output reg [DATA_LEN-1:0] data,
                   output reg [1:0] d_cache_vis_status,
                   input [DATA_LEN-1:0] mem_data,
                   input [1:0] mem_status,
                   output reg [DATA_LEN-1:0] mem_written_data,
                   output reg [2:0] written_data_type,
                   output [ENTRY_INDEX_SIZE:0] write_length, // 1：单个
                   output [ADDR_WIDTH-1:0] mem_vis_addr,     // 访存地址
                   output reg [1:0] mem_vis_signal);
    
    localparam BYTE_SELECT      = 2;
    localparam CACHE_LINE_SIZE = 1<<BYTE_SELECT;
    localparam TAG_SIZE        = ADDR_WIDTH - CACHE_INDEX_SIZE - BYTE_SELECT;
    
    // 缓存数据
    reg valid [CACHE_SIZE-1:0];
    reg [TAG_SIZE-1:0] tag [CACHE_SIZE-1:0];
    reg [DATA_LEN-1:0] data_line [CACHE_SIZE-1:0]; // 一个cache line
    
    wire addr_tag         = data_addr[ADDR_WIDTH-1:CACHE_INDEX_SIZE+BYTE_SELECT];
    wire cache_line_index = data_addr[CACHE_INDEX_SIZE+BYTE_SELECT-1:BYTE_SELECT];
    wire select_bit       = data_addr[BYTE_SELECT-1:0];
    
    // + hit判断
    // 单字节
    wire byte_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag;
    // 半字
    wire half_word_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&(select_bit+1<CACHE_LINE_SIZE|| tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag);
    // 全字
    wire word_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&(select_bit+3<CACHE_LINE_SIZE|| tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag);
    // 如果所要的数据都有，hit
    // todo:EIGHT_BYTE
    wire hit         = (data_type == `ONE_BYTE&&byte_hit)||(data_type == `TWO_BYTE&&half_word_hit)||(data_type == `FOUR_BYTE&&word_hit);
    assign cache_hit = hit;
    
    assign write_length = length;
    
    // 接线取数据（从请求地址开始取字节，转为正常顺序）
    reg [DATA_LEN-1:0]          direct_data;
    
    reg [BYTE_SIZE-1:0]         direct_byte ;
    reg [2*BYTE_SIZE-1:0]       direct_half_word;
    reg [DATA_LEN-1:0]          direct_word;
    
    reg [DATA_LEN-1:0]          indirect_data;
    
    reg [BYTE_SIZE-1:0]         indirect_byte ;
    reg [2*BYTE_SIZE-1:0]       indirect_half_word;
    reg [DATA_LEN-1:0]          indirect_word;
    
    always @(*) begin
        case (select_bit)
            0:begin
                direct_byte      = data_line[cache_line_index][31:24];
                direct_half_word = data_line[cache_line_index][31:16];
                direct_word      = data_line[cache_line_index][31:0];
            end
            1:begin
                direct_byte      = data_line[cache_line_index][23:16];
                direct_half_word = data_line[cache_line_index][23:8];
                direct_word      = {data_line[cache_line_index][23:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:24]};
            end
            2:begin
                direct_byte      = data_line[cache_line_index][15:8];
                direct_half_word = data_line[cache_line_index][15:0];
                direct_word      = {data_line[cache_line_index][15:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:16]};
            end
            3:begin
                direct_byte      = data_line[cache_line_index][7:0];
                direct_half_word = {data_line[cache_line_index][7:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:24]};
                direct_word      = {data_line[cache_line_index][7:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:8]};
            end
            default:
            $display("[ERROR]:unexpected select_bit in data cache\n");
        endcase
    end
    
    always @(*) begin
        case(data_type)
            `ONE_BYTE:begin
                direct_data = {24'b0,direct_byte};
            end
            `TWO_BYTE:begin
                direct_data = {16'b0,direct_half_word[BYTE_SIZE-1:0],direct_half_word[2*BYTE_SIZE-1:BYTE_SIZE]};
            end
            `FOUR_BYTE:begin
                direct_data = {direct_word[BYTE_SIZE-1:0],direct_word[2*BYTE_SIZE-1:BYTE_SIZE],direct_word[3*BYTE_SIZE-1:2*BYTE_SIZE],direct_word[4*BYTE_SIZE-1:3*BYTE_SIZE]};
            end
            default:
            $display("[ERROR]:unexpected data type in data cache\n");
        endcase
    end
    
    always @(*) begin
        case (load_select_bit)
            0:begin
                indirect_byte      = data_line[load_cache_line_index][31:24];
                indirect_half_word = data_line[load_cache_line_index][31:16];
                indirect_word      = data_line[load_cache_line_index][31:0];
            end
            1:begin
                indirect_byte      = data_line[load_cache_line_index][23:16];
                indirect_half_word = data_line[load_cache_line_index][23:8];
                indirect_word      = {data_line[load_cache_line_index][23:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:24]};
            end
            2:begin
                indirect_byte      = data_line[load_cache_line_index][15:8];
                indirect_half_word = data_line[load_cache_line_index][15:0];
                indirect_word      = {data_line[load_cache_line_index][15:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:16]};
            end
            3:begin
                indirect_byte      = data_line[load_cache_line_index][7:0];
                indirect_half_word = {data_line[load_cache_line_index][7:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:24]};
                indirect_word      = {data_line[load_cache_line_index][7:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:8]};
            end
            default:
            $display("[ERROR]:unexpected load_select_bit in data cache\n");
        endcase
    end
    
    always @(*) begin
        case(requested_data_type)
            `ONE_BYTE:begin
                indirect_data = {24'b0,indirect_byte};
            end
            `TWO_BYTE:begin
                indirect_data = {16'b0,indirect_half_word[BYTE_SIZE-1:0],indirect_half_word[2*BYTE_SIZE-1:BYTE_SIZE]};
            end
            `FOUR_BYTE:begin
                indirect_data = {indirect_word[BYTE_SIZE-1:0],indirect_word[2*BYTE_SIZE-1:BYTE_SIZE],indirect_word[3*BYTE_SIZE-1:2*BYTE_SIZE],indirect_word[4*BYTE_SIZE-1:3*BYTE_SIZE]};
            end
            default:
            $display("[ERROR]:unexpected requested data type in data cache\n");
        endcase
    end
    
    // 转为内存顺序的数据
    reg [DATA_LEN-1:0] written_data;
    always @(*) begin
        case(requested_data_type)
            `ONE_BYTE:begin
                written_data = {cache_written_data[7:0],24'b0};
            end
            `TWO_BYTE:begin
                written_data = {cache_written_data[7:0],cache_written_data[15:8],16'b0};
            end
            `FOUR_BYTE:begin
                written_data = {cache_written_data[7:0],cache_written_data[15:8],cache_written_data[23:16],cache_written_data[31:24]};
            end
            default:
            $display("[ERROR]:unexpected data type in data cache\n");
        endcase
    end
    
    reg [2:0] requested_data_type;
    reg [ADDR_WIDTH-1:0] load_addr;
    reg [ADDR_WIDTH-1:0] _current_addr;
    assign mem_vis_addr = {_current_addr[ADDR_WIDTH-1:BYTE_SELECT],{BYTE_SELECT{1'b0}}};
    
    wire load_addr_tag          = load_addr[ADDR_WIDTH-1:CACHE_INDEX_SIZE+BYTE_SELECT];
    wire load_cache_line_index  = load_addr[CACHE_INDEX_SIZE+BYTE_SELECT-1:BYTE_SELECT];
    wire load_select_bit        = load_addr[BYTE_SELECT-1:0];
    wire extra_addr_tag         = _current_addr[ADDR_WIDTH-1:CACHE_INDEX_SIZE+BYTE_SELECT];
    wire extra_cache_line_index = _current_addr[CACHE_INDEX_SIZE+BYTE_SELECT-1:BYTE_SELECT];
    
    
    reg [1:0] CNT = 0;
    reg [1:0] task_type;
    
    always @(posedge clk) begin
        case(CNT)
            // 等待开始工作
            3:begin
                d_cache_vis_status <= `D_CACHE_WORKING;
                case (task_type)
                    `D_CACHE_LOAD:begin
                        CNT            <= 2;
                        mem_vis_signal <= `MEM_READ; // 读取单个数据
                    end
                    `D_CACHE_STORE:begin
                        CNT               <= 1;
                        mem_vis_signal    <= `MEM_WRITE;
                        mem_written_data  <= written_data;
                        written_data_type <= requested_data_type;
                    end
                    default:
                    $display("[ERROR]:unexpected task_type when cnt == 3 in data cache\n");
                endcase
            end
            // 工作中，处理mem数据，再次发起访存
            // load:一次要填充两个cache line，再从cache line中取数据
            2:begin
                if (mem_status == `MEM_DATA_FINISHED) begin
                    CNT                              <= 1;
                    mem_vis_signal                   <= `MEM_READ; // 读取单个数据
                    _current_addr                    <= _current_addr+CACHE_LINE_SIZE;
                    valid[load_cache_line_index]     <= 1;
                    tag[load_cache_line_index]       <= load_addr_tag;
                    data_line[load_cache_line_index] <= mem_data;
                end
                else begin
                    CNT                <= 2;
                    d_cache_vis_status <= `D_CACHE_STALL;
                end
            end
            // 工作中，处理mem数据
            // load:填充两个cache line
            // store:直接向内存指定位置写该数据
            1:begin
                if (mem_status == `MEM_DATA_FINISHED) begin
                    CNT                <= 0;
                    mem_vis_signal     <= `MEM_NOP;
                    d_cache_vis_status <= `L_S_FINISHED;
                    case (task_type)
                        `D_CACHE_LOAD:begin
                            valid[extra_cache_line_index]     <= 1;
                            tag[extra_cache_line_index]       <= extra_addr_tag;
                            data_line[extra_cache_line_index] <= mem_data;
                            data                              <= indirect_data;
                        end
                        `D_CACHE_STORE:begin
                            // todo?
                        end
                        default:
                        $display("[ERROR]:unexpected task_type when cnt == 1 in data cache\n");
                    endcase
                end
                else begin
                    CNT                <= 1;
                    d_cache_vis_status <= `D_CACHE_STALL;
                end
            end
            // 工作完成或任务发布
            0:begin
                mem_vis_signal <= `MEM_NOP;
                // data cache处于空闲状态，开启新任务
                if (task_type == `D_CACHE_REST) begin
                    requested_data_type <= data_type;
                    task_type           <= cache_vis_signal;
                    case (cache_vis_signal)
                        `D_CACHE_NOP:begin
                            CNT                <= 0;
                            d_cache_vis_status <= `L_S_FINISHED;
                        end
                        // 都表现为
                        `D_CACHE_LOAD:begin
                            if (hit)begin
                                data               <= direct_data;
                                CNT                <= 0;
                                d_cache_vis_status <= `L_S_FINISHED;
                            end
                            else begin
                                CNT                <= 3;
                                d_cache_vis_status <= `D_CACHE_WORKING;
                                _current_addr      <= data_addr;
                                load_addr          <= data_addr;
                            end
                        end
                        `D_CACHE_STORE:begin
                            CNT                <= 3;
                            d_cache_vis_status <= `D_CACHE_WORKING;
                            _current_addr      <= data_addr;
                        end
                        default:
                        $display("[ERROR]:unexpected cache_vis_signal in data cache\n");
                    endcase
                end
                else begin
                    task_type          <= `D_CACHE_REST;
                    d_cache_vis_status <= `D_CACHE_RESTING;
                end
            end
            default:
            $display("[ERROR]:unexpected cnt in data cache\n");
        endcase
    end
endmodule