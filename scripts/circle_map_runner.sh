#!/bin/bash
#
#SBATCH --job-name=circle_map
#SBATCH --time=3-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=120G


START_TIME=$(date +%s)
SCRIPT_DIR=$1
RESULTS_DIR=$2
REF_FASTA=$3
BAM_SUFFIX=$4
SAMPLES_STRING=$5
FINAL_SNPS=$6
FINAL_INDELS=$7

SAMPLE_ARRAY=( $(echo $SAMPLES_STRING | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}

srun --time=3-00:00:00 --mem=64G --partition=cgawad --pty bash ${SCRIPT_DIR}/circle_map.sh $RESULTS_DIR $REF_FASTA $BAM_SUFFIX $SAMPLE $SCRIPT_DIR $FINAL_SNPS $FINAL_INDELS
