module CONTROL_UNIT(
    input reset,
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,
    output reg [5:0] alu_input,
    output reg lb, mem_to_reg, SW, sb,
    output reg BNEQ, BEQ, BLT, BGE, JUMP, LUI, BGEU, BLTU,
    output reg reg_write
);

  always @(*) begin
      alu_input = 6'b000000;
      mem_to_reg = 0;
      BEQ = 0; BNEQ = 0; BGE = 0; BLT = 0; BGEU = 0; BLTU = 0;
      JUMP = 0; LUI = 0; SW = 0; sb=0; lb = 0; reg_write = 0;

      if (reset) begin
          alu_input = 6'b000000;
      end

      else if (opcode == 7'b0110011) begin // R-type
          reg_write = 1;
          case ({funct7[5], funct3})
              4'b0000 : alu_input = 6'b000001; // add
              4'b1000 : alu_input = 6'b000010; // subtract
              4'b0001 : alu_input = 6'b000011; // sll
              4'b0010 : alu_input = 6'b000100; // slt
              4'b0011 : alu_input = 6'b000101; // sltu
              4'b0101 : alu_input = 6'b000111; // srl
              4'b1101 : alu_input = 6'b001000; // sra
              4'b0100 : alu_input = 6'b000110; // xor
              4'b0110 : alu_input = 6'b001001; // or
              4'b0111 : alu_input = 6'b001010; // and
              default : alu_input = 6'b000000;
          endcase
      end

      else if (opcode == 7'b0010011) begin // I-type
          reg_write = 1;
          case (funct3)
              3'b000: alu_input = 6'b001011; // ADDI
              3'b001: alu_input = 6'b001100; // SLLI
              3'b010: alu_input = 6'b001101; // SLTI
              3'b011: alu_input = 6'b001110; // SLTIU
              3'b100: alu_input = 6'b001111; // XORI
              3'b101: alu_input = funct7[5] ? 6'b010001 : 6'b010000; // SRAI : SRLI
              3'b110: alu_input = 6'b010010; // ORI
              3'b111: alu_input = 6'b010011; // ANDI
          endcase
      end

else if (opcode == 7'b0000011) begin // LOAD (I-type) 
reg_write = 1;
mem_to_reg = 1; 
alu_input = 6'b001011; // same as ADDI: address = rs1 + imm 
case (funct3) 
3'b000: lb = 1; // LB — byte load, sign-extended 
3'b010: lb = 0; // LW — word load 
default: ; 
endcase 
end 

 else if (opcode == 7'b0100011) begin // STORE (S-type)
    alu_input = 6'b001011; // address = rs1 + imm
    SW = 1; // store enable, true for both SB and SW
    case (funct3)
        3'b000: sb = 1; // SB — byte only
        3'b010: sb = 0; // SW — full word
        default: ;
    endcase
end

 else if (opcode == 7'b0110111) begin // LUI
          reg_write = 1;
          LUI = 1;
      end

      else if (opcode == 7'b1100011) begin // B-type
          case (funct3)
              3'b000: begin alu_input = 6'b011011; BEQ  = 1; end
              3'b001: begin alu_input = 6'b011100; BNEQ = 1; end
              3'b100: begin alu_input = 6'b011101; BLT  = 1; end
              3'b101: begin alu_input = 6'b011110; BGE  = 1; end
              3'b110: begin alu_input = 6'b011111; BLTU = 1; end
              3'b111: begin alu_input = 6'b100000; BGEU = 1; end
              default: ;
          endcase
      end

      else if (opcode == 7'b1101111) begin // JAL
          reg_write = 1;
          alu_input = 6'b100010;
          JUMP = 1;
      end
  end
endmodule
