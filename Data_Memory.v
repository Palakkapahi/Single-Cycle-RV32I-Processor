module data_memory(
    input clk, rst,
    input [31:0] address,      // from ALU: rs1 + imm
    input [31:0] write_data,   // from RFU: rs2 value, for SW/SB
    input sw,                  // store enable (SB or SW)
    input sb,                  // 1 = byte store, 0 = word store
    input lb,                  // 1 = byte load (sign-extended), 0 = word load
    output reg [31:0] data_out
);
    reg [7:0] data_mem [127:0]; // byte-addressable
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 128; i = i + 1)
                data_mem[i] <= 0;
        end
        else if (sw) begin
            if (sb) begin
                data_mem[address] <= write_data[7:0]; // only 1 byte touched
            end
            else begin
                data_mem[address]   <= write_data[7:0];
                data_mem[address+1] <= write_data[15:8];
                data_mem[address+2] <= write_data[23:16];
                data_mem[address+3] <= write_data[31:24];
            end
        end
    end

    always @(*) begin
        if (lb)
            data_out = {{24{data_mem[address][7]}}, data_mem[address]};
        else
            data_out = {data_mem[address+3], data_mem[address+2], data_mem[address+1], data_mem[address]};
    end
endmodule
