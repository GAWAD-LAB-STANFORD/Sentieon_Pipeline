#!/bin/bash

START_TIME=$(date +%s)
RESULTS_DIR=$1
REF_FASTA=$2
BAM_SUFFIX=$3
SAMPLE=$4
SCRIPT_DIR=$5
FINAL_SNPS=$6
FINAL_INDELS=$7

echo -e "START: $(date)\nWGS WES Pipeline\nSlurm ID: $SLURM_ARRAY_TASK_ID\nSample: $SAMPLE\nResults dir: $RESULTS_DIR"
cd $RESULTS_DIR

ml biology samtools bwa bedtools
ml python/3.6.1
export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH
export PATH=/home/groups/cgawad/python_libs/bin:$PATH
ml py-numpy/1.19.2_py36 py-biopython/1.70_py27 py-pandas/1.0.3_py36
ml python/3.6.1

echo "### Sort BAM by read name ### - START: $(date)"
samtools sort -n -o ${SAMPLE}_qname${BAM_SUFFIX} ${SAMPLE}${BAM_SUFFIX}
echo "### Sort BAM by read name ### - END: $(date)"

echo "### Sort BAM by leftmost mapping coordinates ### - START: $(date)"
samtools sort -o ${SAMPLE}_sorted${BAM_SUFFIX} ${SAMPLE}${BAM_SUFFIX}
samtools index ${SAMPLE}_sorted${BAM_SUFFIX}
echo "### Sort BAM by leftmost mapping coordinates ### - END: $(date)"

echo "### Extract circular DNA rearrangements ### - START: $(date)"
Circle-Map ReadExtractor -i ${SAMPLE}_qname${BAM_SUFFIX} -o ${SAMPLE}_circular_read_candidates${BAM_SUFFIX}
echo "### Extract circular DNA rearrangements ### - END: $(date)"

echo "### Sort read candidates by coordinates ### - START: $(date)"
samtools sort -o ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX} ${SAMPLE}_circular_read_candidates${BAM_SUFFIX}
samtools index ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX}
echo "### Sort read candidates by coordinates ### - END: $(date)"

echo "### Detect circular DNA ### - START: $(date)"
Circle-Map Realign -i ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX} \
    -qbam ${SAMPLE}_qname${BAM_SUFFIX} -sbam ${SAMPLE}_sorted${BAM_SUFFIX} \
    -fasta $REF_FASTA -o ${SAMPLE}_unknown_circle.bed
echo "### Detect circular DNA ### - END: $(date)"

echo "### Parsing annotated variants that fall within circular regions ### - START: $(date)"
if [ ! -f $FINAL_SNPS ]; then
    echo "$FINAL_SNPS final SNPs file not found. Cannot parsed annotated variants from circular regions"
else
    CIRCLE_SNPS="${SAMPLE}_snp_variants_in_circular_regions.tsv"
    python3 ${SCRIPT_DIR}/circle_map_variants.py $FINAL_SNPS ${SAMPLE}_unknown_circle.bed $CIRCLE_SNPS
fi
if [ ! -f $FINAL_INDELS ]; then
    echo "$FINAL_INDELS final indels file not found. Cannot parsed annotated variants from circular regions"
else
    CIRCLE_INDELS="${SAMPLE}_indel_variants_in_circular_regions.tsv"
    python3 ${SCRIPT_DIR}/circle_map_variants.py $FINAL_SNPS ${SAMPLE}_unknown_circle.bed $CIRCLE_INDELS
fi
echo "### Parsing annotated variants that fall within circular regions ### - END: $(date)"
 
rm ${SAMPLE}_qname${BAM_SUFFIX} ${SAMPLE}_sorted${BAM_SUFFIX}
rm ${SAMPLE}_circular_read_candidates${BAM_SUFFIX} ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX}
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"