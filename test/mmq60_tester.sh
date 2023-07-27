#!/bin/bash
#
#SBATCH --job-name=sentieon_svc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

RESULTS_DIR="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results"
SAMPLE="ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25"
NORMAL_SAMPLE_NAME="ANEU01_Bulk_WB_WES_Capt09_S26"

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
REF_FASTA="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta"
NUMBER_THREADS=16
TUMOR_REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
TUMOR_RECAL_TABLE="${SAMPLE}_recal_data.table"
NORMAL_REALIGN_BAM="${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
NORMAL_RECAL_TABLE="${NORMAL_SAMPLE_NAME}_recal_data.table"
OUT_TN_VCF="${RESULTS_DIR}/${SAMPLE}_mmq60_variant.vcf"
dbSNP="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
PANEL_OF_NORMAL="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/1000g_pon.hg38.vcf.gz"

sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM} -q ${RESULTS_DIR}"/"${TUMOR_RECAL_TABLE} \
   -i ${RESULTS_DIR}"/"${NORMAL_REALIGN_BAM} -q ${RESULTS_DIR}"/"${NORMAL_RECAL_TABLE} \
   --algo TNscope --tumor_sample ${SAMPLE} \
      --normal_sample ${NORMAL_SAMPLE_NAME} \
      --dbsnp $dbSNP \
      --pon $PANEL_OF_NORMAL \
      --min_base_qual 60 \
        $OUT_TN_VCF

