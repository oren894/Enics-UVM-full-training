+incdir+../dv_agent
# Package file (must be compiled after common)
# Verification Files
../sv/rx_verification_pack.sv

# RTL Files
../rtl/dma_crc_pkg.sv
../rtl/dma_rx_pkg.sv

# Sub-modules
../rtl/dma_rx_fsm.sv
../rtl/dma_rx_phase_ctrl.sv  
../rtl/dma_rx_len_detect.sv
../rtl/dma_rx_ctrl_proc.sv
../rtl/dma_rx_data_proc.sv
../rtl/dma_rx_parity_check.sv

# Top-level module
../rtl/dma_rx_top.sv

# Agent Files
../dv_agent/dv_if.sv
../dv_agent/dv_sequence_item.sv
../dv_agent/dv_monitor_item.sv
../dv_agent/dv_sequencer.sv
../dv_agent/dv_driver.sv
../dv_agent/dv_monitor.sv
../dv_agent/dv_agent.sv


../sv/generation_parameters/final_rx_generation_parameters.sv
../sv/components/rx_scoreboard.sv
../sv/sequencers/rx_virtual_sequencer.sv
../sv/items/rx_item/final_rx_item.sv
../sv/items/coverage_item/final_rx_coverage_item.sv
../sv/components/coverage/final_rx_coverage.sv
../sv/rx_report_server.sv

../sv/sequences/input_sequence/final_rx_input_data_sequence.sv

../sv/rx_typedefs.sv
../sv/sequences/virtual_sequence/final_rx_virtual_sequence.sv
../sv/components/reference_model/final_rx_reference_model.sv

../sv/rx_environment.sv
../sv/tests/rx_base_test.sv
../sv/rx_top_tb.sv
