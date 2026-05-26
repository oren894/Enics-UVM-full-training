# Student Guide — Implementation Tasks

Read README.md first for architecture overview.

---

## Task A — Enhance the Reference Model

**File:** `sv/components/reference_model/exercise_rx_reference_model.sv`

### What Exists

A reference model with:
- CRC calculation functions
- FSM state variables and lock tracking
- TLM analysis ports ready to send predictions
- Main entry point: `write_input_data()` that receives one byte at a time

Currently it finds valid (LENGTH, LENGTH_CRC) at phase 0 and assumes everything after works. It doesn't re-validate, doesn't correct errors, doesn't handle misalignment.

### What Needs to Happen

Your reference model needs to support several scenarios it currently doesn't:

**Scenarios in NOT_LOCKED state:**
- Valid (LENGTH, LENGTH_CRC) can appear at any phase (0, 1, 2, or 3), not just phase 0
- After finding lock at a phase, subsequent packet boundaries are at that same phase offset

**Scenarios in MAYBE_LOCKED state:**
- Validate CRC multiple times, count consecutive valid packets
- Invalid packet resets the search — back to NOT_LOCKED
- Only after reaching lock_valid_threshold does lock succeed

**Scenarios in LOCKED state:**
- LENGTH_CRC validation + single-bit error correction
- CONTROL_CRC validation + single-bit error correction
- PARITY validation
- Data word accumulation and transmission
- Proper field boundaries aligned to the discovered phase

**Error scenarios:**
- Once locked, if any packet fails CRC validation, call `uvm_fatal()` to stop simulation
- Parity mismatch detection

### The Loop

As you implement each feature in the reference model, modify `generation_parameters.sv` to test it:

Read `generation_parameters.sv` — it has knobs for error probabilities, lock types, phase handling, and more. Add a feature to your reference model, adjust the corresponding parameter value to exercise that feature, run the test.

Does your validation work when errors are injected? Does your error correction fix single-bit errors correctly? Does lock acquisition handle different lock types?

When you can run multiple seeds and always see SUCCESS with 0 mismatches even with various generation parameters enabled, your implementation is solid.

---

## Task B — Define Coverage

**File:** `sv/components/coverage/exercise_rx_coverage.sv`

### What Exists

Coverage item and covergroup that already measure:
- `lock_achieved` — Did we reach LOCKED state?
- `length` — What packet lengths did we see?

### What's Missing

Based on your AL, add more measurement fields to capture what matters for your verification.

### Validation

Once Task A is implemented, run the test multiple times with different seeds. Coverage percentage shows which scenarios occur. If you see 100% coverage and zero failures across runs, your reference model is correct and your coverage definitions match your AL.

---

## Task C — Stimulus & Testing

Your reference model needs to handle different scenarios. This is where you generate them.

Different lock types (regular lock, lock with phase offset, lock with errors). Error injection (corrupted CRCs, bad parity). Real-world conditions (packets of varying sizes, delays between packets, phase misalignment). Your reference model should handle all of it.

The stimulus here is configured to generate these scenarios. You adjust parameters to test different things. Your reference model processes them. Coverage measures what actually happened. If coverage hits 100%, you've tested everything that matters.

---

**Files:**
- `sv/items/exercise_rx_item.sv` — Packet definition
- `sv/sequences/virtual_sequence/exercise_rx_virtual_sequence.sv` — Test orchestration
- `sv/sequences/input_sequence/exercise_rx_input_data_sequence.sv` — Bit transmission
- `sv/generation_parameters/final_rx_generation_parameters.sv` — Test configuration (reference)
- `sv/verification_pack.sv` — Constants and types (reference)

### What Currently Exists

**exercise_rx_item.sv:** Defines a packet structure with fields for length, control, data, parity. Includes randomization and CRC/parity computation.

**exercise_rx_virtual_sequence.sv:** Orchestrates test flow. Launches sequences with different configurations to create varied test scenarios.

**exercise_rx_input_data_sequence.sv:** Takes a packet and transmits it bit-by-bit to the DUT.

**final_rx_generation_parameters.sv:** Reference file showing available probability weights and test configuration options — lock types, error injection probabilities, phase handling, test count limits. You reference this to understand what knobs are available.

**sv/verification_pack.sv:** Reference constants and types available throughout the testbench.

### Helper — Using Parameters and Verification Pack

You can reference `generation_parameters.sv` to see what knobs control behavior. You can read `verification_pack.sv` to see what constants and types are available. If you need to add custom types or constants for your scenarios, they can go in `verification_pack.sv` alongside the existing ones.

Your reference model improvements and coverage definitions drive what matters. The stimulus and parameters support exercising all those scenarios.

---