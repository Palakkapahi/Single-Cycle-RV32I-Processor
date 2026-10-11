# Single-Cycle-RV32I-Processor

This project implements a single-cycle RV32I RISC-V processor in Verilog, supporting 31 instructions with a modular datapath and control unit. The design is split into an instruction fetch unit, control unit, ALU, register file, immediate generator, and instruction and data memories, all connected through a top-level module.

The processor is verified using a self-checking cocotb testbench. It combines directed tests, seeded random testing against a Python golden reference model, and program-level execution (Fibonacci) to validate dependent instruction sequences. A monitor tracks every executed opcode, and the testbench reaches 100% instruction coverage (31/31).

## Tools
Verilog, cocotb, Python, Icarus Verilog
