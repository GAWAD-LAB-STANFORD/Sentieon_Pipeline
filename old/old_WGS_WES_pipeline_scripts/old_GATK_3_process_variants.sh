#!/bin/bash
#
#SBATCH --job-name=GATK_3_process_variants
#SBATCH --cpus-per-task=4
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
RESULTS_DIR=$1
GENOME_VERSION=$2
PROJECT=$3
TARGETED=$4
TOOLS_DIR=$5
INTERVALS_STRING=$6
REFERENCE_DIR=$7
ANNOVAR_DIR=$8
PANEL_BED=$9
TRANCHE=${10}
PIPELINE_STATUS=${11}
PYTHON_LIBS=${12}
PYTHON_LIBS_SITE_PACKAGES=${13}
SCRIPT_DIR=${14}

echo -e "START: $(date)\nWGS WES Pipeline\nResults dir: $RESULTS_DIR\nProject: $PROJECT"
cd $RESULTS_DIR

ml R/4.0.2 java perl biology gatk bedtools samtools
export R_LIBS="/home/groups/cgawad/R_LIBS"

ml python/3.6.1
export PATH=${PYTHON_LIBS}:$PATH
export PYTHONPATH=${PYTHON_LIBS_SITE_PACKAGES}:$PYTHONPATH

# File and directory paths (reference files available in /oak/stanford/groups/cgawag/Reference_Files/)
# hg38 reference files
ANNOVAR_GENOME_VERSION="hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
HAPMAP_VCF="${REFERENCE_DIR}/hapmap_3.3.hg38.vcf.gz"
OMNI_VCF="${REFERENCE_DIR}/1000G_omni2.5.hg38.vcf.gz"
ONEKG_VCF="${REFERENCE_DIR}/1000G_phase1.snps.high_confidence.hg38.vcf.gz"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
MILLS_VCF="${REFERENCE_DIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
AXIOM_VCF="${REFERENCE_DIR}/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz"

# hg19 version b37 reference files
if [ "$GENOME_VERSION" = "b37" ]; then
    ANNOVAR_GENOME_VERSION="hg19"
    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
    HAPMAP_VCF="${REFERENCE_DIR}/hapmap_3.3.b37.vcf.gz"
    OMNI_VCF="${REFERENCE_DIR}/1000G_omni2.5.b37.vcf.gz"
    ONEKG_VCF="${REFERENCE_DIR}/1000G_phase1.snps.high_confidence.b37.vcf.gz"
    DBSNP_VCF="${REFERENCE_DIR}/dbsnp_138.b37.vcf.gz"
    MILLS_VCF="${REFERENCE_DIR}/Mills_and_1000G_gold_standard.indels.b37.vcf.gz"
    AXIOM_VCF="${REFERENCE_DIR}/Axiom_Exome_Plus.genotypes.all_populations.poly.vcf.gz"
fi

echo "START: $(date)"
echo "### Gathering genomic interval VCFs ### - START: $(date)"
INTERVAL_ARRAY=( $(echo $INTERVALS_STRING | sed 's/_/ /g') )
INTERVAL_VCFS_ARRAY=()
for INTERVAL in ${INTERVAL_ARRAY[@]}; do # GatherVcfs requires genomic interval inputs in order
    if [ -f "${PROJECT}.${INTERVAL}.merged.vcf.gz" ]; then
        INTERVAL_VCFS_ARRAY+=( "${PROJECT}.${INTERVAL}.merged.vcf.gz" )
    else
        echo "Missing ${PROJECT}.${INTERVAL}.merged.vcf.gz"
    fi
done
echo -e "Number of intervals: ${#INTERVAL_ARRAY[@]}\nIntervals: ${INTERVAL_ARRAY[@]}\nNumber of VCFs: ${#INTERVAL_ARRAY[@]}\nVCFs to gather: ${INTERVAL_VCFS_ARRAY[@]}"
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx64g" GatherVcfs \
    -I $(echo ${INTERVAL_VCFS_ARRAY[@]} | sed 's/ / -I /g') -O ${PROJECT}.merged.vcf.gz
gatk IndexFeatureFile -I ${PROJECT}.merged.vcf.gz 
echo "### Gathering genomic interval VCFs ### - END: $(date)"

if [ "$PANEL_BED" = "0" ]; then
    SNP_PREFIX="${PROJECT}.merged.snp_vqsr.snp_only"
    INDEL_PREFIX="${PROJECT}.merged.indel_vqsr.indel_only"
    if [ $TARGETED -eq 1 ]; then
        echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
            -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.snp.recal \
            --tranches-file ${PROJECT}.merged.snp.recal.tranches \
            --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
            --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
            --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
            -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
            -tranche $TRANCHE \
            --max-gaussians 4 -R $REF_FASTA --rscript-file ${PROJECT}.merged.snp.recal_plots.R
        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
            -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.indel.recal \
            --tranches-file ${PROJECT}.merged.indel.recal.tranches \
            --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
            --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
            -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
            -tranche $TRANCHE \
            --max-gaussians 4 -R $REF_FASTA \
            --rscript-file ${PROJECT}.merged.indel.recal_plots.R
        echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
    else
        echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
            -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.snp.recal \
            --tranches-file ${PROJECT}.merged.snp.recal.tranches \
            --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
            --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
            --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
            -an QD -an DP -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
            -tranche $TRANCHE \
            --max-gaussians 4 -R $REF_FASTA --rscript-file ${PROJECT}.merged.snp.recal_plots.R
        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
            -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.indel.recal \
            --tranches-file ${PROJECT}.merged.indel.recal.tranches \
            --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
            --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
            -an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
            -tranche $TRANCHE \
            --max-gaussians 4 -R $REF_FASTA \
            --rscript-file ${PROJECT}.merged.indel.recal_plots.R
        echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
    fi

    echo "### Applying VQSR to SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" ApplyVQSR \
        -R $REF_FASTA -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.snp_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.merged.snp.recal.tranches \
        --recal-file ${PROJECT}.merged.snp.recal -mode SNP
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" ApplyVQSR \
        -R $REF_FASTA -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.indel_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.merged.indel.recal.tranches \
        --recal-file ${PROJECT}.merged.indel.recal -mode INDEL
    echo "### Applying VQSR to SNPs and Indels ### - END: $(date)"

    echo "### Extracting SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" SelectVariants \
        -R $REF_FASTA -V ${PROJECT}.merged.snp_vqsr.vcf.gz \
        -O ${SNP_PREFIX}.vcf.gz -select-type SNP
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" SelectVariants \
        -R $REF_FASTA -V ${PROJECT}.merged.indel_vqsr.vcf.gz \
        -O ${INDEL_PREFIX}.vcf.gz -select-type INDEL
    echo "### Extracting SNPs and Indels ### - END: $(date)"
else
    SNP_PREFIX="${PROJECT}.merged.snp_only"
    INDEL_PREFIX="${PROJECT}.merged.indel_only"
    
    echo "### Extracting SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" SelectVariants \
        -R $REF_FASTA -V ${PROJECT}.merged.vcf.gz \
        -O ${SNP_PREFIX}.vcf.gz -select-type SNP
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" SelectVariants \
        -R $REF_FASTA -V ${PROJECT}.merged.vcf.gz \
        -O ${INDEL_PREFIX}.vcf.gz -select-type INDEL
    echo "### Extracting SNPs and Indels ### - END: $(date)"
fi

echo "### Annotating SNPs and Indels ### - START: $(date)"
perl ${ANNOVAR_DIR}/table_annovar.pl ${SNP_PREFIX}.vcf.gz -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${SNP_PREFIX} -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome
perl ${ANNOVAR_DIR}/table_annovar.pl ${INDEL_PREFIX}.vcf.gz -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${INDEL_PREFIX} -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome
bgzip ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf
tabix ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
bgzip ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf
tabix ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
echo "### Annotating SNPs and Indels ### - END: $(date)"

echo "### Convert annotated VCF to TSV ### - START: $(date)"
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
sed -i "s/#CHROM/CHROM/" ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
sed -i "s/#CHROM/CHROM/" ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Convert annotated VCF to TSV ### - END: $(date)"

echo "### Recalculate VAF ### - START: $(date)"
python3 ${SCRIPT_DIR}/split_add_VAF.py \
    -i ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv \
    -o ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
python3 ${SCRIPT_DIR}/split_add_VAF.py \
    -i ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv \
    -o ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
rm ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
rm ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Recalculate VAF ### - END: $(date)"

echo "### Computing mutational signature with SigProfiler ### - START: $(date)"
OPTIONS=()
if [ "$GENOME_VERSION" = "b37" ]; then
    OPTIONS+=( "--b37" )
fi
srun ${SCRIPT_DIR}/SigProfiler.sh --project ${PROJECT}.tranche_${TRANCHE} \
    --tsv ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv \
    --script_dir $SCRIPT_DIR --results_dir $RESULTS_DIR ${OPTIONS[@]}
echo "### Computing mutational signature with SigProfiler ### - END: $(date)"

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
if [ ! -f ${PROJECT}.merged.vcf.gz ]; then
    echo "Final file ${PROJECT}.merged.vcf.gz not found. Exiting with code 1"
    echo "${PROJECT}.merged.vcf.gz file not found. Exiting with code 1" >> $PIPELINE_STATUS
    exit 1
fi
echo "### GATK step 3 - Processing variants ### - END: $(date)" >> $PIPELINE_STATUS
rm ${INTERVAL_VCFS_ARRAY[@]}
rm ${PROJECT}.*.merged.vcf.gz*
if [ "$PANEL_BED" = "0" ]; then
    # rm ${PROJECT}.merged.snp.recal ${PROJECT}.merged.snp.recal.idx 
    # rm ${PROJECT}.merged.indel.recal ${PROJECT}.merged.indel.recal.idx
    rm ${PROJECT}.merged.snp_vqsr.vcf.gz* ${PROJECT}.merged.indel_vqsr.vcf.gz*
    rm ${SNP_PREFIX}.avinput ${INDEL_PREFIX}.avinput
else
    rm ${SNP_PREFIX}.avinput ${INDEL_PREFIX}.avinput
fi