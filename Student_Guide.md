# DMA RX — Student Guide

> **Level:** Beginner UVM  
> **Prerequisite reading:** README.md (architecture, file structure, protocol) + the VP document

---

## Overview

You are working on the `env_without_reference_model` branch. The environment is fully built and running — your job is to implement three components inside it, in order:

| Part | Files | What you implement |
|---|---|---|
| A | `sv/components/rx_reference_model.sv` | The golden model that predicts DUT output |
| B | `sv/components/rx_coverage.sv` | Functional coverage groups based on your AL |
| C | `sv/sequences/rx_virtual_sequence.sv` + `sv/sequences/rx_input_data_sequence.sv` | Stimulus generation |

**Do not move to the next part until the current one passes.**

---

## Before You Start

Any new enum or parameter you need throughout your implementation goes in `rx_typedefs.sv` or `rx_verification_pack.sv` respectively — keep everything centralized there, the same way the existing types are organized.

Read these files in order — they are short but critical:

```
1. sv/rx_verification_pack.sv       — global constants (bus widths, CRC params, size limits)
2. sv/rx_typedefs.sv                — agent typedefs and enums: rx_test_type_e, rx_lock_type_e
3. sv/rx_generation_parameters.sv   — all test knobs and probabilities
4. dv_agent/dv_monitor_item.sv      — the item type arriving at your model
5. sv/components/rx_scoreboard.sv   — understand what the scoreboard expects to receive
```

Pay attention to the constants already defined in `rx_verification_pack` — use them throughout instead of hardcoding values:

```systemverilog
MIN_DATA_SIZE                = 4
MAX_DATA_SIZE                = 8192
OPTIMAL_DATA_SIZE            = 4096
MIN_LOCK_VALID_THRESHOLD     = 2
MAX_LOCK_VALID_THRESHOLD     = 12
OPTIMAL_LOCK_VALID_THRESHOLD = 7

CRC_LEN_POLY   = 16'h1021    // LENGTH CRC polynomial
CRC_LEN_INIT   = 16'hFFFF    // LENGTH CRC init value
CRC_CTRL_POLY  = 16'h8005    // CONTROL CRC polynomial
CRC_CTRL_INIT  = 16'h0000    // CONTROL CRC init value
```

And the enums from `rx_typedefs.sv`:

```systemverilog
typedef enum int unsigned {
    TEST_REGULAR,       // 100–1000 random-length packets
    TEST_REAL           // realistic burst traffic
} rx_test_type_e;

typedef enum int unsigned {
    LOCK_REGULAR,           // LVT consecutive valid minimum-size packets
    LOCK_ONE_PACKET_OUT,    // one non-minimum-size packet mixed in during lock
    LOCK_PHASE_CHANGE,      // inject a half-packet (phase disruption) then re-lock
    LOCK_SINGLE_BIT_ERR,    // (disabled — do not implement)
    LOCK_MULTI_BIT_ERR      // wrong-length packet during lock sequence
} rx_lock_type_e;
```

---

## Part A — Reference Model

**File:** `sv/components/rx_reference_model.sv`

### What this component does

The monitor sits on the DUT's input bus and calls `write_input_data()` once per byte. Your job is to process those bytes byte-by-byte, run the same logic as the DUT, and push expected outputs to the scoreboard via the three analysis ports — **only while in LOCKED state**.

The scoreboard then compares your predictions against the actual DUT output. If they match every time, the test passes.

### The single entry point

```systemverilog
function void write_input_data(dv_monitor_item #(...) item);
    byte incoming_byte = item.data;
    // ALL your logic lives here
endfunction
```

This is called once per byte. Your entire FSM lives inside this function.

### FSM states — your model must track these

```
NOT_LOCKED ──valid packet found──► MAYBE_LOCKED ──LVT consecutive valid──► LOCKED
     ▲                                   │
     └──────invalid packet───────────────┘
```

- **NOT_LOCKED:** Search for a valid packet boundary using a sliding window over 4 possible byte alignments (phases 0–3).
- **MAYBE_LOCKED:** A valid boundary was found. Count consecutive valid packets.
- **LOCKED:** `lock_count >= lock_valid_threshold_value`. Only now do you write to the scoreboard.
- **FATAL:** If your reference model receives an invalid packet while in LOCKED state, it must transition to FATAL and stop writing to the scoreboard entirely.

> **Key rule:** Do not write anything to the scoreboard before reaching LOCKED, or after entering FATAL.

### What makes a packet "valid" for lock purposes?

Only the LENGTH + LENGTH_CRC fields matter during lock acquisition. If the CRC over the 2-byte LENGTH field matches the received 2-byte CRC, the packet is valid. The other fields are ignored at this stage.

### State variables you will need

```systemverilog
// FSM
rx_state_t   fsm_state;           // current state
int          lock_count;           // consecutive valid packets seen
int          current_phase;        // byte offset where packet boundary was found (0–3)

// Packet parsing
byte         byte_window[$];       // sliding byte buffer (for NOT_LOCKED phase search)
int          bytes_in_packet;      // bytes counted since start of current packet
int unsigned current_length;       // LENGTH field extracted from current packet

// Outputs being built
bit [15:0]   current_control;      // CONTROL field
bit [31:0]   current_data_word;    // accumulating 4 bytes into a 32-bit word
int          data_byte_count;      // how many DATA bytes received so far
bit [31:0]   parity_accumulator;   // XOR of all 32-bit DATA words
```

### CRC implementation

```systemverilog
// For LENGTH field — use CRC_LEN_POLY and CRC_LEN_INIT
function bit [15:0] crc_length(bit [7:0] data[]);
    bit [15:0] crc = rx_verification_pack::CRC_LEN_INIT;
    foreach (data[i]) begin
        crc ^= (data[i] << 8);
        repeat (8)
            crc = crc[15] ? (crc << 1) ^ rx_verification_pack::CRC_LEN_POLY
                          : (crc << 1);
    end
    return crc;
endfunction

// For CONTROL field — use CRC_CTRL_POLY and CRC_CTRL_INIT
function bit [15:0] crc_control(bit [7:0] data[]);
    bit [15:0] crc = rx_verification_pack::CRC_CTRL_INIT;
    foreach (data[i]) begin
        crc ^= (data[i] << 8);
        repeat (8)
            crc = crc[15] ? (crc << 1) ^ rx_verification_pack::CRC_CTRL_POLY
                          : (crc << 1);
    end
    return crc;
endfunction
```

> **Tip:** Cross-check your CRC logic against `rtl/dma_crc_pkg.sv` — the RTL implements the exact same algorithm.

### LOCKED state — packet field order and output timing

Once locked, parse each packet in this field order:

```
Bytes 0–1       →  LENGTH  (16-bit, big-endian)
Bytes 2–3       →  LENGTH CRC  (validate; correct single-bit error if found)
Bytes 4–5       →  CONTROL  (16-bit)
Bytes 6–7       →  CONTROL CRC  (validate; correct single-bit error if found)
                   → send CONTROL immediately here (if corrected value != 0)
Bytes 8..N      →  DATA  (N = LENGTH bytes, always a multiple of 4)
                   → send one 32-bit word every 4 bytes
Bytes N+1..N+4  →  PARITY  (32-bit XOR signature)
                   → send parity result here
```

Use `LENGTH_AND_CRC_BYTES`, `CONTROL_AND_CRC_BYTES`, and `PARITY_BYTES` from `rx_verification_pack` for field boundary calculations.

**Output rules:**

```systemverilog
// As soon as CONTROL CRC is received → send CONTROL (only if corrected value != 0)
if (corrected_control != 16'h0000) begin
    dv_monitor_item #(rx_verification_pack::CONTROL_DATA_WIDTH) c = new("c");
    c.data = corrected_control;
    control_export.write(c);
end

// Every 4 DATA bytes → send one 32-bit word and update parity
if (data_byte_count % 4 == 0 && data_byte_count > 0) begin
    dv_monitor_item #(rx_verification_pack::OUTPUT_DATA_WIDTH) d = new("d");
    d.data = current_data_word;
    output_data_export.write(d);
    parity_accumulator ^= current_data_word;
end

// When PARITY field is fully received → send parity result (0 = match, 1 = error)
begin
    dv_monitor_item #(1) p = new("p");
    p.data = (received_parity == parity_accumulator) ? 1'b0 : 1'b1;
    parity_export.write(p);
end
```

### Self-check before moving on

- [ ] Do you reset `parity_accumulator` to zero at the start of every new packet?
- [ ] Do you suppress all scoreboard writes until FSM is LOCKED?
- [ ] Do you send CONTROL immediately after receiving CONTROL CRC — not at end of packet?
- [ ] Do you only correct **single-bit** errors, never two or more?
- [ ] Do you skip sending CONTROL when its corrected value is exactly `16'h0000`?

---

## Part B — Functional Coverage

**File:** `sv/components/rx_coverage.sv`

### How coverage works in this environment

Your coverage component receives information **only from the reference model**. As you implement the reference model, you decide what data to forward to the coverage component — packet size, CRC error flags, parity result, control value, phase, and so on. You then write coverpoints over those fields.

The one exception is the **input valid probability**, which comes directly from the test configuration and must be sampled separately.

Functional coverage tracks **which scenarios were exercised**, not whether they passed. It tells you the test is actually exploring the design space — not just repeating the same scenario.

### End-to-end example — parity result

**Step 1 — In your reference model**, once you know the parity outcome, send it to coverage:

```systemverilog
// Inside rx_reference_model, after computing parity result:
rx_coverage_item cov_item = new("cov_item");
cov_item.parity_ok = (received_parity == parity_accumulator);
coverage_port.write(cov_item);
```

**Step 2 — In `rx_coverage.sv`**, sample it:

```systemverilog
covergroup rx_cg;
    cp_parity: coverpoint item.parity_ok {
        bins valid     = {1};
        bins not_valid = {0};
    }
endgroup
```

That's the full flow — reference model populates the item, coverage samples it. Apply the same pattern to every scenario in your AL.

### What to cover — based on your AL

The scenarios come directly from your AL document. For each group in the AL, decide which field from your reference model captures it, add that field to `rx_coverage_item`, and write a coverpoint. The list includes: packet size, LVT value, lock scenario, CRC error type (length and control separately), control output value, packet phase, parity result, and cross combinations between them.

The **input valid probability** is the only field that does not come from the reference model — sample it directly from the test configuration and add it as a separate coverpoint.

### Self-check before moving on

- [ ] Did you instantiate the covergroup with `= new()` in the constructor?
- [ ] Do you call `rx_cg.sample()` inside `write()`?
- [ ] Does your `rx_coverage_item` carry all the fields your coverpoints need?
- [ ] Are new enums/parameters defined in `rx_typedefs.sv` / `rx_verification_pack.sv`?

---

## Part C — Stimulus Generation

**Files to delete and rewrite:** `sv/sequences/rx_virtual_sequence.sv` + `sv/sequences/rx_input_data_sequence.sv`

### Goal

Implement stimulus that drives the DUT through all the scenarios defined in your AL. How you structure the code is entirely your decision.

Your implementation is considered successful when your coverage reaches **100%**. That is the only measure that matters.

### Constraints

- Never inject errors during the lock phase
- DATA size must always be a multiple of 4
- Parity is XOR over 32-bit words, not individual bytes
- `LOCK_SINGLE_BIT_ERR` is disabled — do not implement it


---

## How Do You Know You Succeeded?

### Run a simulation

```bash
cd runspace

xrun -uvm \
     -f ../list.f \
     +define+UVM_PACKER_MAX_BYTES=10000 \
     -coverage all \
     -covoverwrite \
     -svseed random
```

### Signs of success

```
UVM_INFO: *** S U C C E S S ***
UVM_ERROR count : 0
UVM_FATAL count : 0
```

All three scoreboard channels must show zero mismatches:
```
[RX_SCOREBOARD_DATA]    Matched: N    Mismatches: 0
[RX_SCOREBOARD_CONTROL] Matched: N    Mismatches: 0
[RX_SCOREBOARD_PARITY]  Matched: N    Mismatches: 0
```

### Common failure patterns

| Symptom | Likely cause |
|---|---|
| Scoreboard DATA mismatch | Wrong CRC polynomial, or sending data before LOCKED |
| Scoreboard PARITY mismatch | `parity_accumulator` not reset between packets |
| Scoreboard CONTROL mismatch | Sending `control = 0`, or wrong timing (not immediately after CONTROL CRC) |
| Simulation never reaches LOCKED | LENGTH CRC wrong, or inconsistent phase during lock |
| `FATAL: Randomization failed` | Constraint in nibble send conflicts with data value |

### Debug tips

**Log every FSM transition:**
```systemverilog
`uvm_info(get_name(), $sformatf("FSM → MAYBE_LOCKED (phase=%0d)", current_phase), UVM_MEDIUM)
```

**Reproduce a failing run with a fixed seed:**
```bash
xrun ... +ntb_random_seed=<seed from failing log>
```

**Read the RTL when in doubt** — `dma_rx_len_detect.sv`, `dma_rx_ctrl_proc.sv`, and `dma_rx_parity_check.sv` are your ground truth.

**Use `rx_generation_parameters.sv` to isolate issues** — it controls all probability weights and knobs that drive the test. Adjusting them can help you reproduce specific scenarios or narrow down where something is going wrong.

---

*Enics & IDF Matzov Unit · April 2026*