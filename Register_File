module register_file(
    input clk, rst,
    input [4:0] rs1_addr, rs2_addr, rd_addr,
    input [31:0] alu_result,      // from ALU
    input [31:0] mem_read_data,   // from data_memory (loads)
    input [31:0] lui_imm_val,     // from imm_gen (LUI)
    input [31:0] pc_plus4,        // from IFU (JAL)
    input reg_write,              // from CU
    input mem_to_reg,             // from CU (load)
    input lui_control,            // from CU
    input jump,                   // from CU
    output [31:0] rs1,
    output [31:0] rs2,
    output reg [31:0] data_out_2_dm  // value to store, for sw
);
    reg [31:0] reg_mem [31:0];
    integer i;

    // async reads — always live, no clock involved
    assign rs1 = reg_mem[rs1_addr];
    assign rs2 = reg_mem[rs2_addr];

    // value to hand off to data_memory for a store
    always @(*) begin
        data_out_2_dm = reg_mem[rs2_addr];  // rs2, NOT rs1
    end

    wire [31:0] write_data = lui_control ? lui_imm_val :
                              jump        ? pc_plus4    :
                              mem_to_reg  ? mem_read_data :
                                            alu_result;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                reg_mem[i] <= i;
        end
        else if (reg_write && rd_addr != 0) begin
            reg_mem[rd_addr] <= write_data;
        end
    end
endmodule
