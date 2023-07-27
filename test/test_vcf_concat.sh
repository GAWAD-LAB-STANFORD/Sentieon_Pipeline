#!/bin/bash
#
#SBATCH --job-name=sentieon_joint_genotyping
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

RESULTS_DIR="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-22_EEG_project_Results"
#VCF_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results"
SAMPLE_PREFIX="EEG05"

cd ${RESULTS_DIR}
echo "about to make vcf_list"
VCF_LIST=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.vcf" ! -name "*germline*" ! -name "*PBMC*" ! -name "*temp*" ! -name "*merged*" ! -name "*multianno*") )

#GVCF_LIST=( $(find ${VCF_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*_variant.vcf.gz") )
ml purge
ml biology bcftools
ml biology samtools
for vcf in ${VCF_LIST[@]}; do
	bgzip $vcf
	bcftools index "${vcf}.gz"
	tabix "${vcf}.gz"

done

echo "exited for loop"

#GVCF_LIST=( $(find ${VCF_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*_variant.vcf.gz") )

VCF_LIST=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.vcf.gz" -name "${SAMPLE_PREFIX}*variant*" ! -name "*PBMC*") )

bcftools merge --force-samples -o "${RESULTS_DIR}/${SAMPLE_PREFIX}_svc_merged.vcf" \
	${VCF_LIST[@]}


