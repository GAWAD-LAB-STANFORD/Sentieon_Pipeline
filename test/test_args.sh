#!/bin/bash
#
#SBATCH --job-name=Scan2_test
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=3-00:00:00
#SBATCH --partition=cgawad

RESULTS_DIR="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-22_EEG_project_Results"
SAMPLE_PREFIX="EEG05"

cd ${RESULTS_DIR}

SC_BAMS=$(find $RESULTS_DIR -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam")
#SC_BAMS=echo $("${SC_BAMS[@]}" | sed 's/[^ ]* */--sc-bam &/g')

echo "sc-bams is ${SC_BAMS}"

#SC_BAMS=$( "${SC_BAMS[@]/#/--sc-bam }" )
FINAL=""

for i in ${SC_BAMS[@]}; do
	echo "arg is ${i}"
	TEMP=${i/#/--sc-bam }
	FINAL="${FINAL} ${TEMP}"
done


echo "FINAL is $FINAL"
