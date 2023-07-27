#!/bin/bash
#
#SBATCH --job-name=test_vcf_annotate
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=3-00:00:00
#SBATCH --partition=cgawad

ml gsl/2.3
ml R/4.0.2 java perl biology gatk bedtools samtools
ml biology bcftools

export R_LIBS="/home/groups/cgawad/R_libs"

RESULTS_DIR="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results"


GATK_VCF="${RESULTS_DIR}/ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25_mmq60_variant.vcf"
SCAN2_REF_VCF="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/Scan2_Reference/Scan2_Results_/gatk/hc_raw.mmq60.vcf"

#need to bgzip the vcf files first, also should make a scan2_ref_vcf for all regions not just chr 22
#may or may not need to uncompress files after annotating

bgzip $GATK_VCF
tabix ${GATK_VCF}.gz
bgzip $SCAN2_REF_VCF
tabix ${SCAN2_REF_VCF}.gz

GATK_VCF="${RESULTS_DIR}/ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25_mmq60_variant.vcf.gz"
SCAN2_REF_VCF="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/Scan2_Reference/Scan2_Results_/gatk/hc_raw.mmq60.vcf.gz"

# overwrite existing TAG annotations
bcftools annotate -a "${SCAN2_REF_VCF}" -c ID,QUAL,FORMAT "${GATK_VCF}"

gunzip $GATK_VCF
gunzip $SCAN2_REF_VCF


