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
cd "/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results"

INDEL_PREFIX=${SNP_PREFIX}"_indel"

#TODO-One of these steps may be labeling mutations as germline mutations in the somatic called file, may need to edit this if still getting 
#germline variations showing up as somatic variations

perl ${ANNOVAR_DIR}/table_annovar.pl ${VCF_FILE} -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${SAMPLE} -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome

bgzip ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf

tabix ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz

bgzip ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf

tabix ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz

perl ${ANNOVAR_DIR}/table_annovar.pl ${VCF_FILE} -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${INDEL_PREFIX} -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome
echo "### Annotating SNPs and Indels ###"

echo "### Convert annotated VCF to TSV ###"
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.tsv

#sed -i "s/#CHROM/CHROM/" ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
#${TOOLS_DIR}/vcflib/bin/vcf2tsv \
#    -g ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
#    ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
#sed -i "s/#CHROM/CHROM/" ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv

echo "### Convert annotated VCF to TSV ###"

echo "### Recalculate VAF ###"

ml math py-numpy

python3 ${SCRIPT_DIR}/split_add_VAF.py \
    -i ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
    -o ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv

python3 ${SCRIPT_DIR}/split_add_VAF.py \
    -i ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
    -o ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
rm ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
rm ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Recalculate VAF ###"

echo "### Computing mutational signature with SigProfiler ###"
OPTIONS=()
if [ "$GENOME_VERSION" = "b37" ]; then
    OPTIONS+=( "--b37" )
fi

ml system ghostscript

PROJECT="EEG_project"

srun ${SCRIPT_DIR}/ginkgo_cnv.sh --project ${PROJECT}.tranche_${TRANCHE} \
    --bam_dir ${RESULTS_DIR}  

ml system ghostscript

if [ -f 01_Ginko_CNV.pdf ]; then
	mv 01_Ginko_CNV.pdf 01_${PROJECT}_Ginko_CNV
fi

gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=01_${PROJECT}_Combined_PDFs.pdf -dBATCH *pdf

if [ -f 01_${PROJECT}_Ginko_CNV ]; then
        mv 01_${PROJECT}_Ginko_CNV 01_${PROJECT}_Ginko_CNV.pdf
fi


srun ${SCRIPT_DIR}/SigProfiler.sh --project ${PROJECT}.tranche_${TRANCHE} \
    --tsv ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv \
    --script_dir $SCRIPT_DIR --results_dir $RESULTS_DIR ${OPTIONS[@]}

echo "### Computing mutational signature with SigProfiler ###"


echo "ANNOTATION DONE"

