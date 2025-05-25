`timescale 1ns / 1ps

module adder_32bit(
    input clk,
    input rst,
    input [31:0] i_a,
    input [31:0] i_b,
    input i_vld,
    output reg [31:0] o_res,
    output reg o_res_vld,
    output reg overflow
);

wire [7:0] shift;
wire [23:0] al_man_a, al_man_b;
wire sign_a, sign_b, sign_res;
wire [7:0] exp_a, exp_b, exp_res;
wire [23:0] man_a, man_b, man_res;
wire [24:0] res;
wire operation_overflow;

assign sign_a = i_a[31];
assign sign_b = i_b[31];
assign exp_a  = i_a[30:23];
assign exp_b  = i_b[30:23];
assign man_a  = (exp_a == 8'b0) ? {1'b0, i_a[22:0]} : {1'b1, i_a[22:0]};
assign man_b  = (exp_b == 8'b0) ? {1'b0, i_b[22:0]} : {1'b1, i_b[22:0]};

wire is_nan_a  = ((exp_a == 8'b11111111) && (i_a[22:0] != 0));  // use original mantissa bits only
wire is_nan_b  = ((exp_b == 8'b11111111) && (i_b[22:0] != 0));
wire is_inf_a  = ((exp_a == 8'b11111111) && (i_a[22:0] == 0));
wire is_inf_b  = ((exp_b == 8'b11111111) && (i_b[22:0] == 0));
wire is_zero_a = (i_a[30:0] == 31'b0);
wire is_zero_b = (i_b[30:0] == 31'b0);


compare_and_shift u_compare_and_shift (
    .exp_a(exp_a),
    .exp_b(exp_b),
    .man_a(man_a),
    .man_b(man_b),
    .al_man_a(al_man_a),
    .al_man_b(al_man_b),
    .shift(shift)
);

addition_s u_addition_s (
    .sign_a(sign_a),
    .sign_b(sign_b),
    .a(al_man_a),
    .b(al_man_b),
    .res(res),
    .sign_res(sign_res)
);

normalization_s_32 u_normalization_s (
    .res(res),
    .exp_base((exp_a > exp_b) ? exp_a : exp_b),
    .man_res(man_res),
    .exp_res(exp_res),
    .overflow(operation_overflow)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        o_res <= 32'b0;
        o_res_vld <= 1'b0;
        overflow <= 1'b0;
    end else if (i_vld) begin
        if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a != sign_b))) begin
            o_res <= 32'b01111111110000000000000000000000;
            o_res_vld <= 1'b1;
            overflow <= 1'b1;
        end else if (is_inf_a || is_inf_b) begin
            o_res <= is_inf_a ? i_a : i_b;
            o_res_vld <= 1'b1;
            overflow <= 1'b1;
        end else if (is_zero_a && is_zero_b) begin
            o_res <= 32'b0;
            o_res_vld <= 1'b1;
            overflow <= 1'b0;
        end else begin
            o_res <= {sign_res, exp_res, man_res[22:0]};
            o_res_vld <= 1'b1;
            overflow <= operation_overflow;
        end
    end else begin
        o_res_vld <= 1'b0;
    end
end

endmodule
