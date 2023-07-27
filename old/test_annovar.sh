#!/bin/bash
#
#SBATCH --job-name=GATK_3_process_variants
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=95:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=94G

#This script tries to run a sample you provide it through 3_GATK_process_variants.sh. I don't think it works very well but is worth a shot

SAMPLE=$1

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
VCF_FILE="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results/merged/EEG05_multianno.merged.vcf]"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
cd "/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results/"
PROJECT="EEG05"

INDEL_PREFIX=${SNP_PREFIX}"_indel"

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

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
BISMARK_GENOME="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Bismark"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
REF_GENOME="${REFERENCE_DIR}/Homo_sapiens_assembly38_bedtools.genome"
N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_n25chr.bed"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
WGS_SCATTERED_CALLINGS="${REFERENCE_DIR}/wgs_calling_regions.hg38.interval_list"
INTERVAL_STRING="chr1_chr2_chr3_chr4_chr5_chr6_chr7_chr8_chr9_chr10_chr11_chr12_chr13_chr14_chr15_chr16_chr17_chr18_chr19_chr20_chr21_chr22_chrX_chrY_chrM"
SCATTERED_CALLING_DIR="${REFERENCE_DIR}/scattered_calling_intervals"
EXOME_TARGETS_BED="${REFERENCE_DIR}/xgen-exome-research-panel-targets_grch38_3col.bed"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/xgen-exome-research-panel-targets_grch38_5col.interval_list"

PROJECT="EEG05_multianno"
RESULTS_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results/merged"
STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"



echo "### RUNNING GATK_3_process ####"    

sbatch --parsable -e $STD_ERR_OUT_DIR/gatk_3_test.err -o $STD_ERR_OUT_DIR/gatk_3_test.out \
	${SCRIPT_DIR}/GATK_3_process_variants.sh \
	$RESULTS_DIR $GENOME_VERSION $PROJECT $TARGETED $TOOLS_DIR $INTERVAL_STRING $REFERENCE_DIR \
	$ANNOVAR_DIR $PANEL_BED $TRANCHE $PIPELINE_STATUS $PYTHON_LIBS $PYTHON_LIBS_SITE_PACKAGES $SCRIPT_DIR $FINAL_DIR 

