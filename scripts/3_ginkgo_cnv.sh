#!/bin/bash
#
#SBATCH --job-name=3_ginkgo_cnv
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=31G

START_TIME=$(date +%s)
GINKGO_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/ginkgo/"
WORK_DIR=$(date '+%Y-%m-%d_%H-%M-%S')
FULL_WORK_DIR="${GINKGO_DIR}/uploads/${WORK_DIR}"
BAM_REGEX=".*.recalibrated_realigned_deduped_sorted.bam"
BAM_SUFFIX=".recalibrated_realigned_deduped_sorted.bam"
KB_BIN_SIZE="500"
GROUP_SEGMENTATION=0
GENOME_VERSION="hg38"
NEW_5M_DIR="0"
while [ "$1" != "" ]; do
    case $1 in
        --bam_dir )             shift
                                BAM_DIR=$1
                                ;;
        --bam_regex )           shift
                                BAM_REGEX=$1
                                ;;
        --bam_suffix )          shift
                                BAM_SUFFIX=$1
                                ;;
        --kb_bin_size )         shift
                                KB_BIN_SIZE=$1
                                ;;
        --results_dir )         shift
                                RESULTS_DIR=$1
                                ;;
        --group_segmentation )  GROUP_SEGMENTATION=1
                                ;;
        --new_5M_folder )       shift
                                NEW_5M_DIR=$1
                                ;;
    esac
    shift
done

if [ -z $BAM_DIR ]; then
    echo "Variables not supplied correctly. Check script for intake parameters. All are required to be specified. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nBam dir: $BAM_DIR\nResults dir: $RESULTS_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX\nKb bin size: $KB_BIN_SIZE\nFull work dir: $FULL_WORK_DIR"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
mkdir -p $FULL_WORK_DIR
mkdir -p $RESULTS_DIR/ginkgo_outputs
cd $GINKGO_DIR

ml php/7.3.0 ghostscript/9.53.2 java gsl/2.3 R/4.0.2 biology bedtools samtools/1.8
export R_LIBS="/home/groups/cgawad/R_LIBS"

SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi

> $FULL_WORK_DIR/list
for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    echo "Preparing $SAMPLE"
    ml biology bedtools
    bedtools bamtobed -i ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} > ${FULL_WORK_DIR}/${SAMPLE}.bed
    gzip ${FULL_WORK_DIR}/${SAMPLE}.bed
    echo "${SAMPLE}.bed.gz" >> ${FULL_WORK_DIR}/list
    echo "Done preparing $SAMPLE"
done

cp config.txt ${FULL_WORK_DIR}/config
sed -i "s/variable_500000_76_bwa/variable_${KB_BIN_SIZE}000_76_bwa/" ${FULL_WORK_DIR}/config
if [ $GROUP_SEGMENTATION -eq 1 ]; then
    sed -i "s/segMeth=0/segMeth=1/" ${FULL_WORK_DIR}/config
fi
bash scripts/sentieon_pipeline_analyze.sh $FULL_WORK_DIR

for SAMPLE in ${SAMPLE_ARRAY[@]}; do
   rm ${FULL_WORK_DIR}/${SAMPLE}.bed.gz
done


if [ "$NEW_5M_DIR" != "0" ]; then
    mkdir -p $NEW_5M_DIR
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        cp ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} ${NEW_5M_DIR}/
        cp ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}.bai ${NEW_5M_DIR}/
    done
fi

# gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=01_Combined_CNV_Plots.pdf -dBATCH *CN.pdf
# cp 01_Combined_CNV_Plots.pdf ..

cd $RESULTS_DIR
mkdir -p $RESULTS_DIR/Ginkgo_CN_Plots

find $RESULTS_DIR/ginkgo_outputs -name '*CN.pdf' -exec mv {} $RESULTS_DIR/Ginkgo_CN_Plots \;

if [ -f "01_Combined_Ginkgo_CNV.pdf" ] ; then
    rm 01_Combined_Ginkgo_CNV.pdf
fi

ml system poppler/0.47.0
pdfunite $RESULTS_DIR/Ginkgo_CN_Plots/*CN.pdf $RESULTS_DIR/01_Combined_Ginkgo_CNV.pdf

exit
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
