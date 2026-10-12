# Exercise Reference Model vs. the Real DUT

`exercise_rx_reference_model.sv` is the simple starter version students
build on for Task A. It already does the easy, normal-case stuff. It is
missing the harder stuff on purpose — adding that is the exercise.

This page lists what it already has, and what's left to add, ordered from
**easiest to hardest**.

## What It Already Has

| # | Feature |
|---|---|
| 1 | Builds incoming bytes into 32-bit words |
| 2 | Counts valid packets and locks once it reaches the threshold |
| 3 | Reads a packet in the right order: Length → Control → Data → Parity |
| 4 | Sends out Control, but skips it when Control is zero |
| 5 | Checks parity (XOR of all data words) and reports valid or not |
| 6 | Streams out each Data word as soon as it has 4 bytes |

## What's Missing — Easiest to Hardest

| # | Feature | What it needs |
|---|---|---|
| 1 | Check Control's CRC | Control is trusted with no check at all right now. The code for checking Length's CRC already exists — Control just needs the same kind of check, with its own CRC numbers (already sitting there unused). |
| 2 | Check Length's CRC on every packet, not just the first one | After the first lock, the model stops checking and just assumes every packet is fine. It needs to call the same CRC-check function again for every new packet. |
| 3 | Go back to searching if a packet looks wrong | Once #2 is in place: if the CRC check fails while still confirming the lock, stop trusting it and start the search over from scratch. |
| 4 | Fix Length when exactly one bit is wrong | Instead of just saying "right" or "wrong", try flipping each bit one at a time and see if that makes the CRC match. If one flip fixes it, use the fixed value. |
| 5 | Fix Control the same way | Same idea as #4, just applied to Control instead of Length. |
| 6 | Give up and re-lock if there's more than one bad bit, even while fully locked | Use the "how many bits were wrong" result from #4. 0 or 1 bad bit → keep going. 2 or more → lose lock and start searching again. |
| 7 | Find where a packet actually starts (handling phase) | Right now the model assumes every packet starts right at byte 0. The real DUT checks every possible starting point before it decides where packets begin. This is the biggest change, because it changes how every incoming byte gets read, not just one function. |

## Bonus: Extra Bookkeeping It Doesn't Track

This part isn't about the DUT's behavior — it's extra detail the full
reference model records just for test coverage:

| # | Feature |
|---|---|
| 1 | Only tracks packet length; doesn't track Control value, error counts, or which starting point it locked at |
| 2 | Doesn't track the "several packets of real traffic" pattern used for one of the coverage goals |

## In Short

The model already handles the normal, error-free path correctly.
Everything missing is about handling errors and misaligned packets —
which is exactly what this exercise is meant to teach.
