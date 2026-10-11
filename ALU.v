module ALU(
    input [31:0] rs1,
    input [31:0] rs2,
    input [5:0] alu_input,
    input [31:0] imm_val,
output reg [31:0] result
);

    always @(*) begin
        result = 32'b0;
        case (alu_input)
            6'b000001 : result = rs1 + rs2;
            6'b000010 : result = rs1 - rs2;
            6'b000011 : result = rs1 << rs2[4:0];
            6'b000100 : result = ($signed(rs1) < $signed(rs2)) ? 32'd1 : 32'd0;
            6'b000101 : result = (rs1 < rs2) ? 32'd1 : 32'd0; // unsigned
            6'b000111 : result = rs1 >> rs2[4:0];
            6'b001000 : result = $signed(rs1) >>> rs2[4:0];
            6'b000110 : result = rs1 ^ rs2;
            6'b001001 : result = rs1 | rs2;
            6'b001010 : result = rs1 & rs2;

            6'b001011 : result = rs1 + imm_val; // ADDI
            6'b001100 : result = rs1 << imm_val[4:0]; // SLLI
            6'b001101 : result = ($signed(rs1) < $signed(imm_val)) ? 32'd1 : 32'd0; // SLTI
            6'b001110 : result = (rs1 < imm_val) ? 32'd1 : 32'd0; // SLTIU
            6'b001111 : result = rs1 ^ imm_val; // XORI
            6'b010000 : result = rs1 >> imm_val[4:0]; // SRLI
            6'b010001 : result = $signed(rs1) >>> imm_val[4:0]; // SRAI
            6'b010010 : result = rs1 | imm_val; // ORI
            6'b010011 : result = rs1 & imm_val; // ANDI

            6'b011011 : result = (rs1 == rs2) ? 32'd1 : 32'd0; // BEQ
            6'b011100 : result = (rs1 != rs2) ? 32'd1 : 32'd0; // BNE
            6'b011101 : result = ($signed(rs1) < $signed(rs2)) ? 32'd1 : 32'd0; // BLT
            6'b011110 : result = ($signed(rs1) >= $signed(rs2)) ? 32'd1 : 32'd0; // BGE
            6'b011111 : result = (rs1 < rs2) ? 32'd1 : 32'd0; // BLTU
            6'b100000 : result = (rs1 >= rs2) ? 32'd1 : 32'd0; // BGEU
            default   : result = 32'b0;
        endcase
    end
endmodule
