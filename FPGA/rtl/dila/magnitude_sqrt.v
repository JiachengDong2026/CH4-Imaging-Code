module magnitude_sqrt(input wire signed[31:0]x,y,output wire[32:0]magnitude);
 wire[63:0]x_sq=$signed(x)*$signed(x),y_sq=$signed(y)*$signed(y);wire[64:0]sum_sq={1'b0,x_sq}+{1'b0,y_sq};
 function[32:0]isqrt65;input[64:0]value;integer k;reg[64:0]operand,result,trial_bit;begin operand=value;result=0;
  trial_bit=65'h1_0000_0000_0000_0000;for(k=0;k<33;k=k+1)begin if(operand>=result+trial_bit)begin operand=operand-(result+trial_bit);result=(result>>1)+trial_bit;end
  else result=result>>1;trial_bit=trial_bit>>2;end isqrt65=result[32:0];end endfunction
 assign magnitude=isqrt65(sum_sq);
endmodule
