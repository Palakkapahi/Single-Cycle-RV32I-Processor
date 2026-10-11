module top(
    input clk,
    input reset
);
    wire [31:0] pc;
    wire [31:0] current_pc;     // pc+4, used for JAL writeback
    wire [31:0] instr;
    wire [31:0] imm_val;

    wire beq_taken, bneq_taken, bge_taken, blt_taken, bgeu_taken, bltu_taken, jump_taken;

    instruction_memory imu(
        .clk(clk),
        .pc(pc),
        .reset(reset),
        .instruction_code(instr)
    );

    data_path dpu(
        .clk(clk), .rst(reset),
        .instr(instr),
        .pc_plus4(current_pc),
        .beq_taken(beq_taken), .bneq_taken(bneq_taken),
        .bge_taken(bge_taken), .blt_taken(blt_taken),
        .bgeu_taken(bgeu_taken), .bltu_taken(bltu_taken),
        .jump_taken(jump_taken),
        .imm_val_out(imm_val)
    );

    IFU ifu(
        .clk(clk), .reset(reset),
        .immediate_address(imm_val),       
        .immediate_address_jump(imm_val), 
        .BEQ(beq_taken), .BNEQ(bneq_taken),
        .BGE(bge_taken), .BLT(blt_taken),
        .JUMP(jump_taken),
        .BGEU(bgeu_taken), .BLTU(bltu_taken),
        .program_counter(pc),
        .current_program_counter(current_pc)
    );

endmodule
