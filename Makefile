# current path
prefix = $(shell pwd)

# Folder Path
src = $(prefix)/src
testspace = $(prefix)/testspace
testcase = $(prefix)/testcase
sim_testcase = $(prefix)/testcase/sim
fpga_testcase = $(prefix)/testcase/fpga
sim = $(prefix)/sim
sys = $(prefix)/sys

# toolchain path
rvv_toolchain = /opt/rvv
# bin path
rvv_bin = $(rvv_toolchain)/bin


_no_testcase_name_check:
	@$(if $(strip $(name)),, echo 'Missing Testcase Name')
	@$(if $(strip $(name)),, exit 1)

# All build result are put at testspace/test
# compile verilog project with iverilog
# complie $(sim)/my_tb.v and related files under common
# if compile all the files, include not needed
build_sim:
	@ iverilog -o $(testspace)/test $(sim)/testbench.v 


build_sim_test: _no_testcase_name_check
	@$(rvv_bin)/riscv64-unknown-linux-gnu-as -o $(sys)/rom.o -march=rv64gv -mabi=lp64  $(sys)/rom.s
	@cp $(testcase)/*$(name)*.c $(testspace)/test.c
	@$(rvv_bin)/riscv64-unknown-linux-gnu-gcc -o $(testspace)/test.o -I $(sys) -c $(testspace)/test.c -march=rv64gv -mabi=lp64 -Wall
	@$(rvv_bin)/riscv64-unknown-linux-gnu-ld -T $(sys)/memory.ld $(sys)/rom.o $(testspace)/test.o -L $(rvv_toolchain)/riscv64-unknown-linux-gnu/lib/ -L $(rvv_toolchain)/lib/gcc/riscv64-unknown-linux-gnu/12.0.1/  -lgcc  -o $(testspace)/test.om
	@$(rvv_bin)/riscv64-unknown-linux-gnu-objcopy -O verilog $(testspace)/test.om $(testspace)/test.data
	@$(rvv_bin)/riscv64-unknown-linux-gnu-objdump -D $(testspace)/test.om > $(testspace)/test.dump
	# @$(rvv_bin)/riscv64-unknown-linux-gnu-objdump -D $(testspace)/test.om > $(testcase)/$(name).dump


# run
run_sim:
	@cd $(testspace) && ./test

# clear
clear:
	@rm $(sys)/rom.o $(testspace)/test*

test_sim: build_sim build_sim_test run_sim


# .PHONY 在 Makefile 中用于声明伪目标
# 告诉 Make 工具该目标不对应一个实际的文件，而是需要执行相应的命令块
# make safely
.PHONY: _no_testcase_name_check build_sim build_sim_test run_sim clear test_sim
