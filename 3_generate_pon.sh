#!/bin/bash
#
#SBATCH --job-name=sentieon_gen_pon
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=115G
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad

#NUMBER_THREADS=$1
NUMBER_THREADS=16
REF_FASTA=$2
NORMAL_PATTERN=$3
RESULTS_DIR=$4
SAMPLE_STRING=$5
SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE=${SAMPLE%".deduped_sorted.bam"}


NORMAL_RECALIBRATED_BAM="${NORMAL_SAMPLE_NAME}.recalibrated_realigned_deduped_sorted.bam"


sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $NORMAL_RECALIBRATED_BAM \
   --algo TNscope --tumor_sample $NORMAL_SAMPLE_NAME $OUT_NORMAL_VCF

ml purge
ml biology bcftools
ml biology samtools

DIR=$RESULTS_DIR
bcftools merge -m all -f PASS,. --force-samples $DIR/*${NORMAL_PATTERN}*.vcf.gz |\
bcftools plugin fill-AN-AC |\
bcftools filter -i 'SUM(AC)>1' > ${SAMPLE}_panel_of_normal.vcf

