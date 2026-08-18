`timescale 1ns/1ps

module dma_rx_write 
    import dma_rx_pkg::*;
    import dma_config_pkg::*;
(
    input logic clk,
    input logic rst_n,
    
    // Configuration inputs from APB
    input dma_config_t config_in,
    
    // Data inputs from RX processing
    input logic [31:0] data_in,
    input logic data_valid,
    input logic [15:0] control_in,
    input logic control_valid,
    
    // Memory interface outputs
    output logic [31:0] mem_addr,
    output logic [31:0] mem_data,
    output logic mem_write_enable,
    
    // Status outputs
    output logic write_complete,
    output logic [15:0] pages_written
);

    // Internal registers
    logic [31:0] current_address;
    logic [15:0] current_page;
    logic [15:0] words_in_page;
    logic [15:0] words_per_page;
    logic [31:0] next_addr_calc;
    
    // Control signals
    logic page_boundary_reached;
    logic all_pages_written;

    
    // Calculate words per page (page_size is in bytes, we write 32-bit words)
    assign words_per_page = config_in.page_size >> 2; // Divide by 4 (bytes per word)
    
    // Check boundaries
    assign page_boundary_reached = (words_in_page >= words_per_page);
    assign all_pages_written = (current_page >= config_in.number_of_pages);
    
    // Memory interface assignments
    assign mem_addr = current_address;
    assign mem_data = data_in;
    assign mem_write_enable = data_valid  && !all_pages_written;
    
    // Status outputs
    assign write_complete = all_pages_written;
    assign pages_written = current_page;
    
    // Address and page management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_address <= 32'h0;
            current_page <= 16'h0;
            words_in_page <= 16'h0;
        end else begin
            // Initialize address when base address is configured
            if (current_address == 32'h0 && config_in.base_address != 32'h0) begin
                current_address <= config_in.base_address;
                current_page <= 16'h0;
                words_in_page <= 16'h0;
            end
            
            // Handle data writes
            else if (data_valid && !all_pages_written) begin
                // Increment word counter
                words_in_page <= words_in_page + 1'b1;
                
                // Check if we've reached page boundary
                if (page_boundary_reached) begin
                    // Move to next page
                    current_page <= current_page + 1'b1;
                    words_in_page <= 16'h0;
                    
                    // Calculate next page address using jump size
                    if (current_page + 1'b1 < config_in.number_of_pages) begin
                        // Check for address overflow
                            current_address <= next_addr_calc[31:0];
                    end
                end else begin
                    // Increment address within page (next 32-bit word)
                    current_address <= current_address + 32'h4;
                end
            end
        end
    end
                             // Jump to next page: base + (page_number * jump_size * page_size)
                    
    assign next_addr_calc = config_in.base_address + ((current_page + 1'b1) * config_in.jump_size * config_in.page_size);
    
    // Debug and monitoring (synthesis will optimize out)
    `ifdef DEBUG
    always_ff @(posedge clk) begin
        if (data_valid && mem_write_enable) begin
            $display("Time: %0t - DMA Write: addr=0x%h, data=0x%h, page=%0d, word_in_page=%0d", 
                     $time, mem_addr, mem_data, current_page, words_in_page);
        end
        
        if (page_boundary_reached && data_valid) begin
            $display("Time: %0t - Page boundary reached, moving to page %0d", 
                     $time, current_page + 1);
        end
        
        if (all_pages_written && data_valid) begin
            $display("Time: %0t - All pages written, DMA transfer complete", $time);
        end

    end
    `endif

endmodule
