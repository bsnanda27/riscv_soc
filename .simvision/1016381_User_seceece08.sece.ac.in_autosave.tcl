
# NC-Sim Command File
# TOOL:	ncsim(64)	15.20-s086
#

set tcl_prompt1 {puts -nonewline "ncsim> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
alias iprof profile
database -open -vcd -into tb_axi_soc.vcd _tb_axi_soc.vcd1 -timescale fs
database -open -evcd -into tb_axi_soc.vcd _tb_axi_soc.vcd -timescale fs
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_axi_soc.dut.M_AXI_ARADDR tb_axi_soc.dut.M_AXI_ARREADY tb_axi_soc.dut.M_AXI_ARVALID tb_axi_soc.dut.M_AXI_AWADDR tb_axi_soc.dut.M_AXI_AWREADY tb_axi_soc.dut.M_AXI_AWVALID tb_axi_soc.dut.M_AXI_BREADY tb_axi_soc.dut.M_AXI_BRESP tb_axi_soc.dut.M_AXI_BVALID tb_axi_soc.dut.M_AXI_RDATA tb_axi_soc.dut.M_AXI_RREADY tb_axi_soc.dut.M_AXI_RRESP tb_axi_soc.dut.M_AXI_RVALID tb_axi_soc.dut.M_AXI_WDATA tb_axi_soc.dut.M_AXI_WREADY tb_axi_soc.dut.M_AXI_WSTRB tb_axi_soc.dut.M_AXI_WVALID tb_axi_soc.dut.br_taken_dbg tb_axi_soc.dut.clk tb_axi_soc.dut.data_access tb_axi_soc.dut.epc_debug tb_axi_soc.dut.gpio_araddr tb_axi_soc.dut.gpio_arready tb_axi_soc.dut.gpio_arvalid tb_axi_soc.dut.gpio_awaddr tb_axi_soc.dut.gpio_awready tb_axi_soc.dut.gpio_awvalid tb_axi_soc.dut.gpio_bready tb_axi_soc.dut.gpio_bresp tb_axi_soc.dut.gpio_bvalid tb_axi_soc.dut.gpio_in tb_axi_soc.dut.gpio_out tb_axi_soc.dut.gpio_rdata tb_axi_soc.dut.gpio_rready tb_axi_soc.dut.gpio_rresp tb_axi_soc.dut.gpio_rvalid tb_axi_soc.dut.gpio_wdata tb_axi_soc.dut.gpio_wready tb_axi_soc.dut.gpio_wstrb tb_axi_soc.dut.gpio_wvalid tb_axi_soc.dut.inst_debug tb_axi_soc.dut.mem_addr tb_axi_soc.dut.mem_rdata tb_axi_soc.dut.mem_re tb_axi_soc.dut.mem_ready tb_axi_soc.dut.mem_valid tb_axi_soc.dut.mem_wdata tb_axi_soc.dut.mem_we tb_axi_soc.dut.mem_write tb_axi_soc.dut.mem_wstrb tb_axi_soc.dut.pc_debug tb_axi_soc.dut.proc_imem_addr tb_axi_soc.dut.proc_imem_rdata tb_axi_soc.dut.proc_mem_addr tb_axi_soc.dut.proc_mem_rdata tb_axi_soc.dut.proc_mem_wdata tb_axi_soc.dut.ram_araddr tb_axi_soc.dut.ram_arready tb_axi_soc.dut.ram_arvalid tb_axi_soc.dut.ram_awaddr tb_axi_soc.dut.ram_awready tb_axi_soc.dut.ram_awvalid tb_axi_soc.dut.ram_bready tb_axi_soc.dut.ram_bresp tb_axi_soc.dut.ram_bvalid tb_axi_soc.dut.ram_rdata tb_axi_soc.dut.ram_rready tb_axi_soc.dut.ram_rresp tb_axi_soc.dut.ram_rvalid tb_axi_soc.dut.ram_wdata tb_axi_soc.dut.ram_wready tb_axi_soc.dut.ram_wstrb tb_axi_soc.dut.ram_wvalid tb_axi_soc.dut.rf_waddr tb_axi_soc.dut.rf_wdata tb_axi_soc.dut.rf_we tb_axi_soc.dut.rst tb_axi_soc.dut.spi_araddr tb_axi_soc.dut.spi_arready tb_axi_soc.dut.spi_arvalid tb_axi_soc.dut.spi_awaddr tb_axi_soc.dut.spi_awready tb_axi_soc.dut.spi_awvalid tb_axi_soc.dut.spi_bready tb_axi_soc.dut.spi_bresp tb_axi_soc.dut.spi_bvalid tb_axi_soc.dut.spi_cs tb_axi_soc.dut.spi_miso tb_axi_soc.dut.spi_mosi tb_axi_soc.dut.spi_rdata tb_axi_soc.dut.spi_rready tb_axi_soc.dut.spi_rresp tb_axi_soc.dut.spi_rvalid tb_axi_soc.dut.spi_sclk tb_axi_soc.dut.spi_wdata tb_axi_soc.dut.spi_wready tb_axi_soc.dut.spi_wstrb tb_axi_soc.dut.spi_wvalid tb_axi_soc.dut.timer_interrupt tb_axi_soc.dut.timer_irq_dbg tb_axi_soc.dut.trap_taken

simvision -input /home/User/Documents/riscv32i_processor/risc_v_axi/.simvision/1016381_User_seceece08.sece.ac.in_autosave.tcl.svcf
