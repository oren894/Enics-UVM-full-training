`timescale 1ns/1ps

package dma_config_pkg;

    // Configuration structure for DMA TX/RX
    typedef struct packed {
        logic [31:0] base_address;       // BASE ADDRESS (32 bits) - READ/WRITE for memory DMA
        logic [15:0] page_size;          // PAGE SIZE (16 bits) - READ/WRITE for memory DMA  
        logic [15:0] jump_size;          // JUMP SIZE in pages (16 bits) - READ/WRITE for memory DMA
        logic [15:0] number_of_pages;    // NUMBER OF PAGES (16 bits) - READ/WRITE for memory DMA
        logic [31:0] transaction_length; // TRANSACTION LENGTH (32 bits) - READ/WRITE
        logic [15:0] extra_1;            // EXTRA 1 (16 bits) - READ/WRITE
        logic [15:0] extra_2;            // EXTRA 2 (16 bits) - READ/WRITE  
        logic [15:0] extra_3;            // EXTRA 3 (16 bits) - READ/WRITE
        logic [31:0] busy;               // BUSY transaction signal (32 bits) - READ/WRITE 
    } dma_config_t;

endpackage
