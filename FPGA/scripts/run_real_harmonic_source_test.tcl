set root [file normalize [file join [file dirname [info script]] ../..]]
set fpga [file join $root FPGA]
set out [file join $fpga build real_harmonic_source_sim]
file mkdir $out
file copy -force [file join $fpga data ch4_hitran_5000ppm.mem] [file join $out ch4_hitran_5000ppm.mem]
cd $out
set files [list \
 [file join $fpga rtl clock system_timebase.v] \
 [file join $fpga rtl adc fractional_sample_tick.v] \
 [file join $fpga rtl adc ch4_rom_source.v] \
 [file join $fpga rtl adc adc_calibration.v] \
 [file join $fpga rtl dila nco.v] \
 [file join $fpga rtl dila complex_mixer.v] \
 [file join $fpga rtl dila cic_decimator.v] \
 [file join $fpga rtl dila fir_decimator.v] \
 [file join $fpga rtl dila demod_chain.v] \
 [file join $fpga rtl dila iq_boxcar16.v] \
 [file join $fpga rtl framing scan_framer.v] \
 [file join $fpga rtl framing wms_feature_extractor.v] \
 [file join $fpga rtl fusion fused_point_builder.v] \
 [file join $fpga rtl fusion ch4_real_fused_point_source.v] \
 [file join $fpga sim tb_ch4_real_harmonic_source.v]]
exec xvlog {*}$files
exec xelab --timescale 1ns/1ps tb_ch4_real_harmonic_source -s real_harmonic_source_sim
set result [exec xsim real_harmonic_source_sim -runall]
if {[string first "REAL_HARMONIC_SOURCE_PASS" $result] < 0} {error "real harmonic source test failed"}
puts $result
