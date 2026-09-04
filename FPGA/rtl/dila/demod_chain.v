module demod_chain #(parameter integer ADC_W=16,REF_W=18,CIC_STAGES=3)(
 input wire clk,rst,clear,in_valid,input wire signed[ADC_W-1:0]sample,input wire signed[REF_W-1:0]sin1,cos1,sin2,cos2,
 input wire[12:0]cic_decim,input wire[4:0]tap_count,fir_decim,input wire active_bank,coeff_we,coeff_bank,
 input wire[4:0]coeff_addr,input wire signed[17:0]coeff_wdata,output wire out_valid,
 output wire signed[31:0]i1,q1,i2,q2,output wire[32:0]a1,a2,output wire overflow);
 wire mv;wire signed[33:0]m1,mq1,m2,mq2;wire cv[0:3];wire signed[55:0]cd[0:3];wire fv[0:3];wire ov[0:3];
 complex_mixer mx(.clk(clk),.rst(rst),.in_valid(in_valid),.sample(sample),.sin_1f(sin1),.cos_1f(cos1),.sin_2f(sin2),.cos_2f(cos2),.out_valid(mv),.i1(m1),.q1(mq1),.i2(m2),.q2(mq2));
 cic_decimator c0(.clk(clk),.rst(rst),.clear(clear),.in_valid(mv),.in_data(m1),.decim(cic_decim),.out_valid(cv[0]),.out_data(cd[0]),.overflow());
 cic_decimator c1(.clk(clk),.rst(rst),.clear(clear),.in_valid(mv),.in_data(mq1),.decim(cic_decim),.out_valid(cv[1]),.out_data(cd[1]),.overflow());
 cic_decimator c2(.clk(clk),.rst(rst),.clear(clear),.in_valid(mv),.in_data(m2),.decim(cic_decim),.out_valid(cv[2]),.out_data(cd[2]),.overflow());
 cic_decimator c3(.clk(clk),.rst(rst),.clear(clear),.in_valid(mv),.in_data(mq2),.decim(cic_decim),.out_valid(cv[3]),.out_data(cd[3]),.overflow());
 fir_decimator f0(.clk(clk),.rst(rst),.clear(clear),.in_valid(cv[0]),.in_data(cd[0]),.tap_count(tap_count),.decim(fir_decim),.coeff_we(coeff_we),.coeff_bank(coeff_bank),.coeff_addr(coeff_addr),.coeff_wdata(coeff_wdata),.active_bank(active_bank),.out_valid(fv[0]),.out_data(i1),.overflow(ov[0]));
 fir_decimator f1(.clk(clk),.rst(rst),.clear(clear),.in_valid(cv[1]),.in_data(cd[1]),.tap_count(tap_count),.decim(fir_decim),.coeff_we(coeff_we),.coeff_bank(coeff_bank),.coeff_addr(coeff_addr),.coeff_wdata(coeff_wdata),.active_bank(active_bank),.out_valid(fv[1]),.out_data(q1),.overflow(ov[1]));
 fir_decimator f2(.clk(clk),.rst(rst),.clear(clear),.in_valid(cv[2]),.in_data(cd[2]),.tap_count(tap_count),.decim(fir_decim),.coeff_we(coeff_we),.coeff_bank(coeff_bank),.coeff_addr(coeff_addr),.coeff_wdata(coeff_wdata),.active_bank(active_bank),.out_valid(fv[2]),.out_data(i2),.overflow(ov[2]));
 fir_decimator f3(.clk(clk),.rst(rst),.clear(clear),.in_valid(cv[3]),.in_data(cd[3]),.tap_count(tap_count),.decim(fir_decim),.coeff_we(coeff_we),.coeff_bank(coeff_bank),.coeff_addr(coeff_addr),.coeff_wdata(coeff_wdata),.active_bank(active_bank),.out_valid(fv[3]),.out_data(q2),.overflow(ov[3]));
 assign out_valid=fv[0]&fv[1]&fv[2]&fv[3];assign a1=0;assign a2=0;assign overflow=ov[0]|ov[1]|ov[2]|ov[3];
endmodule
