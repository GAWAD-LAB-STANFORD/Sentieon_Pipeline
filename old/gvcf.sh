#!/bin/bash
#
#SBATCH --job-name=sentieon_joint_genotyping
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

RESULTS_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"

VCF_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results"
SAMPLE_PREFIX="EEG05"

VCF_LIST=( $(find ${VCF_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.vcf" -name "*multianno*") )

for vcf in ${VCF_LIST[@]}; do
	echo $vcf
done

ml purge
ml biology bcftools

bcftools concat -o "${RESULTS_DIR}/${SAMPLE_PREFIX}_merged.vcf" ${VCF_LIST[@]}


