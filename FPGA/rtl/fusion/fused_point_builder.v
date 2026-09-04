// Packs the frozen 48-byte payload. Bit 0 is serialized first (little-endian).
module fused_point_builder(input wire[63:0]measurement_time,input wire[31:0]image_id,
 input wire[15:0]line_id,point_id,input wire signed[15:0]x_angle,y_angle,
 input wire signed[31:0]i1,q1,i2,q2,input wire[31:0]a1,a2,input wire[15:0]flags,config_revision,
 output wire[383:0]payload);
 assign payload={config_revision,flags,a2,a1,q2,i2,q1,i1,y_angle,x_angle,point_id,line_id,image_id,measurement_time};
endmodule

