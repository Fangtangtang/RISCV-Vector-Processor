// #############################################################################################################################
// TESTBENCH
// 
// testbench top module file
// for simulation only
// #############################################################################################################################

`include "src/top.v"

`timescale 1ns/1ps

module testbench();
    
    reg clk;
    reg rst;
    
    top#(
    .SIM(1),
    .LEN(32)
    )
    top_(
    .EXCLK(clk),
    .btnC(rst),
    .Tx(),
    .Rx(),
    .led()
    );
    
    initial begin
        clk               = 0;
        rst               = 1;
        repeat(50) #1 clk = !clk;
        rst               = 0;
        forever #1 clk    = !clk;
        
        $finish;
    end
    
    // 生成vcd文件
    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0, testbench);
        $dumpall;
        #3000 $finish;
    end
    
endmodule
