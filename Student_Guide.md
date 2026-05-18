# DMA RX — Student Guide

> **Level:** Beginner UVM  
> **Prerequisite reading:** README.md (architecture, file structure, protocol) + the VP document

---

## Overview

You are working on a Git repository with three branches — each branch is a different starting point, and you implement the missing pieces.

| Part | Branch to Start From | Files to Implement | Goal |
|---|---|---|---|
| A | `env_without_reference_model` | `sv/components/rx_reference_model.sv` | Golden model that predicts DUT output |
| B | `env_without_reference_model` | `sv/components/rx_coverage.sv` | Functional coverage groups based on your AL |
| C | `uvm_env_without_sequences` | `sv/items/rx_item.sv` + `sv/rx_generation_parameters.sv` + `sv/sequences/rx_virtual_sequence.sv` + `sv/sequences/rx_input_data_sequence.sv` | Stimulus generation — drives all scenarios |

**Do not move to the next part until the current one passes.**

---

## Git Setup — Start Here

The project uses Git with three branches. Before writing a single line of code, set up your workspace correctly.

### Repository Structure

| Branch | Contents | Used For |
|---|---|---|
| `main` | Complete reference implementation — fully working | Reference only — do not work here |
| `env_without_reference_model` | Full env, sequences included. Reference model and coverage are empty stubs | Parts A and B |
| `uvm_env_without_sequences` | Full env with reference model. Item and sequence files are empty stubs | Part C |

### Step-by-Step Setup

**Step 1 — Clone the repository:**
```bash
git clone <repository-url>
cd uvm-verification_full_env
```

**Step 2 — Check out the task branch:**
```bash
# For Parts A and B:
git checkout env_without_reference_model

# For Part C:
git checkout uvm_env_without_sequences
```

**Step 3 — Create your own working branch:**

Never work directly on the shared branches. Create your own branch from the task branch, and name it with your name:
```bash
git checkout -b <your-name>/part-c
```

For example: `git checkout -b yossi-cohen/part-c`

**Step 4 — Verify your starting point:**
```bash
git branch          # confirm you are on your own branch
git log --oneline   # see the commit history
```

---

## Before You Start

Any new enum or parameter you need throughout your implementation goes in `rx_typedefs.sv` or `rx_verification_pack.sv` respectively — keep everything centralized there.

Read these files in order — they are short but critical:

```
1. sv/rx_verification_pack.sv       — global constants (bus widths, CRC params, size limits)
2. sv/rx_typedefs.sv                — agent typedefs and enums: rx_test_type_e, rx_lock_type_e
3. sv/rx_generation_parameters.sv   — all test knobs and probabilities  ← you implement this in Part C
4. dv_agent/dv_monitor_item.sv      — the item type arriving at your model
5. sv/components/rx_scoreboard.sv   — understand what the scoreboard expects to receive
```

Pay attention to the constants already defined in `rx_verification_pack` — use them throughout instead of hardcoding values.

---

## Part A — Reference Model

**File:** `sv/components/rx_reference_model.sv`  
**Branch:** `env_without_reference_model` → your own branch

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

> **Tip:** Cross-check your CRC logic against `rtl/dma_crc_pkg.sv` — the RTL implements the exact same algorithm.

### Self-check before moving on

- [ ] Do you reset `parity_accumulator` to zero at the start of every new packet?
- [ ] Do you suppress all scoreboard writes until FSM is LOCKED?
- [ ] Do you send CONTROL immediately after receiving CONTROL CRC — not at end of packet?
- [ ] Do you only correct **single-bit** errors, never two or more?
- [ ] Do you skip sending CONTROL when its corrected value is exactly `16'h0000`?

---

## Part B — Functional Coverage

**File:** `sv/components/rx_coverage.sv`  
**Branch:** `env_without_reference_model` → your own branch

### How coverage works in this environment

Your coverage component receives information **only from the reference model**. As you implement the reference model, you decide what data to forward to the coverage component. You then write coverpoints over those fields.

The one exception is the **input valid probability**, which comes directly from the test configuration and must be sampled separately.

Functional coverage tracks **which scenarios were exercised**, not whether they passed.

### What to cover

The scenarios come directly from your AL document. For each group in the AL, decide which field from your reference model captures it, add that field to `rx_coverage_item`, and write a coverpoint. Think about: packet size, LVT value, lock scenario, CRC error types, control output value, packet phase, parity result, and cross combinations between them.

### Self-check before moving on

- [ ] Did you instantiate the covergroup with `= new()` in the constructor?
- [ ] Do you call `rx_cg.sample()` inside `write()`?
- [ ] Does your `rx_coverage_item` carry all the fields your coverpoints need?
- [ ] Are new enums/parameters defined in `rx_typedefs.sv` / `rx_verification_pack.sv`?

---

## Part C — Stimulus Generation

**Branch:** `uvm_env_without_sequences` → `git checkout -b <your-name>/part-c`

**Files to implement (all four are stubs in this branch):**
- `sv/items/rx_item.sv`
- `sv/rx_generation_parameters.sv`
- `sv/sequences/rx_virtual_sequence.sv`
- `sv/sequences/rx_input_data_sequence.sv`

### What the branch gives you

The `uvm_env_without_sequences` branch contains a **complete, working UVM environment** — the scoreboard, reference model, coverage, monitors, drivers, and agent are all implemented and connected. The four files above exist in the branch but contain only empty stubs with TODO comments.

This is different from Parts A and B: there, you were filling in components that process data arriving from the bus. Here, **you are generating the data**. The design of your stimulus is entirely your own — there is no single correct solution.

---

### File 1 — rx_generation_parameters.sv

This is your **configuration object** — a plain UVM object (no randomization, no sequencer) that holds all the knobs and probability weights that control how your test behaves. The sequences read from it via the config DB.

**What this file needs to contain:**

- Variables representing probability weights for the different test flows (which test type runs, how often each lock scenario is selected, how often each error type is injected, etc.)
- Variables representing the min/max boundaries for things like packet counts and packet sizes
- A constructor

Everything in this file is just plain member variables with default values — no `rand`, no constraints. The purpose is to give one centralized place to tune the test without touching sequence code.

> Think about what your sequences will need to know in order to make decisions. Every "knob" that you want to be able to tune goes here.

---

### File 2 — rx_item.sv

This is your **transaction object** — the data structure that represents a single RX packet in the UVM world. Before any bits reach the bus, you first describe the packet as an object and randomize it.

**What this file needs to contain:**

- The packet's fields — look at the protocol description to know what a packet contains
- `rand` declarations on the fields you want randomized
- `uvm_object_utils` and `uvm_field_*` macros to register your fields with the UVM factory
- Constraint blocks to keep generated packets legal
- A `post_randomize()` function if you need to compute derived values after randomization

**`uvm_field_*` macros** register each member so UVM knows how to pack, print, compare, and copy it:

```systemverilog
`uvm_object_utils_begin(rx_item)
    `uvm_field_int(my_field,       UVM_DEFAULT | UVM_NOPACK)
    `uvm_field_queue_int(my_queue, UVM_DEFAULT | UVM_NOPACK)
`uvm_object_utils_end
```

> Think carefully about which fields should be `rand` and which should be derived. Fields that are computed from other fields (like CRCs) are usually better handled in `post_randomize()` than randomized directly.

---

### File 3 — rx_virtual_sequence.sv

This is the **test coordinator**. It decides at a high level what the test will do — which scenario to run, how many packets, in what order. It does not drive the bus directly; it delegates that to the physical sequence.

**What this file needs to contain:**

- Randomized knobs that select the test scenario
- Constraints on those knobs
- A `body()` task that orchestrates the full test flow

#### Declaring a physical sequence and accessing its sequencer

The virtual sequence holds a handle to the physical sequence, and uses `p_sequencer` to reach the sequencer it should run on. For this to work you must declare the sequencer type with:

```systemverilog
`uvm_declare_p_sequencer(rx_virtual_sequencer)
```

This macro gives you access to `p_sequencer`, which is a typed handle to the virtual sequencer. From it you can reach the physical sequencer:

```systemverilog
p_sequencer.input_data_sequencer
```

#### uvm_do_on_with — the main tool for launching sequences

The most convenient way to create, constrain, randomize, and run a physical sequence in one shot is:

```systemverilog
`uvm_do_on_with(my_seq, p_sequencer.input_data_sequencer, {
    my_seq.some_field == some_value;
    my_seq.other_field inside {[min : max]};
})
```

What this macro does, step by step:
1. Creates the sequence object if it doesn't exist yet
2. Calls `pre_start()`
3. Randomizes the sequence applying the inline constraints you provide
4. Calls `start()` on the given sequencer, which runs `body()`
5. Calls `post_start()`

The inline constraint block `{ ... }` is just like a regular constraint block — you can use `==`, `inside`, `!=`, ranges, and anything else. These constraints are **added on top of** the sequence's own constraints, so you only need to specify what you want to override or restrict.

You can call this macro as many times as you want, in loops, in case statements — the structure is entirely up to you:

```systemverilog
// Example: repeat a sequence N times with a specific constraint
repeat(n) begin
    `uvm_do_on_with(my_seq, p_sequencer.input_data_sequencer, {
        my_seq.some_flag == 0;
    })
end
```

#### dist — weighted randomization for scenario selection

When you have a `rand` knob that selects between scenarios, use `dist` in your constraint to give each value a relative probability weight. The weights don't need to sum to 100 — they are relative:

```systemverilog
rand my_enum_t scenario;

constraint scenario_c {
    scenario dist {
        SCENARIO_A := parameters.WEIGHT_A,
        SCENARIO_B := parameters.WEIGHT_B,
        SCENARIO_C := parameters.WEIGHT_C
    };
}
```

This is what connects your generation parameters file to the actual randomization — the weights come from there, so you can tune probabilities without touching the sequence code.

#### Getting configuration from the config DB

The generation parameters object is passed to your sequence through the UVM config DB. Retrieve it in `pre_randomize()` so it is available before constraints are evaluated:

```systemverilog
function void pre_randomize();
    if (!uvm_config_db #(rx_generation_parameters)::get(
            null, this.get_full_name(), "parameters", this.parameters))
        `uvm_fatal(get_name(), "Couldn't find generation parameters")
endfunction
```

`pre_randomize()` runs automatically before every `randomize()` call — it is the right place to fetch anything your constraints depend on.

#### Raising and dropping objections

The simulation ends when all objections are dropped. The virtual sequence is responsible for keeping the simulation alive while the test runs:

```systemverilog
task pre_start();
    if (get_parent_sequence() == null && starting_phase != null)
        starting_phase.raise_objection(this, "Starting");
endtask

task post_start();
    if (get_parent_sequence() == null && starting_phase != null)
        starting_phase.drop_objection(this, "Ending");
endtask
```

Raise in `pre_start()`, drop in `post_start()`. If you forget to drop the objection the simulation will hang; if you drop it too early the simulation will end before the test finishes.

---

### File 4 — rx_input_data_sequence.sv

This is the **physical sequence** — it takes one packet and delivers it to the driver bit by bit. This is where the actual bus protocol lives.

**What this file needs to contain:**

- Your `rx_item`
- A `body()` task that packs the item into bits and sends it to the driver in chunks

#### Packing — from packet to bits

```systemverilog
bit packed_bits[];
item.pack(packed_bits);
```

`pack()` uses the `uvm_field_*` macros you registered and serializes all fields into a flat bit array, in the order they were declared. The driver doesn't know about packets — it only knows about fixed-width chunks. This is how you bridge between the two worlds.

#### Sending chunks — start_item / finish_item

```systemverilog
my_seq_item chunk = my_seq_item::type_id::create("chunk");

start_item(chunk);   // wait until the driver is ready
// fill chunk with the next N bits from your packed array
finish_item(chunk);  // hand off to the driver, wait until it's done
```

`start_item` blocks until the driver calls `get_next_item()`. `finish_item` hands the chunk over and blocks until the driver calls `item_done()`. Every `finish_item` is one transaction on the bus. You can also use `uvm_do_on_with` here instead — same result, more compact syntax.

#### The leftover-bits problem

A packet's bit length won't always divide evenly by the chunk width. The leftover bits from the end of one packet need to be prepended to the next — otherwise byte alignment silently drifts and every scoreboard comparison after that point will fail.

> If you see DATA mismatches and everything else looks correct, start here.

---

### Constraints to keep in mind

- DATA size must always be a multiple of 4 bytes
- Parity is XOR over 32-bit words — not individual bytes
- `LOCK_SINGLE_BIT_ERR` is disabled — do not implement it
- Never inject errors during the lock phase (unless the lock scenario specifically calls for it)

---

### Success criterion

Your implementation is considered successful when functional coverage reaches **100%**. That is the only measure that matters.

---

### Debugging tips

**Start with one scenario and expand.** Don't try to implement all lock types at once. Get the simplest lock working and verify the scoreboard matches before adding complexity.

**Use your generation parameters file.** Temporarily set one probability to 100 and everything else to 0 — this forces a specific scenario every run, making failures reproducible without needing a fixed seed.

**Fix the random seed to reproduce a failure:**
```bash
xrun ... +ntb_random_seed=<seed_from_failing_log>
```
The failing seed appears in the log.

**Add UVM info messages at key transitions** — FSM state changes, lock acquisition, packet boundaries — so you can trace what is happening in the log.

**Read the RTL when something doesn't match** — `dma_rx_len_detect.sv`, `dma_rx_ctrl_proc.sv`, and `dma_rx_parity_check.sv` are your ground truth for exactly what the DUT does with each field.

**Common failure patterns:**

| Symptom | Where to look |
|---|---|
| Simulation never reaches LOCKED | Lock phase packet format, or junk bytes accidentally forming a valid packet |
| `FATAL: Randomization failed` | Conflicting constraints in your rx_item |
| Coverage stuck below 100% | A scenario is never selected — check knob constraints and probability weights |
| Scoreboard DATA mismatch | Byte alignment on the bus — check your leftover-bits handling |
| Scoreboard PARITY mismatch | Parity computation or error injection logic |
| Scoreboard CONTROL mismatch | Sending control=0, or wrong timing relative to field boundaries |

---

## Running the Simulation

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

[RX_SCOREBOARD_DATA]    Matched: N    Mismatches: 0
[RX_SCOREBOARD_CONTROL] Matched: N    Mismatches: 0
[RX_SCOREBOARD_PARITY]  Matched: N    Mismatches: 0
```
