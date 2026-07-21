# Assignment 3 — Riddles: Waveforms, Blocking vs. Non-Blocking

You already know SystemVerilog syntax (Assignment 2). Before you build something real (Assignment 4 — a FIFO) and then learn UVM (Assignment 5), you need one more skill: **reading a waveform and knowing exactly when a signal is supposed to change, and why.**

This assignment is three short, self-contained "detective cases." Each one is a tiny piece of hardware with one bug. None of them require UVM. All of them require you to actually open the waveform, not just read the code.

**Rules for every case:**
1. **Predict first.** Before you run anything, read the DUT and write down (on paper, in your head, wherever) what you expect to see.
2. **Run it and look at the waveform**, not just the `S U C C E S S` / `MISMATCH` text. The text tells you *that* something is wrong; the waveform tells you *why*.
3. **Answer the questions** for that case — out loud to yourself, to a teammate, or to your mentor. If you can't answer them, you don't understand the bug yet, even if your fix happens to work.
4. **Fix it**, re-run, and confirm the waveform now looks the way you predicted a correct design should look.

---

## Getting Started

Same workflow as Assignment 2:

```bash
tsmc65
code .
```

Then, for each case, compile and run it directly with waveform access (no `list.f` needed — each file is one self-contained testbench):

```bash
mkdir -p runspace && cd runspace
xrun -gui -debug -access +rwc ../SV-Files-Assignment3/case1_blocking_vs_nonblocking.sv
```

Once the simulation finishes, open the waveform database (`simvision dump`, or use the `-gui` window that opened automatically) and drag in the signals mentioned in each case below.

---

## Case 1 — The Collapsing Pipeline

**File:** `SV-Files-Assignment3/case1_blocking_vs_nonblocking.sv`

Two 3-stage shift registers, `stage0/1/2_nb` (correct, non-blocking) and `stage0/1/2_bug` (broken, blocking), driven by the exact same `clk`, `rst_n` and `data_in`.

**Waveform:** put `data_in`, `stage0_nb`, `stage1_nb`, `stage2_nb`, `stage0_bug`, `stage1_bug`, `stage2_bug` on the same window, stacked in that order.

**Questions:**
1. When `data_in` pulses for exactly one cycle, how many cycles does it take the reference pipeline (`*_nb`) to show that pulse on `stage2_nb`? Does that match what you'd expect from three flip-flops in series?
2. In the buggy pipeline, on the *same* clock edge that `data_in` is captured, which other stage(s) also change? Why does a blocking assignment (`=`) let that happen inside a clocked `always_ff` block, when a non-blocking assignment (`<=`) doesn't?
3. `stage0_bug` never disagrees with `stage0_nb`, but `stage1_bug` and `stage2_bug` do, and `stage2_bug` is "more wrong" than `stage1_bug`. Why does the error get worse at each stage instead of staying constant?
4. In your own words: when a non-blocking assignment executes, does the right-hand side use the value from *before* the always block ran, or the value *after* the earlier statements in the same block already updated it? What about blocking?

**Fix:** in the marked block, change every `=` to `<=`. Don't restructure anything else.

---

## Case 2 — The Phantom Latch

**File:** `SV-Files-Assignment3/case2_priority_grant.sv`

A 4-input priority grant block. `req[3]` is highest priority, `req[0]` lowest, and `grant` should be all-zero when no request is active.

**This is not a blocking/non-blocking bug** — every assignment already uses `=` correctly inside `always_comb`.

**Waveform:** the testbench sweeps `req` through all 16 values automatically. Put `req` and `grant` on the waveform and step through the sweep.

**Questions:**
1. Which values of `req` produce a `grant` that doesn't match a priority encoder? What do they have in common?
2. Look at the `always_comb` block. For those `req` values, is there any statement that assigns `grant` at all? If `grant` isn't assigned on some path, what value does it hold in simulation — and what would it turn into in real silicon?
3. Why do simulators (and synthesis tools) warn about an `always_comb`/`always @*` block that doesn't drive its output on every possible input combination? What hardware structure does that turn into?

**Fix:** add whatever `else`/`else if` branch(es) are missing so `grant` is driven on every path.

---

## Case 3 — The Eager Door

**File:** `SV-Files-Assignment3/case3_vault_fsm.sv`

A small "vault" FSM: `VAULT_LOCKED → VAULT_MAYBE → VAULT_OPEN`, needs two consecutive `key_pulse` cycles to open, closes again as soon as `key_pulse` drops while open. This is the same shape (`current_state` / `next_state`, sequential register + combinational next-state logic) as the real `dma_rx_fsm` you'll work with in the full practical environment — this is a preview.

**Waveform:** put `clk`, `rst_n`, `key_pulse`, `state`, `next_state`, `door_open` together, in that order.

**Questions:**
1. Look closely at the cycle where `state` first becomes `VAULT_OPEN`. Does `door_open` rise on that same cycle, one cycle earlier, or one cycle later?
2. Find the line that drives `door_open`. Is it watching `state` or `next_state`? Given what `next_state` represents (the state we're *about to* move to, computed combinationally this cycle), explain why that produces the timing you saw in question 1.
3. Is this a blocking-vs-non-blocking bug? Why or why not — what *is* it, then?
4. Generalize: when you build an output that should reflect "what state are we in right now," which signal should you always read from — the current state register, or the next-state logic? When (if ever) would you deliberately want the opposite?

**Fix:** change `assign door_open = (next_state == VAULT_OPEN);` to read `state` instead.

---

## Why This Matters

The FIFO you're about to build (Assignment 4), and the real project after that, live on exactly these three lessons: knowing when a register actually updates, making sure combinational logic is always fully driven, and knowing which signal — current or next state — an output should really be watching.

When all three cases print `S U C C E S S` **and** you can explain each bug and fix out loud without looking at this file again, you're ready for Assignment 4.
