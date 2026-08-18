`timescale 1ns/1ps

module dma_rx_phase_ctrl 
    import dma_rx_pkg::*;
(
    input logic clk,
    input logic rst_n,
    
    // FSM inputs
    input fsm_state_t fsm_next_state,
    input logic [16:0] data_next_nibble_counter,
    input logic [15:0] data_packet_length,
    
    // Phase outputs  
    output logic phase_control_active,
    output logic phase_data_active,
    output logic phase_data_length_active,
    output logic phase_parity_active,

    output logic phase_next_control_active,
    output logic phase_next_data_active,
    output logic phase_next_data_length_active,
    output logic phase_next_parity_active,

    // Phase edge pulses
    output logic phase_control_start,      
    output logic phase_control_end,
    output logic phase_data_length_start,  
    output logic phase_data_length_end,
    output logic phase_data_start,         
    output logic phase_data_end,
    output logic phase_parity_start,       
    output logic phase_parity_end,
    
    // Current FSM state for edge detection
    input fsm_state_t fsm_current_state
);

    phase_state_t phase_state, phase_state_next;

    // Compute next-phase booleans (combinational) based on fsm_next_state and data_next_nibble_counter
    always_comb begin
        // Phase default values
        phase_next_control_active = 1'b0;
        phase_next_data_length_active = 1'b0;
        phase_next_data_active = 1'b0;
        phase_next_parity_active = 1'b0;
        phase_state_next = PHASE_NONE;

        if (fsm_next_state == FSM_LOCKED || fsm_next_state == FSM_MAYBE_LOCKED) begin
            phase_next_data_length_active = (data_next_nibble_counter < LEN_CRC_LENGTH);
            phase_next_control_active     = (data_next_nibble_counter >= LEN_CRC_LENGTH &&
                                        data_next_nibble_counter < LEN_CRC_LENGTH + CTRL_CRC_LENGTH);
            phase_next_data_active        = (data_next_nibble_counter >= LEN_CRC_LENGTH + CTRL_CRC_LENGTH &&
                                        data_next_nibble_counter < LEN_CRC_LENGTH + data_packet_length * 2);
            phase_next_parity_active      = (data_next_nibble_counter >= LEN_CRC_LENGTH + data_packet_length * 2 &&
                                        data_next_nibble_counter < LEN_CRC_LENGTH + data_packet_length * 2 + PARITY_CHECK_LENGTH);

            // Map next-phase booleans to a single next-state for clarity/tracing
            if (phase_next_data_length_active) phase_state_next = PHASE_LEN;
            else if (phase_next_control_active) phase_state_next = PHASE_CTRL;
            else if (phase_next_data_active) phase_state_next = PHASE_DATA;
            else if (phase_next_parity_active) phase_state_next = PHASE_PARITY;
            else phase_state_next = PHASE_NONE;
        end else begin
            phase_state_next = PHASE_NONE;
        end
    end

    // Register the phase FSM state and update phase_active signals. This preserves the original behavior
    // where phase_active signals were registered from phase_next_* values (i.e. next-phase values become
    // the active-phase signals on the following clock edge).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_state <= PHASE_NONE;
            phase_control_active <= 1'b0;
            phase_data_length_active <= 1'b0;
            phase_data_active <= 1'b0;
            phase_parity_active <= 1'b0;
        end else begin
            phase_state <= phase_state_next;

            // Registering phase_active from the computed next-phase (matches previous timing)
            phase_control_active <= (phase_state_next == PHASE_CTRL);
            phase_data_length_active <= (phase_state_next == PHASE_LEN);
            phase_data_active <= (phase_state_next == PHASE_DATA);
            phase_parity_active <= (phase_state_next == PHASE_PARITY);
        end
    end

    // Phase edges: 1-cycle pulses on transitions, only when we accept a nibble
    always_comb begin
        phase_control_start      =  ~phase_control_active     && phase_next_control_active;
        phase_control_end        =   phase_control_active     && ~phase_next_control_active;

        phase_data_length_start  =  ~phase_data_length_active && phase_next_data_length_active;
        phase_data_length_end    = (  phase_data_length_active && ~phase_next_data_length_active) || 
                                   (fsm_current_state == FSM_NOT_LOCKED && fsm_next_state == FSM_MAYBE_LOCKED);

        phase_data_start         =  ~phase_data_active        && phase_next_data_active;
        phase_data_end           =   phase_data_active        && ~phase_next_data_active;

        phase_parity_start       =  ~phase_parity_active      && phase_next_parity_active;
        phase_parity_end         =   phase_parity_active      && ~phase_next_parity_active;
    end

endmodule
