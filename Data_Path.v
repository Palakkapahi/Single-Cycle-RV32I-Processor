module data_path(
    input clk, rst,
    input [31:0] instr,
    input [31:0] pc_plus4,       

    output beq_taken, bneq_taken, bge_taken, blt_taken, bgeu_taken, bltu_taken,
    output jump_taken,
    output [31:0] imm_val_out     
);

    // instruction field breakdown
    wire [6:0] funct7  = instr[31:25];
    wire [2:0] funct3  = instr[14:12];
    wire [6:0] opcode  = instr[6:0];
    wire [4:0] rs1_addr = instr[19:15];
    wire [4:0] rs2_addr = instr[24:20];
    wire [4:0] rd_addr  = instr[11:7];

    // control signals
    wire [5:0] alu_input;
    wire lb, sb, mem_to_reg, BNEQ, BEQ, BLT, BGE, JUMP, LUI, SW, BGEU, BLTU, reg_write;

    // data signals
    wire [31:0] imm_val;
    wire [31:0] rs1, rs2;
    wire [31:0] alu_result;
    wire [31:0] mem_read_data;
    wire [31:0] data_out_2_dm;

    CONTROL_UNIT cu(
        .reset(rst),
        .funct7(funct7),
        .funct3(funct3),
        .opcode(opcode),
        .alu_input(alu_input),
        .lb(lb), .sb(sb),
        .mem_to_reg(mem_to_reg),
        .BNEQ(BNEQ), .BEQ(BEQ), .BLT(BLT), .BGE(BGE),
        .JUMP(JUMP), .LUI(LUI), .SW(SW),
        .BGEU(BGEU), .BLTU(BLTU),
        .reg_write(reg_write)
    );

    imm_gen ig(
        .instr(instr),
        .imm_val(imm_val)
    );

    register_file rfu(
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .alu_result(alu_result),
        .mem_read_data(mem_read_data),
        .lui_imm_val(imm_val),     
        .pc_plus4(pc_plus4),
        .reg_write(reg_write),
        .mem_to_reg(mem_to_reg),
        .lui_control(LUI),
        .jump(JUMP),
        .rs1(rs1), .rs2(rs2),
        .data_out_2_dm(data_out_2_dm)
    );

    ALU alu_unit(
        .rs1(rs1), .rs2(rs2),
        .alu_input(alu_input),
        .imm_val(imm_val),
        .result(alu_result)
    );

    data_memory dmu(
        .clk(clk), .rst(rst),
        .address(alu_result),     
        .write_data(data_out_2_dm),
        .sw(SW), .sb(sb), .lb(lb),
        .data_out(mem_read_data)
    );

    assign beq_taken  = alu_result[0] && BEQ;
    assign bneq_taken = alu_result[0] && BNEQ;
    assign bge_taken  = alu_result[0] && BGE;
    assign blt_taken  = alu_result[0] && BLT;
    assign bgeu_taken = alu_result[0] && BGEU;
    assign bltu_taken = alu_result[0] && BLTU;
    assign jump_taken = JUMP;
    assign imm_val_out = imm_val;

endmodule
