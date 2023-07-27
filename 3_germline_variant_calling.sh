#!/bin/bash

#SBATCH --job-name=germline_calling
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=300G
#SBATCH --cpus-per-task=8

set -x

RESULTS_DIR=$1
REFERENCE_DIR=$2
REF_FASTA=$3
NUMBER_THREADS=$4
SAMPLE_STRING=$5
TARGETS_BED=$6
SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}

REALIGNED_BAM="${SAMPLE}"
SAMPLE_NAME="${REALIGNED_BAM%.realigned_deduped_sorted.bam}"
VARIANT_VCF="${SAMPLE_NAME}_germline_call.g.vcf"

ml purge
ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

echo "### Variant calling ### - START: $(date)"
sentieon driver -r $REF_FASTA -i $REALIGNED_BAM --interval $TARGETS_BED\
    -q ${SAMPLE_NAME}_recal_data.table --algo Haplotyper --emit_mode gvcf \
     $VARIANT_VCF
echo "### Variant calling ### - END: $(date)"
