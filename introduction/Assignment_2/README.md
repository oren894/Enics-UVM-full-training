# Complete Guide: Running SystemVerilog Simulations

Welcome to the standard workflow for compiling and simulating SystemVerilog/Verilog designs. This guide covers the best practices for keeping your workspace clean and running simulations efficiently.

**Looking for the actual assignment tasks and material?** See [MATERIAL.md](MATERIAL.md) — this file is only about the simulator workflow.

---

## 1. Initializing the Environment

Before starting, you must load the proper toolchains and open your development environment. Open your terminal and run:

```bash
tsmc65
code .
```

* **`tsmc65`**: Loads the necessary environment variables, paths, and licenses required to run the simulation tools.
* **`code .`**: Opens Visual Studio Code in your current directory, allowing you to edit your RTL and Testbench files comfortably.

---

## 2. Managing Files with `list.f`

Instead of manually typing every single Verilog file into the terminal during compilation, you should always use a file compilation list. Create a text file named `list.f` in your main project directory.

**Why use a `list.f`?**
As your design grows, you will have multiple modules and testbenches. The `list.f` file acts as a central index. It keeps your compilation command short and makes it incredibly easy to add or remove files from the simulation.

*Example of `list.f` content:*
```text
// RTL Modules
my_design.sv
alu.sv

// Testbench
top_tb.sv
```

---

## 3. The `runspace` Directory (Crucial Step)

**Never run simulations directly in your source code directory.** Simulators generate a massive amount of output files (history, logs, and databases). To protect your source code and keep your repository clean, always execute simulations inside a dedicated sandbox folder.

Create a directory called `runspace` and navigate into it:

```bash
mkdir runspace
cd runspace
```

**Why use a `runspace`?**
It completely isolates the simulation "trash" from your actual source files. If you want to perform a clean compilation or if something gets stuck, you can simply delete the `runspace` directory and start fresh without accidentally deleting your hard work.

---

## 4. Execution with `xrun`

The modern simulation executable is **`xrun`** (do not use the older `irun` command). 

Since you are currently inside the `runspace` directory, you need to point `xrun` to the `list.f` file located one level up in the parent directory.

**To run the simulation in the terminal (CLI mode):**
```bash
xrun -f ../list.f
```

**To run the simulation with the GUI and signal visibility (for waveform debugging):**
```bash
xrun -gui -debug -f ../list.f
```