#!/bin/bash
#
#SBATCH --job-name=STAR_align_reads
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=60G


START_TIME=$(date +%s)
RESULTS_DIR=$1
REF_FASTA=$2
SAMPLE_ARRAY=( $(echo $3 | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
R1_SUFFIX=$4
R2_SUFFIX=$5

echo -e "START: $(date)\nWGS WES Pipeline\nSlurm ID: $SLURM_ARRAY_TASK_ID\nSample: $SAMPLE"
cd $RESULTS_DIR

ml python/3.6.1 java 
ml biology bwa samtools gatk star/2.5.4b

echo "### Aligning RNA fastqs to human - First of two passes ### - START: $(date)"
SAMPLE="scRNA-10x-5E-BM-AML-1355-GEX_S2"
STAR --genomeDir \
    /oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/hg38_STAR_index/ \
    --readFilesIn ${SAMPLE}${R1_SUFFIX} ${SAMPLE}${R2_SUFFIX} \
    --readFilesCommand zcat \
    --runThreadN 2 \
    --outFileNamePrefix ${SAMPLE}. \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMunmapped Within \
    --outSAMattributes Standard
echo "### Aligning RNA fastqs to human - First of two passes ### - START: $(date)"
