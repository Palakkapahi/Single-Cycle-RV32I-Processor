module IFU(
    input clk, reset,
    input [31:0] immediate_address,
    input [31:0] immediate_address_jump,
    input BEQ, BNEQ, BGE, BLT, JUMP, BGEU, BLTU,
    output reg [31:0] program_counter,
    output [31:0] current_program_counter   // was: output reg
);

  wire if_set = BEQ | BNEQ | BGE | BLT | BLTU | BGEU;
  wire [1:0] sel = {JUMP, if_set};

  always @(posedge clk) begin
      if (reset)
          program_counter <= 0;
      else begin
          case (sel)
              2'b00 : program_counter <= program_counter + 4;
              2'b01 : program_counter <= program_counter + immediate_address;
              2'b10 : program_counter <= program_counter + immediate_address_jump;
              2'b11 : program_counter <= program_counter + immediate_address_jump;
          endcase
      end
  end

  assign current_program_counter = program_counter + 4;

endmodule
