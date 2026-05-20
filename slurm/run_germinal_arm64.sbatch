#!/bin/bash
#SBATCH --job-name=germinal_arm64
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --partition=workq
#SBATCH --gpus=1
#SBATCH --output=jobs/%x-%j.out
#SBATCH --error=jobs/%x-%j.err

# ---------------------------------------------------------------------------
# Germinal ARM64 Slurm job — Isambard-AI Phase 2 (NVIDIA GH200)
#
# Usage:
#   sbatch run_germinal_arm64.sbatch
#
# Override any Hydra config key on the command line, e.g.:
#   sbatch run_germinal_arm64.sbatch --export=ALL,EXTRA_ARGS="max_trajectories=3"
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Paths (host filesystem) ------------------------------------------------
GERMINAL_SIF=/projects/u6jt/containers/germinal-arm64.sif
AF3_SIF=/projects/u6jt/containers/alphafold3-arm64.sif
AF2_PARAMS=/projects/u6jt/germinal_params
AF3_PARAMS=/projects/u6jt/af3_params
AF3_DB=/projects/u6jt/af3_databases
WORKDIR=$PWD   # run from germinal repo root

# --- Sanity checks ----------------------------------------------------------
for f in "$GERMINAL_SIF" "$AF3_SIF" "$AF2_PARAMS" "$AF3_PARAMS" "$AF3_DB"; do
    [[ -e "$f" ]] || { echo "ERROR: missing $f"; exit 1; }
done
mkdir -p "$WORKDIR/jobs" "$WORKDIR/results"

echo "=============================="
echo "Job:        $SLURM_JOB_ID"
echo "Node:       $SLURM_NODELIST"
echo "Started:    $(date)"
echo "=============================="

# ---------------------------------------------------------------------------
# Run germinal inside the ARM64 Apptainer container.
#
# Bind mounts:
#   AF2-Multimer weights → /workspace/params        (hallucination)
#   AF3 model weights   → /workspace/af3_params     (cofolding)
#   AF3 databases       → /workspace/af3_databases  (cofolding MSA)
#   AF3 SIF             → /workspace/af3.sif        (germinal calls apptainer)
#   pdbs/               → /workspace/pdbs           (target PDB files)
#   results/            → /workspace/results        (pipeline output)
#
# Nested Apptainer: germinal calls the AF3 container via subprocess.
# The host apptainer binary is injected so it is accessible inside the container.
# ---------------------------------------------------------------------------

APPTAINER_BIN=$(which apptainer)

apptainer exec \
    --nv \
    --bind "${AF2_PARAMS}:/workspace/params" \
    --bind "${AF3_PARAMS}:/workspace/af3_params" \
    --bind "${AF3_DB}:/workspace/af3_databases" \
    --bind "${AF3_SIF}:/workspace/af3.sif" \
    --bind "${APPTAINER_BIN}:/usr/local/bin/apptainer" \
    --bind "${WORKDIR}/pdbs:/workspace/pdbs" \
    --bind "${WORKDIR}/results:/workspace/results" \
    "${GERMINAL_SIF}" \
    python run_germinal.py \
        run=vhh \
        target=pdl1 \
        structure_model=af3 \
        af3_sif_path=/workspace/af3.sif \
        af3_model_dir=/workspace/af3_params \
        af3_db_dir=/workspace/af3_databases \
        af_params_dir=/workspace/params \
        experiment_name=pdl1_vhh_arm64_test \
        max_trajectories=3 \
        ${EXTRA_ARGS:-}

echo "=============================="
echo "Finished:   $(date)"
echo "=============================="
