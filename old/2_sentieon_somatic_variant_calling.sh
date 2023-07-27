#!/bin/bash
#
#SBATCH --job-name=sentieon_svc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad


START_TIME=$(date +%s)
RESULTS_DIR=$1
SKIP_TRIMMOMATIC=2
SCRIPT_DIR=$3
TOOLS_DIR=$4
R1_SUFFIX=$5
R2_SUFFIX=$6
REF_FASTA=$7
NUMBER_THREADS=$8
SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )
FASTQ_DIR=${10}
dbSNP=${11}
NORMAL_SAMPLE_NAME=${12}
BAM_DIR=${13}

if [ -z $BAM_DIR ]; then
    RESULTS_DIR=${BAM_DIR}
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}

echo "TASK_ID is $SLURM_ARRAY_TASK_ID"
echo "SAMPLE about to be worked on is $SAMPLE"

BAM="${SAMPLE}.bam"
SORTED_BAM="${SAMPLE}.sorted.bam"
DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
TUMOR_REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
RECALIBRATED_BAM="${SAMPLE}.recalibrated_realigned_deduped_sorted.bam"
VARIANT_VCF="${SAMPLE}.vcf"
TUMOR_RECAL_TABLE="${SAMPLE}_recal_data.table"
NORMAL_REALIGN_BAM="${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
NORMAL_RECAL_TABLE="${NORMAL_SAMPLE_NAME}._recal_data.table"
SOMATIC_VCF="${SAMPLE}_somatic.vcf"
TMP_OUT_TN_VCF=${RESULTS_DIR}"/${SAMPLE}_temp.vcf"
OUT_TN_VCF=${RESULTS_DIR}"/${SAMPLE}_variant.vcf"

echo "### Variant calling ### - START: $(date)"


sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM} -q ${RESULTS_DIR}"/"${TUMOR_RECAL_DATA} \
   -i ${RESULTS_DIR}"/"${NORMAL_REALIGN_BAM} -q ${RESULTS_DIR}"/"${NORMAL_RECAL_DATA} \
   --algo TNhaplotyper2 --tumor_sample $SAMPLE_NAME \
      --normal_sample $NORMAL_SAMPLE_NAME \
      $TMP_OUT_TN_VCF \

sentieon driver -r $REF_FASTA \
   --algo TNfilter --tumor_sample $SAMPLE_NAME \
   --normal_sample $NORMAL_SAMPLE_NAME \
   -v $TMP_OUT_TN_VCF \
   $OUT_TN_VCF
echo "### Variant calling ### - END: $(date)"


echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"

if [ ! -f $OUT_TN_VCF ]; then
    echo "No $VARIANT_VCF found. Exiting with code 1"
    exit 1
fi



