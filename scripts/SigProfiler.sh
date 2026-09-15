#!/bin/bash
#
#SBATCH --job-name=sig_profiler
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
REF_FASTA="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/"
GENOME_VERSION="hg38"

while [ "$1" != "" ]; do
    case $1 in
        --project )         shift
                            PROJECT=$1
                            ;;
        --vcf )             shift
                            VCF=$1
                            ;;
        --tsv )             shift
                            TSV=$1
                            ;;
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --hg19 )            GENOME_VERSION="hg19"
                            ;;
        --b37 )             GENOME_VERSION="b37"
                            ;;
        --script_dir )      shift
                            SCRIPT_DIR=$1
                            ;;
    esac
    shift
done

echo "RESULTSDIR is ${RESULTS_DIR}"


echo -e "START: $(date)\nProject: $PROJECT"
if [ ! -z $VCF ]; then
    echo "VCF: $VCF"
    TSV=$(echo $VCF | sed "s/.gz//" | sed "s/.vcf/.tsv/")
fi
if [ $GENOME_VERSION = "hg19" ]; then
    REF_FASTA="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg19/ucsc.hg19.fasta"
elif [ $GENOME_VERSION = "b37" ]; then
    REF_FASTA="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_b37/human_g1k_v37.fasta"
fi
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$(dirname $TSV)
fi
cd $RESULTS_DIR
echo -e "TSV: $TSV\nResults dir: $RESULTS_DIR\nRef fasta: $REF_FASTA"


ml R/4.0.2 java perl biology gatk bedtools samtools
export R_LIBS="/home/groups/cgawad/R_LIBS"

ml python/3.6.1
export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH
export PATH=/home/groups/cgawad/python_libs/bin:$PATH

if [ ! -z $VCF ]; then
    echo "### Convert annotated VCF to TSV ### - START: $(date)"
    ${TOOLS_DIR}/vcflib/bin/vcf2tsv -g $VCF > $TSV
    sed -i "s/#CHROM/CHROM/" $TSV
    echo "### Convert annotated VCF to TSV ### - END: $(date)"
fi

echo "### Extracting unique variant positions ### - START: $(date)"
cut -f 1,2,4,5 $TSV | uniq > ${PROJECT}.temp_bedtools_reformat.tsv
echo "### Extracting unique variant positions ### - START: $(date)"

echo "### Reformatting for bedtools input ### - START: $(date)"
Rscript ${SCRIPT_DIR}/SigProfiler_1_Bedtools_Reformat.R ${PROJECT}.temp_bedtools_reformat.tsv \
    ${PROJECT}.temp_bedtools_before_input.tsv ${PROJECT}.temp_bedtools_after_input.tsv
echo "### Reformatting for bedtools input ### - END: $(date)"

echo "### Obtaining previous and subsequent reference base ### - START: $(date)"
bedtools getfasta -fi $REF_FASTA -bed ${PROJECT}.temp_bedtools_before_input.tsv \
    -bedOut > ${PROJECT}.temp_bedtools_before_output.tsv
echo "Previous base obtained"
bedtools getfasta -fi $REF_FASTA -bed ${PROJECT}.temp_bedtools_after_input.tsv \
    -bedOut > ${PROJECT}.temp_bedtools_after_output.tsv
echo "Subsequent base obtained"
echo "### Obtaining previous and subsequent reference base ### - END: $(date)"

echo "### Reformatting into trinucleotide context ### - START: $(date)"
Rscript ${SCRIPT_DIR}/SigProfiler_2_Trinucleotide_Reformat.R ${PROJECT}.temp_bedtools_reformat.tsv \
    ${PROJECT}.temp_bedtools_before_output.tsv ${PROJECT}.temp_bedtools_after_output.tsv \
    ${PROJECT}.sigprofiler_input.tsv ${SCRIPT_DIR}/Mutation_Types.tsv
echo "### Reformatting into trinucleotide context ### - END: $(date)"

echo "### Obtaining mutational signature with SigProfiler ### - START: $(date)"
python3 -u ${SCRIPT_DIR}/SigProfiler_3_Extractor.py ${PROJECT}.sigprofiler_input.tsv \
    ${PROJECT}_SigProfiler_Results $RESULTS_DIR
cp ${PROJECT}_SigProfiler_Results/SBS96/Suggested_Solution/COSMIC_SBS96_Decomposed_Solution/SBS96_Decomposition_Plots.pdf ${PROJECT}_SigProfiler_Results/${PROJECT}_SBS96_Decomposition_Plots.pdf
echo "### Obtaining mutational signature with SigProfiler ### - END: $(date)"

rm ${PROJECT}.temp_bedtools_reformat.tsv 
rm ${PROJECT}.temp_bedtools_before_input.tsv ${PROJECT}.temp_bedtools_after_input.tsv 
rm ${PROJECT}.temp_bedtools_before_output.tsv ${PROJECT}.temp_bedtools_after_output.tsv
rm ${PROJECT}.sigprofiler_input.tsv
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
