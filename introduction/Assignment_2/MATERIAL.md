# Assignment 2 — Material & Tasks

This file replaces the old part-by-part PDF: for each of the three exercise files, it teaches just enough of each concept to recognize it and use it, then tells you exactly what to build. You don't need to master any of this deeply yet — you need to be able to look at each construct later and know what it's doing. Depth comes later, in Assignment 3 (Riddles) and the practical project.

Read [README.md](README.md) first for the run workflow (`tsmc65`, `list.f`, `runspace`, `xrun`). Each file below is self-contained — compile and run it on its own, e.g.:

```bash
xrun -gui -debug ../SV-Files-Assignment2/01_decode_the_signal.sv
```

---

## File 1 — `01_decode_the_signal.sv`

### Data Structures (quick reference)

SystemVerilog gives you several containers beyond plain fixed-size arrays:

| Type | Example | Notes |
|---|---|---|
| Fixed array | `byte arr[8];` | Size known at compile time. |
| Dynamic array | `int arr[];` then `arr = new[10];` | Size set at runtime. |
| Queue | `int q[$];` | Grows/shrinks; `push_back`, `push_front`, `pop_back`, `pop_front`, `.size()`. |
| Associative array | `int arr[string];` | Indexed by a key type instead of an integer. |
| Struct | `typedef struct {int a; bit b;} my_t;` | Groups fields together. |

You'll use plain arrays here — nothing fancy, just indexing: `raw_telemetry[1]`.

### Loops (quick reference)

```systemverilog
for (int i = 0; i < 8; i++) ...          // classic counting loop
foreach (raw_telemetry[i]) ...           // iterates every index of the array automatically
while (condition) ...                    // condition-driven loop
```

`foreach` is the one you'll reach for most often in verification code — it can't run off the end of the array by mistake.

### Your Task — Part A

`raw_telemetry` is 8 bytes of noise with 3 real payload bytes hidden at indices 1, 3 and 5. Using any loop you like, copy `raw_telemetry[1]`, `raw_telemetry[3]`, `raw_telemetry[5]` — **in that order** — into `payload[0]`, `payload[1]`, `payload[2]`.

### Streaming Operations (quick reference)

Streaming operators convert between a variable and a raw bit stream, letting you re-slice or re-order data:

```systemverilog
bit [15:0] packed;
byte       bytes[2] = '{8'hAB, 8'hCD};

packed = {bytes};            // straightforward concatenation: 16'hABCD
packed = {<<byte{bytes}};    // byte-order REVERSED: 16'hCDAB  <- endian swap idiom
packed = {<<{bytes}};        // bit-order reversed
```

`{<<byte{...}}` is the standard SystemVerilog idiom for swapping endianness — reversing the order of byte-sized chunks without touching the bits inside each byte. It shows up constantly in real driver/monitor code whenever a protocol's byte order doesn't match your internal representation.

### Your Task — Part B (hardest part of this file)

`payload` holds the right 3 bytes, but in reversed byte order — `payload[0]` is really the *least* significant byte of the real code, not the most significant. Use a streaming operator to reverse the byte order of `payload` into the 24-bit `decoded_code`. If Part A and Part B are both correct, `decoded_code` will be exactly `0xC0FFEE` — and the simulation will tell you so.

---

## File 2 — `02_the_rendezvous.sv`

### Tasks & Functions (quick reference)

| | Function | Task |
|---|---|---|
| Can consume simulation time (`#`, `@`, `wait`) | No | Yes |
| Returns a value | Yes (or `void`) | No (only via `output`/`ref` args) |
| Typical use | Pure computation | Anything that waits on a clock, delay, or event |

```systemverilog
function int double_it(int x);
    return x * 2;
endfunction

task automatic wait_and_print(string msg, int delay);
    #delay;
    $display(msg);
endtask
```

**`automatic` matters.** By default, a task's local variables and *arguments* are static — shared across every call to that task, even concurrent ones. If two processes call the same non-automatic task at the same time, they'll stomp on each other's arguments. `automatic` gives each call its own private copy. Any task you plan to run from multiple parallel processes should be `automatic`.

### Your Task — Part A

Write `task automatic run_racer(string name, int lap_time)`. It should wait `lap_time` time units, append `name` to the `finish_order` queue, increment `racers_done`, and — once all three racers have finished — trigger the `race_finished` event.

### Processes (quick reference)

```systemverilog
fork
    do_a();
    do_b();
    do_c();
join       // waits for ALL three to finish
// join_any  waits for the FIRST one to finish
// join_none returns immediately, all three keep running in the background
```

`fork...join_none` is how you launch things that should genuinely run *at the same time* without blocking the process that launched them.

### Events (quick reference)

```systemverilog
event my_event;

// process A:
-> my_event;              // trigger it

// process B:
@(my_event);               // block until it's triggered
```

An event has no value and no memory — if it's triggered before anyone is waiting on it, that trigger is lost. That's a real hazard in general, but harmless here: the racers all need a minimum delay before they can finish, so the process waiting on `@(race_finished)` is guaranteed to already be waiting well before the first trigger can possibly happen.

### Your Task — Part B (hardest part of this file)

Launch all three racers with `fork...join_none` so they run concurrently (not one after another), then `@(race_finished)` before printing the result. Watch the finish order in the output — it reflects `racer_times`, not the order you wrote the `fork` statements in.

---

## File 3 — `03_generate_and_prove.sv`

### Randomization (quick reference)

```systemverilog
class stim_packet;
    rand bit [3:0] length;
    rand bit       urgent;

    constraint c_length { length inside {[2:12]}; }        // range constraint
    constraint c_urgent { urgent dist {1 := 20, 0 := 80}; } // weighted probability
endclass

stim_packet pkt = new();
void'(pkt.randomize());
```

`inside {[a:b]}` restricts a field to a range. `dist` gives you weighted probabilities instead of a uniform 50/50 — useful when you want something to happen "rarely" (like an error injection) instead of "half the time." This is exactly the mechanism the real project's `generation_parameters.sv` is built on.

### Your Task — Part A

Create and `randomize()` 5 `stim_packet` objects. For each one, `$display` it (length + urgent), then push its `length` field into the `lengths` queue — Part B's generator consumes this queue.

### Assertions (quick reference — the hardest topic in this training)

SystemVerilog Assertions (SVA) let you state a timing/behavioral rule and have the simulator check it automatically, every cycle, for the whole run:

```systemverilog
// "whenever a is true, b must become true within 1 to 20 cycles"
assert property (@(posedge clk) a |-> ##[1:20] b);

// "a and b must never both be true"
assert property (@(posedge clk) !(a && b));
```

- `|->` is implication: "if the left side matches, the right side must also match."
- `##[m:n]` is a bounded delay: "somewhere between m and n cycles later."
- If an `assert property` ever fails, the simulator prints an assertion failure on its own — you don't have to check anything manually.

### Your Task — Part B (hardest part of this file — and of this whole assignment)

A generator (already written for you, in the `always_ff` block) drives `req`/`done` from the `lengths` queue: it raises `req`, holds it for `lengths[i]+1` cycles, then pulses `done` for exactly one cycle while dropping `req` in that same cycle. Write two assertions:

1. `p_mutex` — `req` and `done` must never both be high at the same cycle.
2. `p_eventual_done` — whenever `req` is high, `done` must go high within 1 to 20 cycles.

If both hold for the entire run (no `ASSERTION FAILURE` printed), you've correctly specified — and proven — the timing contract of a block you never even had to look inside.

---

## When You're Done

All three files should run to `$finish` with no unexpected mismatches and no assertion failures. That's it for Assignment 2 — next up is Assignment 3 (Riddles), where you'll do the same kind of reasoning but by reading a waveform instead of trusting the console output.
