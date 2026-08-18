# DMA RX — UVM Verification Environment

> **Complete Verification Framework** | SystemVerilog · UVM · Xcelium · CRC · Parity  
> **With Built-In Training Exercises**

**TL;DR:** Complete UVM test environment. Can run as-is with final implementations, or work through 3 optional implementation tasks (reference model, coverage, stimulus).

## ⚠️ **Note:** Training Exercises Included, If you are starting the training, please go to the `README.md` file in the `../introduction` folder first.




This repository contains **three progressive implementation tasks** for learning UVM verification:
- **Task A:** Implement the reference model (golden predictor)
- **Task B:** Implement functional coverage collection  
- **Task C:** Implement stimulus generation

See **STUDENT_GUIDE_FRIENDLY.md** for implementation details. These exercises are optional — you can also run the environment with all final implementations using `list_full.f`.

---

## Table of Contents

- [Overview](#overview)
- [DUT — What Are We Verifying?](#dut--what-are-we-verifying)
- [Packet Protocol](#packet-protocol)
- [Environment Architecture](#environment-architecture)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Running a Simulation](#running-a-simulation)
- [Running Regression](#running-regression)
- [Key Parameters & Knobs](#key-parameters--knobs)
- [Test Scenarios](#test-scenarios)
- [Coverage Strategy](#coverage-strategy)
- [Exercise Task Structure](#exercise-task-structure)
- [Known Limitations](#known-limitations)

---

## Overview

This repository contains a complete **UVM-based functional verification environment** for the `dma_rx_top` module — the **receive (RX) front-end of a DMA controller**.

The environment exercises the DUT by injecting 4-bit serial nibble streams, verifying that the DUT correctly:

- Locks onto a byte-aligned packet stream (FSM lock acquisition)
- Parses multi-field packet frames (Length, Control, Data, Parity)
- Detects and corrects single-bit CRC errors
- Validates end-of-packet XOR parity signatures
- Outputs processed 32-bit data words and 16-bit control words

---

## DUT — What Are We Verifying?

**Module:** `dma_rx_top`  
**Location:** `rtl/dma_rx_top.sv`

The DUT receives a **4-bit nibble serial stream** and processes it through a pipeline of sub-modules:

| Sub-Module | Responsibility |
|---|---|
| `dma_rx_fsm` | FSM — manages lock state (NOT_LOCKED → MAYBE_LOCKED → LOCKED → FATAL) |
| `dma_rx_phase_ctrl` | Tracks active packet phase (Control / Length / Data / Parity) |
| `dma_rx_len_detect` | Sliding-window length detection with CRC validation |
| `dma_rx_ctrl_proc` | Parses 16-bit control field + 16-bit CRC |
| `dma_rx_data_proc` | Accumulates nibbles into 32-bit data words |
| `dma_rx_parity_check` | XOR parity validation across the full data payload |
| `dma_rx_write` | DMA write engine — outputs to memory interface |
| `dma_rx_config` | Latches DMA configuration (base address, page size, etc.) |

### DUT Ports (Key Signals)

```
Inputs:
  clk, rst_n
  input_data[3:0]       — 4-bit nibble stream
  input_valid           — handshake valid
  lock_valid_threshold[15:0] — configures lock sensitivity (randomized per test)
  config_in             — DMA configuration struct
  fetch_enable          — triggers config latch

Outputs:
  data_out[31:0]        — processed 32-bit data word
  output_valid          — data word valid strobe
  control_out[15:0]     — extracted control field
  control_valid         — control word valid strobe
  parity_valid          — parity check passed
  parity_not_valid      — parity check failed
  mem_addr/mem_data/mem_write_enable/mem_valid — DMA memory interface
  write_complete        — DMA transaction done
  pages_written[15:0]   — DMA page count
```

---

## Packet Protocol

Each packet sent to the DUT has the following structure:

```
┌────────────────┬──────────────────┬─────────────────────┬─────────────┬──────────────────┐
│  LENGTH field  │   LENGTH CRC     │   CONTROL field      │  DATA bytes │  PARITY (XOR-32) │
│   (16 bits)    │   (16 bits)      │   (16+16 bits)       │  (variable) │   (32 bits)      │
└────────────────┴──────────────────┴─────────────────────┴─────────────┴──────────────────┘
```

- **Length field**: specifies data payload size (bytes). CRC polynomial: `0x1021`, init: `0xFFFF`
- **Control field**: 16-bit header. CRC polynomial: `0x8005`, init: `0x0000`
- **Data**: 4–8192 bytes (optimal: 4096 bytes)
- **Parity**: 32-bit XOR over all data words

The DUT must find the packet boundary via a **sliding window** over `(LENGTH + LENGTH_CRC)` bits — any of 4 byte offsets can be the correct alignment.

---

## Environment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        rx_base_test                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   rx_environment                      │  │
│  │                                                       │  │
│  │  ┌────────────────────┐    ┌───────────────────────┐  │  │
│  │  │  rx_virtual_seq    │    │  rx_reference_model   │  │  │
│  │  │  (stimulus         │    │  (golden model —      │  │  │
│  │  │   orchestration)   │    │   predicts outputs)   │  │  │
│  │  └────────┬───────────┘    └──────────┬────────────┘  │  │
│  │           │                           │               │  │
│  │  ┌────────▼──────────┐      ┌─────────▼──────────┐   │  │
│  │  │ dv_agent (ACTIVE) │      │  rx_scoreboard ×3  │   │  │
│  │  │ input_data_agent  │      │  (data/ctrl/parity) │   │  │
│  │  │  Driver+Monitor   │      └────────────────────┘   │  │
│  │  └───────────────────┘                               │  │
│  │                                                       │  │
│  │  ┌────────────────────┐    ┌───────────────────────┐  │  │
│  │  │ dv_agent (PASSIVE) │    │    rx_coverage        │  │  │
│  │  │ output_data_agent  │    │ (functional coverage) │  │  │
│  │  │ control_agent      │    └───────────────────────┘  │  │
│  │  │ parity_agent       │                               │  │
│  │  └───────────────────┘                               │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                   ┌──────────▼──────────┐
                   │     dma_rx_top      │
                   │       (DUT)         │
                   └─────────────────────┘
```

### Component Roles

| Component | File | Role |
|---|---|---|
| `rx_base_test` | `sv/tests/rx_base_test.sv` | Top-level test. Builds environment, randomizes parameters, launches virtual sequence |
| `rx_environment` | `sv/rx_environment.sv` | Instantiates and connects all agents, scoreboards, reference model, coverage |
| `rx_virtual_sequence` | `sv/sequences/virtual_sequence/exercise_rx_virtual_sequence.sv` | Orchestrates lock acquisition + stimulus phases |
| `rx_input_data_sequence` | `sv/sequences/input_sequence/exercise_rx_input_data_sequence.sv` | Builds individual packet frames (nibble-level) |
| `rx_reference_model` | `sv/components/reference_model/exercise_rx_reference_model.sv` | Golden model — predicts expected data/control/parity outputs |
| `rx_scoreboard` | `sv/components/rx_scoreboard.sv` | Compares DUT output vs. reference model (parameterized for 3 channels) |
| `rx_coverage` | `sv/components/coverage/exercise_rx_coverage.sv` | Functional coverage collection |
| `dv_agent` | `dv_agent/dv_agent.sv` | Generic reusable UVM agent (parameterized by data width) |
| `rx_generation_parameters` | `sv/generation_parameters/exercise_rx_generation_parameters.sv` | Test configuration object with all probability knobs |

---

## Repository Structure

```
rx-uvm-env/
├── introduction/                 # Assignments 1-4 (sibling folder — see ../introduction)
└── UVM_Training/                 # This folder
    ├── introduction_uvm/         # UVM concept slides — start here before Tasks A/B/C
    │   ├── UVM Basics (3).pptx
    │   ├── UVM IPC(1).pptx
    │   ├── UVMSequenceSequencer.pptx
    │   └── new_agent_presentation.pptx
    │
    ├── rtl/                          # DUT RTL source files
    │   ├── dma_rx_top.sv             # Top-level DUT
    │   ├── dma_rx_fsm.sv             # Lock FSM
    │   ├── dma_rx_phase_ctrl.sv      # Packet phase controller
    │   ├── dma_rx_len_detect.sv      # Length & CRC detection (sliding window)
    │   ├── dma_rx_ctrl_proc.sv       # Control field processor
    │   ├── dma_rx_data_proc.sv       # Data accumulator
    │   ├── dma_rx_parity_check.sv    # XOR parity validator
    │   ├── dma_rx_write.sv           # DMA write engine
    │   ├── dma_rx_config.sv          # Configuration register file
    │   ├── dma_rx_config_apb.sv      # APB config interface
    │   ├── dma_config_pkg.sv         # DMA config struct (dma_config_t)
    │   ├── dma_crc_pkg.sv            # CRC utilities package
    │   └── dma_rx_pkg.sv             # RX package (FSM state enum, etc.)
    │
    ├── dv_agent/                     # Generic reusable UVM agent
    │   ├── dv_agent.sv               # Agent top (parameterized)
    │   ├── dv_driver.sv              # Driver — drives VIF from sequence items
    │   ├── dv_monitor.sv             # Monitor — samples VIF, broadcasts items
    │   ├── dv_if.sv                  # Interface (parameterized DATA_WIDTH)
    │   ├── dv_sequence_item.sv       # Input sequence item
    │   ├── dv_monitor_item.sv        # Monitor item (observed transactions)
    │   └── dv_sequencer.sv           # UVM sequencer
    │
    ├── sv/                           # UVM verification components
    │   ├── rx_top_tb.sv              # Top-level testbench (DUT instantiation)
    │   ├── rx_verification_pack.sv   # Global constants & parameters
    │   ├── rx_typedefs.sv            # Enums & type aliases
    │   ├── rx_environment.sv         # UVM environment
    │   ├── rx_report_server.sv       # Custom UVM report server
    │   ├── tests/
    │   │   └── rx_base_test.sv       # Base test
    │   ├── sequences/
    │   │   ├── virtual_sequence/
    │   │   │   ├── exercise_rx_virtual_sequence.sv
    │   │   │   └── final_rx_virtual_sequence.sv
    │   │   └── input_sequence/
    │   │       ├── exercise_rx_input_data_sequence.sv
    │   │       └── final_rx_input_data_sequence.sv
    │   ├── sequencers/
    │   │   └── rx_virtual_sequencer.sv     # Virtual sequencer
    │   ├── items/
    │   │   ├── rx_item/
    │   │   │   ├── exercise_rx_item.sv
    │   │   │   └── final_rx_item.sv
    │   │   └── coverage_item/
    │   │       ├── exercise_rx_coverage_item.sv
    │   │       └── final_rx_coverage_item.sv
    │   ├── generation_parameters/
    │   │   ├── exercise_rx_generation_parameters.sv
    │   │   └── final_rx_generation_parameters.sv
    │   └── components/
    │       ├── rx_scoreboard.sv       # Parameterized scoreboard
    │       ├── coverage/
    │       │   ├── exercise_rx_coverage.sv
    │       │   └── final_rx_coverage.sv
    │       └── reference_model/
    │           ├── exercise_rx_reference_model.sv
    │           └── final_rx_reference_model.sv
    │
    ├── scripts/
    │   ├── run_regression.py         # Parallel regression runner (qsub-based)
    │   └── sim.tcl                   # Simulation waveform setup
    │
    ├── documents/                    # AL, Verification Plan, block intro doc
    │
    ├── runspace/                     # Simulation work directory (gitignored)
    │   └── logs/                     # Simulation logs
    │
    ├── list_exercise_A_B.f           # File list for Tasks A & B (uses exercise files)
    ├── list_exercise_C.f             # File list for Task C (uses exercise files)
    ├── list_full.f                   # File list for reference (all final files)
    ├── README.md                     # This file
    └── Student_Guide.md              # Student task guide
```

---

## Getting Started

```bash
git clone <repository-url>
cd rx-uvm-env/UVM_Training

# Create your working branch
git checkout -b <your-name>/tasks

# Read the Student_Guide.md for detailed task instructions
cat Student_Guide.md
```

---

## Running a Simulation

### Basic simulation (Task A/B) — No waveforms

```bash
cd runspace

xrun -uvm \
     -f ../list_exercise_A_B.f \
     +define+UVM_PACKER_MAX_BYTES=10000 \
     -svseed random
```

### Basic simulation with waveforms (Task A/B)

```bash
cd runspace

xrun -uvm \
     -f ../list_exercise_A_B.f \
     +define+UVM_PACKER_MAX_BYTES=10000 \
     -input ../scripts/sim.tcl \
     -access +rwc \
     -svseed random
```

Then view waveforms in SimVision: `simvision dump`

### Basic simulation with coverage (Task A/B)

```bash
cd runspace

xrun -uvm \
     -f ../list_exercise_A_B.f \
     +define+UVM_PACKER_MAX_BYTES=10000 \
     -coverage all \
     -covoverwrite \
     -covworkdir ./cov_work \
     -covtest manual_run
```

### Simulation for Task C

```bash
cd runspace

xrun -uvm \
     -f ../list_exercise_C.f \
     +define+UVM_PACKER_MAX_BYTES=10000 \
     -coverage all \
     -covoverwrite
```

A successful run will print **`S U C C E S S`** near the end of the log.

---

### Viewing Waveforms in SimVision

#### First Time — Load the Database

After the simulation finishes, open SimVision:

```bash
simvision dump
```

Or from within SimVision:
```
File → Open Database → select dump
```

Once the database is loaded:
1. In the **Design Browser** panel (left), expand the DUT hierarchy
2. Select signals and drag them into the **Waveform Window**
3. Press **F** to zoom to the full simulation time
4. Save your layout: `File → Save As → mysignals.svcf`

#### Subsequent Runs — Reload Only

After re-running the simulation, inside SimVision:
```
File → Reload Databases
```
Or press **Ctrl+Shift+R** — SimVision refreshes the waveforms while keeping your signal layout intact.

To reopen SimVision with your saved layout directly:
```bash
simvision mysignals.svcf
```

> **Tip:** Load the database + arrange signals + save `.svcf` **once** — every run after that is just re-run xrun → **Reload Databases**.

---

## Running Regression

The regression runner submits parallel jobs to a grid (SGE/OGS via `qsub`) and aggregates results.

```bash
cd runspace
python3 ../scripts/run_regression.py
```

### Regression Options

| Flag | Description | Default |
|---|---|---|
| `-n, --runs N` | Number of total runs | `1` |
| `-p, --parallel N` | Max simultaneous grid jobs | `20` |
| `-f, --filelist PATH` | Override `list_exercise_A_B.f` path | hardcoded |
| `-x, --xrun-flags FLAGS` | Extra flags passed to every xrun invocation | `""` |

**Examples:**
```bash
# Run 50 regressions, 10 in parallel
python3 ../scripts/run_regression.py -n 50 -p 10

# Run with debug define
python3 ../scripts/run_regression.py -n 10 -x "+define+DEBUG"
```

### Regression Output

After completion, results are in `runspace/logs/`:
- `summary.log` — pass/fail counts per seed
- `main.log` — full aggregated log
- `run_N.log` — individual run log

**Coverage merge** (after regression):
```bash
cd runspace/cov_work/scope
imc -i -exec merge.tcl
```

---

## Key Parameters & Knobs

All test parameters are centralized in `rv_generation_parameters.sv` and can be adjusted without touching test code:

### Stimulus Probabilities

| Parameter | Description | Default |
|---|---|---|
| `RUN_RANDOM_TEST_P` | Weight for TEST_REGULAR (fast, random lengths) | `50` |
| `RUN_REAL_TEST_P` | Weight for TEST_REAL (long, realistic traffic) | `50` |
| `LOCK_REGULAR_TEST_P` | Weight for standard lock acquisition | `1` |
| `LOCK_ONE_PACKET_OUT_TEST_P` | Lock with one oversized packet | `1` |
| `LOCK_PHASE_CHANGE_TEST_P` | Inject phase change before lock | `1` |
| `LOCK_MULTI_BIT_ERR_TEST_P` | Inject wrong-length packet during lock | `1` |
| `INPUT_DATA_VALID_100_PERCENT_P` | Full throughput (valid every cycle) | `33` |
| `INPUT_DATA_VALID_25_PERCENT_P` | Low throughput (25% valid cycles) | `33` |
| `INPUT_DATA_VALID_1_TO_4_RATIO_P` | Bursty (1-in-4 valid cycles) | `34` |

### Packet Size Limits

| Parameter | Value |
|---|---|
| `MIN_DATA_SIZE` | 4 bytes |
| `MAX_DATA_SIZE` | 8192 bytes |
| `OPTIMAL_DATA_SIZE` | 4096 bytes |

### Lock Threshold

`lock_valid_threshold` is randomized per simulation run:
- Range: `2–12`
- Optimal: `7`
- Distribution: 25% chance of optimal, 75% random within range

---

## Test Scenarios

Each test run randomly selects a combination of **Lock Type** and **Test Type**:

### Lock Types (How the DUT Acquires Lock)

| Lock Type | Description |
|---|---|
| `LOCK_REGULAR` | Send `LVT` consecutive valid minimum-size packets |
| `LOCK_ONE_PACKET_OUT` | Lock with one non-minimum-size packet mixed in |
| `LOCK_PHASE_CHANGE` | Inject a half-packet (phase disruption) then re-lock |
| `LOCK_MULTI_BIT_ERR` | Send a wrong-length packet during lock sequence |

### Test Types (Post-Lock Traffic)

| Test Type | Description | Duration |
|---|---|---|
| `TEST_REGULAR` | 100–1000 random-length packets | ~1–2 min |
| `TEST_REAL` | 10–100 transactions, each with bursts of min+optimal packets | ~30–40 min |

### Test Flow

```
1. Send initial junk (random phase offset, 0–100 bytes)
2. Execute selected Lock Type sequence
3. If locked: execute selected Test Type traffic
4. Send trailing half-packet to flush DUT state
```

---

## Coverage Strategy

The environment collects functional coverage in `rx_coverage.sv`. Key coverage goals include:

- **FSM state transitions**: NOT_LOCKED → MAYBE_LOCKED → LOCKED → FATAL
- **Packet sizes**: min / optimal / max / random
- **CRC scenarios**: clean / 1-bit error / multi-bit error
- **Parity outcomes**: valid / invalid
- **Lock threshold values**: all values across MIN–MAX range
- **Input valid patterns**: 100% / 25% / 1-in-4
- **Lock scenarios**: all 4 lock types
- **Control word values**: null (0x0000) vs. non-null

---

## Training Exercises

This project includes three optional implementation tasks:

| Task | Component | Purpose |
|------|-----------|---------|
| **A** | Reference Model | Golden predictor — matches DUT behavior |
| **B** | Coverage Collection | Measures which test scenarios were exercised |
| **C** | Stimulus Generation | Creates and sends test packets |

**See STUDENT_GUIDE_FRIENDLY.md for implementation details.** Each task is 40-60% pre-implemented; you fill in the core algorithms.

To run with all **final implementations** (skip exercises): `xrun -f list_full.f ...`

To run with **exercise files** (implement Task A/B): `xrun -f list_exercise_A_B.f ...`

To run with **exercise files** (implement Task C): `xrun -f list_exercise_C.f ...`

---

## Known Limitations

- `LOCK_SINGLE_BIT_ERR` lock type is currently **disabled** — the DUT does not support single-bit length CRC correction during lock acquisition.
- `config_in` / `dma_rx_write` integration has a known open TODO regarding busy-signal protocol handshake.
- `mem_valid` is not currently connected to the testbench output monitor.
- Regression runner requires Cadence grid environment (`qsub`/`qstat`) — not portable to standalone Xcelium without modification.