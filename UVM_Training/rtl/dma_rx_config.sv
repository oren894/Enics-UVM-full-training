`timescale 1ns/1ps

module dma_rx_config 
    import dma_rx_pkg::*;
    import dma_config_pkg::*;
(
    input logic clk,
    input logic rst_n,
    
    // Fetch enable signal from top module
    input logic fetch_enable,
    
    // Configuration input from top module
    input dma_config_t config_in,
    
    // BUSY signal input from DMA RX core (indicates ongoing transaction)
    input logic [31:0] busy_in,
    
    // Configuration output to DMA RX core
    output dma_config_t config_out     // Complete configuration structure
);

    // Internal configuration register - Using structured type
    dma_config_t config_reg_file;                 // Complete configuration structure

    // Default configuration values
    localparam logic [31:0] DEFAULT_BASE_ADDRESS    = 32'h0000_0000;
    localparam logic [15:0] DEFAULT_PAGE_SIZE       = 16'h0000;
    localparam logic [15:0] DEFAULT_JUMP_SIZE       = 16'h0000;
    localparam logic [15:0] DEFAULT_NUMBER_OF_PAGES = 16'h0000;
    // localparam logic [31:0] DEFAULT_PARITY_FAILS    = 32'h0000_0000;
    localparam logic [15:0] DEFAULT_EXTRA_1         = 16'h0000;
    localparam logic [15:0] DEFAULT_EXTRA_2         = 16'h0000;
    localparam logic [15:0] DEFAULT_EXTRA_3         = 16'h0000;
    
    // Busy signal values
    localparam logic [31:0] TRANSACTION_BUSY        = 32'hFFFF_FFFF;
    localparam logic [31:0] TRANSACTION_READY       = 32'h0000_0000;

    //==================================================
    // Configuration register update logic
    // Registers get updated when fetch_enable is asserted
    //==================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize with default values
            config_reg_file.base_address      <= DEFAULT_BASE_ADDRESS;
            config_reg_file.page_size         <= DEFAULT_PAGE_SIZE;
            config_reg_file.jump_size         <= DEFAULT_JUMP_SIZE;
            config_reg_file.number_of_pages   <= DEFAULT_NUMBER_OF_PAGES;
            // config_reg_file.parity_fails      <= DEFAULT_PARITY_FAILS;
            config_reg_file.extra_1           <= DEFAULT_EXTRA_1;
            config_reg_file.extra_2           <= DEFAULT_EXTRA_2;
            config_reg_file.extra_3           <= DEFAULT_EXTRA_3;
            config_reg_file.busy              <= TRANSACTION_READY;
        end else if (fetch_enable) begin
            // Load configuration from input struct
            config_reg_file.base_address      <= config_in.base_address;
            config_reg_file.page_size         <= config_in.page_size;
            config_reg_file.jump_size         <= config_in.jump_size;
            config_reg_file.number_of_pages   <= config_in.number_of_pages;
            config_reg_file.extra_1           <= config_in.extra_1;
            config_reg_file.extra_2           <= config_in.extra_2;
            config_reg_file.extra_3           <= config_in.extra_3;
            config_reg_file.busy              <= busy_in;
        end
    end

    // // Parity counter is always updated (read from input)
    // always_comb begin
    //     config_reg_file.parity_fails = parity_not_valid_count_in; // TODO: reset on read ( or something )
    // end

    // Output assignments - Pack into configuration structure directly
    assign config_out = config_reg_file;
    

endmodule
