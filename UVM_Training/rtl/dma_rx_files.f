# DMA RX RTL Files
# Common package files (must be compiled first)
-f ../../common/dma_common_files.f
# Package file (must be compiled after common)
./dma_rx_pkg.sv

# Sub-modules
./dma_rx_fsm.sv
./dma_rx_phase_ctrl.sv
./dma_rx_len_detect.sv
./dma_rx_ctrl_proc.sv
./dma_rx_data_proc.sv
./dma_rx_parity_check.sv

# Top-level module
./dma_rx_top.sv

# Legacy file (for reference, can be removed after verification)
# ./dma_rx.sv
