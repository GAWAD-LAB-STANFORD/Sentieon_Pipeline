#!/bin/bash
#
#SBATCH --job-name=sentieon_joint_genotyping
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

#SAMPLE_ARRAY=( $(echo ${1} | sed 's/:/ /g') )
#SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))

RESULTS_DIR=$1
REFERENCE_DIR=$2
REF_FASTA=$3
NUMBER_THREADS=$4
PROJECT=$5
TARGETS_BED=$6
echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${RESULTS_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${RESULTS_DIR}/std_err_out_files/""%A_variant_call_2%x.err"
SAMPLE=${SAMPLE%".deduped_sorted.bam"}
BAM="${SAMPLE}.bam"
SORTED_BAM="${SAMPLE}.sorted.bam"
DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
TUMOR_REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
RECALIBRATED_BAM="${SAMPLE}.recalibrated_realigned_deduped_sorted.bam"
TUMOR_RECAL_TABLE="${SAMPLE}_recal_data.table"
NORMAL_REALIGN_BAM="${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
NORMAL_RECAL_TABLE="${NORMAL_SAMPLE_NAME}_recal_data.table"
SOMATIC_VCF="${SAMPLE}_somatic.vcf"
TMP_OUT_TN_VCF=${RESULTS_DIR}"/${SAMPLE}_temp.vcf"
dbSNP="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
#Trying out joint genotyping, --emit_mode gvcf may cause problems

cd ${RESULTS_DIR}
JOINT_VCF="${PROJECT}_joint_germline_merged.vcf"
sentieon driver --interval $TARGETS_BED -r $REF_FASTA --algo GVCFtyper ${JOINT_VCF} ${SAMPLE_PREFIX}*.g.vcf

echo "### Variant calling ### - END: $(date)"


if [ ! -f $OUT_TN_VCF ]; then
    echo "No $VARIANT_VCF found. Exiting with code 1"
    exit 1
fi

ml purge
ml biology bcftools
ml biology samtools

bcftools index ${JOINT_VCF}
bgzip -f ${JOINT_VCF}
tabix "${JOINT_VCF}.gz"
