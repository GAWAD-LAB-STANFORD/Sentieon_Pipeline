#!/bin/bash
#
#SBATCH --job-name=sentieon_svc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

#This script supplies samples to test_sentieon_somatic_variant_calling.sh to do somatic variant call

NUMBER_THREADS=4
SAMPLE_PREFIX="EEG05"
NORMAL_SAMPLE_NAME="EEG05_Bulk_PBMC_WES_Capt10_S58"
RESULTS_DIR="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-22_EEG_project_Results"
SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.deduped_sorted.bam" ! -name "${NORMAL_SAMPLE_NAME}*" -exec basename {} \;) ) 
STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files/"

for SAMPLE in ${SAMPLE_ARRAY[@]}; do
	sbatch --error ${STD_ERR_OUT_DIR}/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out --cpus-per-task 4 /oak/stanford/groups/cgawad/Scripts/Sentieon_Pipeline_Under_Constr/test_sentieon_somatic_variant_calling.sh $SAMPLE
done
