SIM ?= icarus
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(PWD)/Top.v \
                  $(PWD)/Data_Path.v \
                  $(PWD)/Control_Unit.v \
                  $(PWD)/ALU.v \
                  $(PWD)/Register_File.v \
                  $(PWD)/Immediate_Generator.v \
                  $(PWD)/Instruction_File_Unit.v \
                  $(PWD)/Instruction_Memory.v \
                  $(PWD)/Data_Memory.v
TOPLEVEL = top
MODULE = testbench
COMPILE_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim
