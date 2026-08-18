#!/usr/bin/env python3
"""
Parallel UVM Regression Runner
- Uses qsub (fire-and-forget) + qstat job-ID tracking, exactly like rxscript.py
- All jobs run from RUNSPACE_DIR so relative paths in list.f (../sv, ../rtl) resolve correctly
- Each job uses -xmlibdirname ./xcelium_run_N for isolated work dirs (no lock contention)
- SUCCESS = 'S U C C E S S' in last 200 lines of log; anything else = FAILED
"""

import subprocess
import time
import re
import os
import shutil
import signal
import sys
import argparse
import random

# ===========================================================
# CONFIGURATION
# ===========================================================
NUM_RUNS     = 10        # Total regression runs
MAX_PARALLEL = 20          # Max simultaneous grid jobs (= licenses)
DELAY_TIME   = 10          # Seconds between qstat poll cycles

LOGDIR      = "logs"
MAIN_LOG    = f"{LOGDIR}/main.log"
SUMMARY_LOG = f"{LOGDIR}/summary.log"

# Absolute path to list.f – derived from this script's location so it always resolves correctly
FILELIST = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../list.f"))

# Flags in the exact same order as run_regression.sh:
#   xrun -uvm -f <list> +define+UVM_PACKER_MAX_BYTES=10000 -coverage all -covoverwrite
#        -xmlibdirname <dir> -covtest <name> -svseed <seed>
XRUN_FLAGS_BEFORE_F = "-uvm"
XRUN_FLAGS_AFTER_F  = "+define+UVM_PACKER_MAX_BYTES=10000 -coverage all -covoverwrite"

IMC_TOOL       = "imc"
COV_WORK_DIR   = "cov_work/scope"
MERGE_TCL      = f"{COV_WORK_DIR}/merge.tcl"
MERGE_OUT_NAME = "merged_results"

SUCCESS_PAT  = r"S U C C E S S"

# SCRIPT_DIR is the directory where this script lives (e.g. scripts/)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Force RUNSPACE_DIR to be the runspace directory sibling to scripts/
RUNSPACE_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../runspace"))
# Ensure all operations occur inside runspace
os.chdir(RUNSPACE_DIR)

# ===========================================================
# GLOBALS
# ===========================================================
active_jobs       = []   # list of current job dicts
submitted_job_ids = []   # every job_id submitted (for qdel on abort)
completed_jobs    = []   # list of dicts {"run_id": X, "seed": Y, "status": Z}

success_count = 0
failed_count  = 0
error_count   = 0

start_time = time.time()
args = None  # filled in __main__


# ===========================================================
# UTILITY
# ===========================================================
def run_cmd(cmd):
    """Run a shell command and return combined stdout+stderr."""
    result = subprocess.run(cmd, shell=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return result.stdout


def log_and_print(msg):
    print(msg)
    with open(MAIN_LOG, "a") as f:
        f.write(msg + "\n")


def write_summary(label="CURRENT RUN SUMMARY"):
    with open(SUMMARY_LOG, "w") as sf:
        sf.write("=" * 50 + "\n")
        sf.write(f"{label}\n")
        sf.write("=" * 50 + "\n")
        sf.write(f"SUCCESS : {success_count}\n")
        sf.write(f"FAILED  : {failed_count}\n")
        sf.write(f"ERRORS  : {error_count}\n")
        sf.write(f"TOTAL   : {success_count + failed_count + error_count}\n")
        
        elapsed = time.time() - start_time
        hours, rem = divmod(elapsed, 3600)
        minutes, seconds = divmod(rem, 60)
        sf.write(f"TIME    : {int(hours):02}:{int(minutes):02}:{int(seconds):02}\n")
        
        sf.write("=" * 50 + "\n")
        
        if completed_jobs:
            sf.write("RUN DETAILS:\n")
            sf.write(f"{'RUN':<5} | {'SEED':<12} | {'STATUS'}\n")
            sf.write("-" * 50 + "\n")
            # Sort by run_id numerically before printing
            for job in sorted(completed_jobs, key=lambda x: x['run_id']):
                sf.write(f"{job['run_id']:<5} | {job['seed']:<12} | {job['status']}\n")
            sf.write("=" * 50 + "\n")


def kill_all_jobs():
    if not submitted_job_ids:
        return
    print("[WARNING] Killing all submitted grid jobs ...")
    for jid in submitted_job_ids:
        run_cmd(f"qdel {jid} 2>/dev/null")
        print(f"  qdel {jid}")


def abort_with_summary(reason="MANUALLY ABORTED BY USER"):
    print(f"\n{'='*50}\n{reason}\n{'='*50}")
    print(f"SUCCESS : {success_count}")
    print(f"FAILED  : {failed_count}")
    print(f"ERRORS  : {error_count}")
    print(f"TOTAL   : {success_count + failed_count + error_count}")
    print(f"{'='*50}\n")
    write_summary(label=reason)
    kill_all_jobs()
    sys.exit(1)


def handle_exit(signum=None, frame=None):
    abort_with_summary("MANUALLY ABORTED BY USER (Ctrl+C)")


signal.signal(signal.SIGINT,  handle_exit)
signal.signal(signal.SIGTERM, handle_exit)


# ===========================================================
# JOB SUBMISSION  –  qsub + qstat (same pattern as rxscript.py)
# ===========================================================
def job_finished(job_id):
    """Return True when qstat no longer knows this job ID."""
    out = run_cmd(f"qstat -j {job_id} 2>&1")
    return "Following jobs do not exist" in out


def launch_job(run_id, seed):
    """
    Submit one xrun job to the grid via qsub.
    qsub returns immediately with 'Your job XXXXX' – track completion via qstat.
    All jobs cd to RUNSPACE_DIR so relative paths in list.f resolve correctly.
    Each run uses its own -xmlibdirname to avoid shared xcelium.d lock contention.
    """
    log_file    = os.path.join(os.path.abspath(LOGDIR), f"run_{run_id}.log")
    script_path = os.path.join(os.path.abspath(LOGDIR), f".job_{run_id}.sh")

    raw_filelist = args.filelist if (args and args.filelist) else FILELIST
    filelist  = os.path.abspath(raw_filelist)
    extra     = (args.xrun_flags if (args and args.xrun_flags) else "")
    real_xrun = shutil.which("xrun") or "xrun"

    xcelium_dir = f"./xcelium_run_{run_id}"   # private work dir per run

    xrun_cmd = (
        f"{real_xrun} "
        f"{XRUN_FLAGS_BEFORE_F} "
        f"-f {filelist} "
        f"{XRUN_FLAGS_AFTER_F} "
        f"-xmlibdirname {xcelium_dir} "
        f"-covtest regression_run_{run_id} "
        f"-svseed {seed}"
        + (f" {extra}" if extra else "")
    )

    # Self-contained shell script for qsub
    with open(script_path, "w") as sf:
        sf.write("#!/bin/bash\n")
        sf.write(f"cd {RUNSPACE_DIR}\n")  # relative paths in list.f resolve from here
        sf.write(f"{xrun_cmd}\n")
    os.chmod(script_path, 0o755)

    # Submit – output captured to log_file via -o/-e/-j y
    qsub_cmd = (
        f"qsub "
        f"-pe mpi 1 "
        f"-l mem_free=5G "
        f"-V -cwd "
        f"-N xrun "
        f"-q all.q "
        f"-o {log_file} "
        f"-e {log_file} "
        f"-j y "
        f"{script_path}"
    )

    output = run_cmd(qsub_cmd)   # returns immediately

    # Parse "Your job XXXXX"  (same as rxscript.py)
    match = re.search(r"Your job\s+(\d+)", output)
    if not match:
        log_and_print(
            f"  [ERROR] run={run_id}: could not parse job ID from qsub output:\n"
            f"  {output.strip()}"
        )
        return None

    job_id = match.group(1)
    submitted_job_ids.append(job_id)

    job = {
        "run_id":   run_id,
        "seed":     seed,
        "job_id":   job_id,
        "log_file": log_file,
    }
    active_jobs.append(job)
    print(f"  [SUBMITTED] run={run_id:>3}  seed={seed}  job={job_id}")
    return job


# ===========================================================
# RESULT ANALYSIS
# ===========================================================
def analyze_log(log_file):
    """
    SUCCESS  = 'S U C C E S S' in last 200 lines (same check as original .sh)
    FAILED   = anything else (explicit fail OR silent crash)
    ERROR    = log file missing entirely
    """
    if not os.path.exists(log_file):
        return "error", "MISSING LOG FILE"
    with open(log_file, "r", errors="replace") as lf:
        content = lf.read()
    tail = "\n".join(content.splitlines()[-200:])
    if re.search(SUCCESS_PAT, tail):
        return "success", content
    return "failed", content


# ===========================================================
# COVERAGE MERGE
# ===========================================================
def generate_and_run_merge_tcl(completed_run_ids):
    """
    Write cov_work/scope/merge.tcl and run imc -batch on it.
    Format:  merge ./regression_run_1 ./regression_run_2 ... -out merged_results -metrics all
    """
    os.makedirs(COV_WORK_DIR, exist_ok=True)

    run_entries = " ".join(f"./regression_run_{rid}" for rid in sorted(completed_run_ids))
    tcl_content = f"# run this commend in the runspace/cov_work/scope in the vnc viewer \"imc -i -exec merge.tcl\"\n"
    tcl_content += f"merge {run_entries} -out {MERGE_OUT_NAME} -metrics all\n"

    with open(MERGE_TCL, "w") as tf:
        tf.write(tcl_content)
    log_and_print(f"  [MERGE] Written : {MERGE_TCL}")
    log_and_print(f"  [MERGE] Content : {tcl_content.strip()}")

    log_and_print(f"  [MERGE] Merge execution skipped by request.")
    log_and_print(f"  [MERGE] run this commend in the runspace/cov_work/scope in the vnc viewer \"imc -i -exec merge.tcl\"")


# ===========================================================
# MAIN
# ===========================================================
def main():
    global success_count, failed_count, error_count

    # ── Clean old data (preserve .gitkeep files) ────────────
    def _clean_dir_contents(path):
        """Remove everything inside *path* except .gitkeep files. Creates the dir if missing."""
        os.makedirs(path, exist_ok=True)
        for entry in os.listdir(path):
            if entry == ".gitkeep":
                continue
            full = os.path.join(path, entry)
            if os.path.isdir(full):
                shutil.rmtree(full, ignore_errors=True)
            else:
                try:
                    os.remove(full)
                except OSError:
                    pass

    # Clean logs/ and cov_work/scope/ contents, keeping structure + .gitkeep
    for target_dir in (LOGDIR, COV_WORK_DIR):
        print(f"[CLEAN] Clearing {target_dir}/ ...")
        _clean_dir_contents(target_dir)

    # Clean stale per-run artefacts from runspace root
    RUNSPACE_STALE_PREFIXES = ("xcelium_run_",)
    RUNSPACE_STALE_NAMES    = ("xrun.log", "xrun.history", "xcelium.d",
                               "simvision.e", "simvision.o")
    for entry in os.listdir(RUNSPACE_DIR):
        if entry == ".gitkeep":
            continue
        full = os.path.join(RUNSPACE_DIR, entry)
        is_stale = (
            any(entry.startswith(p) for p in RUNSPACE_STALE_PREFIXES)
            or any(entry.startswith(n) for n in RUNSPACE_STALE_NAMES)
        )
        if is_stale:
            print(f"[CLEAN] Removing {entry} ...")
            if os.path.isdir(full):
                shutil.rmtree(full, ignore_errors=True)
            else:
                try:
                    os.remove(full)
                except OSError:
                    pass

    # Initialise fresh log files
    open(MAIN_LOG, "w").close()
    with open(SUMMARY_LOG, "w") as sf:
        sf.write("No runs completed yet.\n")


    log_and_print("=" * 60)
    log_and_print(f"Parallel UVM Regression  –  {NUM_RUNS} runs  –  {MAX_PARALLEL} parallel  (qsub)")
    log_and_print("=" * 60)

    # ── Assign random seeds ─────────────────────────────────
    run_seeds = {i: random.randint(1, 2**31 - 1) for i in range(1, NUM_RUNS + 1)}

    next_run_id = 1
    failed_runs = []
    successful_runs = []

    # ── Submit initial batch ────────────────────────────────
    log_and_print(f"\nSubmitting initial batch of {min(MAX_PARALLEL, NUM_RUNS)} jobs ...")
    while next_run_id <= NUM_RUNS and len(active_jobs) < MAX_PARALLEL:
        launch_job(next_run_id, run_seeds[next_run_id])
        next_run_id += 1

    log_and_print(f"\nMonitoring {len(active_jobs)} active jobs via qstat ...\n")

    # ── Sliding-window poll loop ────────────────────────────
    while active_jobs:
        for job in active_jobs[:]:            # iterate a snapshot
            if not job_finished(job["job_id"]):
                continue                      # still on the grid

            run_id   = job["run_id"]
            seed     = job["seed"]
            job_id   = job["job_id"]
            log_file = job["log_file"]

            status, content = analyze_log(log_file)

            if status == "success":
                success_count += 1
                result_str = "SUCCESS ✓"
                successful_runs.append(run_id)
                
                # Automatically and quietly update merge.tcl after every successful run
                os.makedirs(COV_WORK_DIR, exist_ok=True)
                run_entries = " ".join(f"./regression_run_{rid}" for rid in sorted(successful_runs))
                with open(MERGE_TCL, "w") as tf:
                    tf.write(f"# run this commend in the runspace/cov_work/scope in the vnc viewer \"imc -i -exec merge.tcl\"\n")
                    tf.write(f"merge {run_entries} -out {MERGE_OUT_NAME} -metrics all\n")
            elif status == "failed":
                failed_count += 1
                result_str = "FAILED  ✗"
                failed_runs.append((run_id, seed, content))
                if failed_count > 20:
                    abort_with_summary("ABORTED – TOO MANY FAILURES (>20)")
            else:
                error_count += 1
                result_str = "ERROR (no log)"
                failed_runs.append((run_id, seed, content))

            log_and_print(
                f"  [DONE] run={run_id:>3}  seed={seed}  job={job_id}"
                f"  --> {result_str}"
                f"  (ok={success_count} fail={failed_count} err={error_count})"
            )
            
            # Save the result to the list and rewrite summary
            completed_jobs.append({
                "run_id": run_id,
                "seed": seed,
                "status": result_str
            })
            write_summary()
            active_jobs.remove(job)

            # Fill the freed slot immediately
            if next_run_id <= NUM_RUNS:
                launch_job(next_run_id, run_seeds[next_run_id])
                next_run_id += 1

            break   # restart loop after modifying active_jobs

        time.sleep(DELAY_TIME)

    # ── Coverage merge ──────────────────────────────────────
    log_and_print(f"\n{'='*60}")
    log_and_print("Generating merge.tcl and merging coverage ...")
    log_and_print(f"{'='*60}")
    completed_ids = [i for i in range(1, next_run_id) if i not in {r[0] for r in failed_runs}]
    if completed_ids:
        generate_and_run_merge_tcl(completed_ids)
    else:
        log_and_print("  [MERGE] No successful runs to merge.")

    # ── Dump failed run logs ────────────────────────────────
    if failed_runs:
        with open(MAIN_LOG, "a") as f:
            f.write(f"\n{'='*60}\nFAILED / ERROR RUNS\n{'='*60}\n")
            for rid, seed, content in failed_runs:
                f.write(f"\n{'='*60}\nRUN {rid}  seed={seed}\n{'='*60}\n")
                f.write(content + "\n")

    # ── Final summary ───────────────────────────────────────
    elapsed = time.time() - start_time
    hours, rem = divmod(elapsed, 3600)
    minutes, seconds = divmod(rem, 60)
    time_str = f"{int(hours):02}:{int(minutes):02}:{int(seconds):02}"

    summary = (
        f"\n{'='*50}\n"
        f"FINAL SUMMARY – ALL RUNS COMPLETED\n"
        f"{'='*50}\n"
        f"  Total   : {NUM_RUNS}\n"
        f"  SUCCESS : {success_count}\n"
        f"  FAILED  : {failed_count}\n"
        f"  ERRORS  : {error_count}\n"
        f"  Time    : {time_str}\n"
        f"{'='*50}\n"
        f"Logs in  : {LOGDIR}/\n"
        f"Coverage : {COV_WORK_DIR}/{MERGE_OUT_NAME}/   (imc -gui)\n"
        f"{'='*50}\n"
    )
    log_and_print(summary)
    write_summary(label="FINAL SUMMARY")
    print("[DONE] Regression finished.")


# ===========================================================
# ENTRY POINT
# ===========================================================
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parallel UVM regression runner – qsub, up to 20 licenses"
    )
    parser.add_argument("--xrun-flags", "-x", type=str, default="",
                        help="Extra xrun flags for every run (e.g. '+define+DEBUG')")
    parser.add_argument("--filelist", "-f", type=str, default=None,
                        help=f"Override filelist (default: {FILELIST})")
    parser.add_argument("--runs", "-n", type=int, default=NUM_RUNS,
                        help=f"Total number of runs (default: {NUM_RUNS})")
    parser.add_argument("--parallel", "-p", type=int, default=MAX_PARALLEL,
                        help=f"Max parallel jobs (default: {MAX_PARALLEL})")
    args = parser.parse_args()

    NUM_RUNS     = args.runs
    MAX_PARALLEL = args.parallel

    try:
        main()
    except KeyboardInterrupt:
        handle_exit()
