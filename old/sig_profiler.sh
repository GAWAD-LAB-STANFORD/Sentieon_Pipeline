#!/bin/bash
#
#SBATCH --job-name=GATK_3_process_variants
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=95:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=94G

SAMPLE=$1

echo "### Annotating SNPs and Indels ###"
ml gsl/2.3
ml R/4.0.2 java perl biology gatk bedtools samtools
export R_LIBS="/home/groups/cgawad/R_libs"

ml python/3.6.1
ml java/1.8.0_131
export PATH=${PYTHON_LIBS}:$PATH
export PYTHONPATH=${PYTHON_LIBS_SITE_PACKAGES}:$PYTHONPATH



ml biology vcftools samtools

TRANCHE="99.9"
PIPELINE_DIR="/oak/stanford/groups/cgawad/Scripts/WGS_WES_Pipeline_2.0"
SCRIPT_DIR="${PIPELINE_DIR}/scripts"
ANNOVAR_GENOME_VERSION="hg38"
ANNOVAR_DIR="/oak/stanford/groups/cgawad/Reference_Files/ANNOVAR/"
SNP_PREFIX=${SAMPLE}
VCF_FILE="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results/${SNP_PREFIX}"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
cd "/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results/"

INDEL_PREFIX=${SNP_PREFIX}"_indel"

echo "### Convert annotated VCF to TSV ###"
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv

sed -i "s/#CHROM/CHROM/" ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
sed -i "s/#CHROM/CHROM/" ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv

echo "### Convert annotated VCF to TSV ###"

echo "### Recalculate VAF ###"


echo "ANNOTATION DONE"
