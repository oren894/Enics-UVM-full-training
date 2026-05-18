`timescale 1ns/1ps

module dma_rx_config_apb
    import dma_rx_pkg::*,
           dma_config_pkg::*;
(
    input logic clk,
    input logic rst_n,
    
    // APB interface
    input logic psel,        // APB select
    input logic penable,     // APB enable
    input logic pwrite,      // APB write enable
    input logic [31:0] paddr,   // APB address
    input logic [31:0] pwdata,  // APB write data
    output logic [31:0] prdata, // APB read data
    output logic pready,     // APB ready
    output logic pslverr,    // APB slave error
    
    // BUSY signal input from DMA RX core (indicates ongoing transaction)
    input logic [31:0] busy_in,
    
    // Configuration to DMA RX core
    output dma_config_t config_out
);

    // APB protocol signals
    logic apb_access;
    logic apb_setup_wr;
    logic apb_setup_rd;
    
    // Configuration register addresses (word-aligned)
    localparam logic [2:0] ADDR_BASE_ADDRESS            = 3'h00;  // 0x00 - Base Address (32-bit)
    localparam logic [2:0] ADDR_PAGE_SIZE_JUMP_SIZE     = 3'h01;  // 0x04 - [31:16] jump_size, [15:0] page_size
    localparam logic [2:0] ADDR_EXTRA_1_NUM_PAGES       = 3'h02;  // 0x08 - [31:16] extra_1, [15:0] number_of_pages
    localparam logic [2:0] ADDR_TRANSACTION_LENGTH      = 3'h03;  // 0x0C - Transaction Length (32-bit)
    localparam logic [2:0] ADDR_EXTRA_3_EXTRA_2         = 3'h04;  // 0x10 - [31:16] extra_3, [15:0] extra_2
    localparam logic [2:0] ADDR_BUSY                    = 3'h05;  // 0x14 - Busy transaction signal (32-bit)

    // Internal configuration register - Using structured type
    dma_config_t config_reg_file;                 // Complete configuration structure

    // Default configuration values
    localparam logic [31:0] DEFAULT_BASE_ADDRESS        = 32'h0000_0000;
    localparam logic [15:0] DEFAULT_PAGE_SIZE           = 16'h0000;      // 0 pages
    localparam logic [15:0] DEFAULT_JUMP_SIZE           = 16'h0000;      // 0 page jump
    localparam logic [15:0] DEFAULT_NUMBER_OF_PAGES     = 16'h0000;      // 0 pages
    localparam logic [31:0] DEFAULT_TRANSACTION_LENGTH  = 32'h0000_0000; // 0 bytes
    localparam logic [15:0] DEFAULT_EXTRA_1             = 16'h0000;      // 0
    localparam logic [15:0] DEFAULT_EXTRA_2             = 16'h0000;      // 0
    localparam logic [15:0] DEFAULT_EXTRA_3             = 16'h0000;      // 0
    
    // Busy signal values
    localparam logic [31:0] TRANSACTION_BUSY            = 32'hFFFF_FFFF; // Transaction busy
    localparam logic [31:0] TRANSACTION_READY           = 32'h0000_0000; // Transaction ready

    //==================================================
    // APB protocol setup phase: latch address and write enable
    //==================================================
    assign apb_access = psel && penable;
    assign apb_setup_wr = apb_access && pwrite;
    assign apb_setup_rd = apb_access && !pwrite;

    // APB ready and error signals
    assign pready = 1'b1;  // Always ready for simplicity
    assign pslverr = 1'b0; // No slave errors

    // Configuration register write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize with default values
            config_reg_file.base_address        <= DEFAULT_BASE_ADDRESS;
            config_reg_file.page_size           <= DEFAULT_PAGE_SIZE;
            config_reg_file.jump_size           <= DEFAULT_JUMP_SIZE;
            config_reg_file.number_of_pages     <= DEFAULT_NUMBER_OF_PAGES;
            config_reg_file.transaction_length  <= DEFAULT_TRANSACTION_LENGTH;
            config_reg_file.extra_1             <= DEFAULT_EXTRA_1;
            config_reg_file.extra_2             <= DEFAULT_EXTRA_2;
            config_reg_file.extra_3             <= DEFAULT_EXTRA_3;
            config_reg_file.busy                <= TRANSACTION_READY;
        end else if (apb_setup_wr) begin
            case (paddr[4:2]) 
                ADDR_BASE_ADDRESS: begin
                    config_reg_file.base_address <= pwdata;
                end
                ADDR_PAGE_SIZE_JUMP_SIZE: begin
                    config_reg_file.jump_size <= pwdata[31:16];  // [31:16] = jump_size
                    config_reg_file.page_size <= pwdata[15:0];   // [15:0] = page_size
                end
                ADDR_EXTRA_1_NUM_PAGES: begin
                    config_reg_file.extra_1         <= pwdata[31:16];   // [31:16] = extra_1
                    config_reg_file.number_of_pages <= pwdata[15:0];    // [15:0] = number_of_pages
                end
                ADDR_TRANSACTION_LENGTH: begin
                    config_reg_file.transaction_length <= pwdata;       // [31:0] = transaction_length
                end
                ADDR_EXTRA_3_EXTRA_2: begin
                    config_reg_file.extra_3 <= pwdata[31:16];    // [31:16] = extra_3
                    config_reg_file.extra_2 <= pwdata[15:0];     // [15:0] = extra_2
                end
                ADDR_BUSY: begin
                    config_reg_file.busy <= pwdata;              // [31:0] = busy
                end
                default: begin
                    // No action for invalid addresses
                end
            endcase
        end else begin
            // Update busy status from RX core (read-only from software perspective)
            config_reg_file.busy <= busy_in;
        end
    end

    // Configuration register read logic
    always_comb begin
        prdata = 32'h0;
        if (apb_setup_rd) begin
            case (paddr[4:2])
                ADDR_BASE_ADDRESS: begin
                    prdata = config_reg_file.base_address;
                end
                ADDR_PAGE_SIZE_JUMP_SIZE: begin
                    prdata = {config_reg_file.jump_size, config_reg_file.page_size};
                end
                ADDR_EXTRA_1_NUM_PAGES: begin
                    prdata = {config_reg_file.extra_1, config_reg_file.number_of_pages};
                end
                ADDR_TRANSACTION_LENGTH: begin
                    prdata = config_reg_file.transaction_length;
                end
                ADDR_EXTRA_3_EXTRA_2: begin
                    prdata = {config_reg_file.extra_3, config_reg_file.extra_2};
                end
                ADDR_BUSY: begin
                    prdata = config_reg_file.busy;
                end
                default: begin
                    prdata = 32'h0;
                end
            endcase
        end
    end

    // Output configuration to RX core
    assign config_out = config_reg_file;

endmodule
