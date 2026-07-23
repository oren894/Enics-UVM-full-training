# Verification Training Introduction

**Prerequisite:** Before starting, it is highly recommended to install a PDF reader extension for your browser to easily view the reference materials and manuals included in this training.

## The Verification Training Process

Welcome to the verification training program. This path is designed to take you from the fundamentals of SystemVerilog to understanding and implementing a complete practical verification environment. The training is divided into six main stages:

### Assignment 1: SystemVerilog Fundamentals
This assignment focuses on general learning about SystemVerilog (SV). You will be tasked with basic questions to help you get familiar with the language's syntax and core paradigms. The answers to these questions are readily available online—researching them independently is a key part of the learning process.

### Assignment 2: Hands-On SystemVerilog
Here, you will transition from theory to practice. Three short, self-checking exercises — each combining a couple of related SV topics (data structures & loops & streaming operations / tasks & processes & events / randomization & assertions) into one themed scenario with a light warm-up and a harder capstone. `MATERIAL.md` inside the assignment folder teaches the underlying concepts and lays out the tasks — read it in place of the old part-by-part PDF.

### Assignment 3: Riddles — Waveforms & Blocking vs. Non-Blocking
Before touching a real DUT, you need to be comfortable reading a waveform and reasoning about *when* signals actually update — not just what the code says. Three short "detective" cases: a shift register broken by a blocking assignment, an unintended latch, and an FSM output watching the wrong signal. Short and self-contained (no UVM required), but not trivial — take it seriously, later stages assume you've internalized it.

### Assignment 4: Build a FIFO
Your first from-scratch build: a synchronous FIFO with a self-checking testbench that plays it against a golden queue model. No hints pre-loaded in the code this time — just the port list, the spec, and the judge. This is where Assignment 3's waveform-reading skill gets put to real use if something doesn't work on the first try.

### Assignment 5: Universal Verification Methodology (UVM)
This stage introduces the UVM architecture through a series of presentation slides.
*Recommendation:* The provided slides outline the high-level concepts and are not highly detailed. To truly grasp the methodology, it is strongly recommended that you dive deeper, search for UVM tutorials online, and supplement your learning with external documentation.

### Stage 6: Practical Verification
This is the final and most comprehensive stage, where you will apply what you have learned to verify an actual block. Please follow this specific order of operations (note that the first three reference files are located in the `documents` folder:

1. Begin by learning about the block by reading the file named **מקלט**.
2. Carefully study the attribute list (AL).
3. Move on to reviewing the Verification Plan (VP) to understand the coverage and testing goals.
4. Finally, open the `student_guide.md` file in your current directory to continue and execute your hands-on training.
