# Enics UVM Full Training

<div align="center">

[![SystemVerilog](https://img.shields.io/badge/SystemVerilog-IEEE%201800-005C8A?style=flat-square&logo=cpu)](https://en.wikipedia.org/wiki/SystemVerilog)
[![UVM](https://img.shields.io/badge/UVM-Accellera%201.2-4CAF50?style=flat-square&logo=testcafe)](https://www.accellera.org/downloads/standards/uvm)
[![Linux Ready](https://img.shields.io/badge/Environment-Linux-E34F26?style=flat-square&logo=linux&logoColor=white)](Linux_Basics_Cheat_Sheet_UVM.pdf)
[![Self-Paced](https://img.shields.io/badge/Learning-Self--Paced-9C27B0?style=flat-square)](introduction/README.md)

</div>

---

## 📖 Overview

Welcome to the **Enics UVM Full Training** repository! This is a comprehensive, self-paced training program designed to take you from SystemVerilog fundamentals all the way to constructing a complete, production-grade UVM verification environment.

Rather than teaching verification through abstract toy examples, you will build a testbench for a real, non-trivial Design Under Test (DUT): **`dma_rx_top`**, the receive front-end of a DMA controller. You will write UVM components, define stimulus sequences, build a reference model, implement functional coverage, and run simulation regression tasks directly against real RTL.

---

## 🎯 Target Audience & Outcomes

*   **Who this is for:** 
    *   Engineers ramping up on functional verification.
    *   Developers transitioning from basic SystemVerilog to UVM.
    *   Anyone who wants hands-on experience building structured testbenches from scratch.
*   **What you will achieve:**
    *   **SystemVerilog Mastery:** Deep comfort reading/writing SystemVerilog and debugging with waveforms.
    *   **UVM Architecture:** A solid understanding of core UVM building blocks including agents, sequences, sequencers, drivers, monitors, scoreboards, coverage collectors, and reference models.
    *   **Practical Experience:** Confidence working in a real-world Linux verification environment.

---

## 🗂️ Repository Structure

The training program is structured into two main phases. We recommend following them in order:

| Section | Target Directory | Description |
| :--- | :--- | :--- |
| **Stage 1: SV Fundamentals** | [📁 `introduction/`](introduction/) | **Assignments 1–4:** SystemVerilog basics, hands-on coding exercises, waveform-reading riddles, and constructing a synchronous FIFO testbench from scratch without UVM. |
| **Stage 2: UVM Verification** | [📁 `UVM_Training/`](UVM_Training/) | **UVM Architecture & Practice:** Introductory slides, followed by a complete UVM environment for the `dma_rx_top` DUT where you implement the reference model, coverage, and stimulus. |

> [!TIP]
> **New to Linux Command Line?**
> We've included a [Linux Basics Cheat Sheet](Linux_Basics_Cheat_Sheet_UVM.pdf) in the root of the repository. Skim this document first if you need a quick refresher on terminal commands.

---

## 🚀 Getting Started

Depending on your background, choose your entry point:

*   **New to SystemVerilog?** Start at [introduction/README.md](introduction/README.md).
*   **Already know SystemVerilog?** Jump straight to [UVM_Training/README.md](UVM_Training/README.md).

---

## 🛠️ Cloud Workspace Setup

Follow these steps to clone this repository and open it in your cloud development environment:

1.  **Enter the Workspace Environment:**
    ```bash
    tsmc65
    ```

2.  **Clone the Repository:**
    ```bash
    git clone https://github.com/oren894/Enics-UVM-full-training.git
    ```

3.  **Navigate into the Project Directory:**
    ```bash
    cd Enics-UVM-full-training
    ```

4.  **Launch VS Code:**
    ```bash
    code .
    ```

> [!IMPORTANT]
> If any of these commands or tools feel unfamiliar, please refer to the [Linux Basics Cheat Sheet](Linux_Basics_Cheat_Sheet_UVM.pdf) before moving forward.
