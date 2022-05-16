onbreak resume
onerror resume
vsim -voptargs=+acc work.FFT_Burst_tb

add wave sim:/FFT_Burst_tb/u_FFT_Burst/clk
add wave sim:/FFT_Burst_tb/u_FFT_Burst/reset
add wave sim:/FFT_Burst_tb/u_FFT_Burst/DataIn_re
add wave sim:/FFT_Burst_tb/u_FFT_Burst/DataIn_im
add wave sim:/FFT_Burst_tb/u_FFT_Burst/ValidIn
add wave sim:/FFT_Burst_tb/u_FFT_Burst/DataOut_re
add wave sim:/FFT_Burst_tb/DataOut_re_ref
add wave sim:/FFT_Burst_tb/u_FFT_Burst/DataOut_im
add wave sim:/FFT_Burst_tb/DataOut_im_ref
add wave sim:/FFT_Burst_tb/u_FFT_Burst/ValidOut
add wave sim:/FFT_Burst_tb/ValidOut_ref
add wave sim:/FFT_Burst_tb/u_FFT_Burst/Ready
add wave sim:/FFT_Burst_tb/Ready_ref
run -all
