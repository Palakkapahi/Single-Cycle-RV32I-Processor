module instruction_memory(
    input clk,
    input [31:0] pc,
    input reset,
    output [31:0] instruction_code
);
    reg [7:0] memory [127:0];
    integer k;

    assign instruction_code = {memory[pc+3], memory[pc+2], memory[pc+1], memory[pc]};

    task put(input integer a, input [31:0] w);
        begin
            memory[a]   = w[7:0];
            memory[a+1] = w[15:8];
            memory[a+2] = w[23:16];
            memory[a+3] = w[31:24];
        end
    endtask

    initial begin
        // fill everything with NOP (addi x0,x0,0) so skipped slots are never X
        for (k = 0; k < 128; k = k + 4) put(k, 32'h00000013);

        put(0,  32'h00940333); // ADD  x6,x8,x9
        put(4,  32'h403100b3); // SUB  x1,x2,x3
        put(8,  32'h00209133); // SLL  x2,x1,x2
        put(12, 32'h00c544b3); // XOR  x9,x10,x12
        put(16, 32'h00c554b3); // SRL  x9,x10,x12
        put(20, 32'h41bd5f33); // SRA  x30,x26,x27
        put(24, 32'h00d66fb3); // OR   x31,x12,x13
        put(28, 32'h0107fbb3); // AND  x23,x15,x16
        put(32, 32'h00a08513); // ADDI x10,x1,10
        put(36, 32'h00491913); // SLLI x18,x18,4
        put(40, 32'h0637c713); // XORI x14,x15,99
        put(44, 32'h00a0a093); // SLTI x1,x1,10
        put(48, 32'h00335093); // SRLI x1,x6,3
        put(52, 32'h00f36093); // ORI  x1,x6,15
        put(56, 32'h00f77093); // ANDI x1,x14,15
        put(60, 32'h00432283); // LW   x5,4(x6)
        put(64, 32'h0072a423); // SW   x7,8(x5)
        put(68, 32'h00408463); // BEQ  x1,x4,+8
        put(72, 32'h00249463); // BNE  x9,x2,+8
        put(80, 32'h00125463); // BGE  x4,x1,+8
        put(88, 32'h12345ab7); // LUI  x21,0x12345
        put(92, 32'h008000ef); // JAL  x1,+8
    end
endmodule
