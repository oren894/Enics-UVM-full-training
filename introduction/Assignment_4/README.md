# Assignment 4 — Build a FIFO

Assignment 3 taught you to read bugs off a waveform. Now build something from a blank page: a First-In-First-Out buffer — the single most common building block in digital design, and something you'll see for real inside the DUT you verify in the final stage of this training.

This assignment is one exercise, not several. Budget about an hour. Unlike the previous assignments, `simple_fifo.sv` is not pre-loaded with any hints — you get a port list, a spec, and a self-checking testbench that will tell you exactly what's wrong if something is.

---

## What a FIFO Is (quick reference)

A FIFO is a circular buffer with two independent sides:

- **Write side:** `wr_en` + `wr_data` push a new item in, if there's room (`!full`).
- **Read side:** `rd_en` pops the oldest item out, if there's anything there (`!empty`).

Internally, it's just an array (`mem`) plus two pointers that chase each other around it:

```
wr_ptr -> where the NEXT write will land
rd_ptr -> where the NEXT read will come from
```

Both pointers only ever move forward and wrap back to 0 after the last slot — that's the "circular" part. The tricky bit is telling `full` apart from `empty`: both happen when `wr_ptr == rd_ptr`. That's exactly why `simple_fifo.sv` also has a `count` register — instead of comparing pointers, you track how many valid entries are in the buffer right now, and `full`/`empty` fall straight out of that:

```systemverilog
assign full  = (count == DEPTH);
assign empty = (count == 0);
```

## The Spec

Full spec is in the comment block inside `SV-Files-Assignment4/simple_fifo.sv`. In short:

1. `full`, `empty`, and `rd_data` (the item at the front of the queue) are all **combinational** — always reflecting the current state, not delayed by a cycle.
2. Writes and reads only take effect on a clock edge, and only when legal (`wr_en && !full`, `rd_en && !empty`).
3. `count` must correctly reflect *net* change: +1 for a write-only cycle, -1 for a read-only cycle, unchanged for simultaneous read+write or for an idle cycle.
4. Everything resets cleanly.

`DEPTH` is fixed at a power of 2 on purpose. A plain `PTR_WIDTH`-bit register wraps back to 0 on its own via ordinary binary overflow when `DEPTH == 2**PTR_WIDTH` — you don't need an explicit "if at the last slot, reset to 0" check. That's one less thing to get wrong.

## Running It

```bash
tsmc65
cd runspace   # or mkdir -p runspace && cd runspace
xrun -gui -debug -access +rwc -f ../list.f
```

The testbench (`simple_fifo_tb.sv` — read-only, it's your judge, not part of the exercise) drives your FIFO against a plain SystemVerilog queue used as a golden model: fills it to full, tries to overfill it, drains it to empty, tries to over-read it, then hammers simultaneous read+write for a while and drains what's left. If your FIFO disagrees with the model at any point, you'll get a specific `MISMATCH` line telling you exactly which cycle and which signal.

## If You Get Stuck

Put `wr_ptr`, `rd_ptr`, `count`, `full`, `empty`, `wr_data`, `rd_data` on a waveform (same skill as Assignment 3) and watch them move — a FIFO bug almost always shows up as a pointer moving on the wrong cycle, or `count` drifting by one somewhere it shouldn't.

When you see `S U C C E S S` with 0 mismatches, you're done. Next up: Assignment 5 (UVM).
