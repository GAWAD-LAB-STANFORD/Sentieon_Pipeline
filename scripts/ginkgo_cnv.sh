#!/bin/bash
#
#SBATCH --job-name=ginkgo_cnv
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=120G

START_TIME=$(date +%s)
GINKGO_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/ginkgo/"
WORK_DIR=$(date '+%Y-%m-%d_%H-%M-%S')
FULL_WORK_DIR="${GINKGO_DIR}/uploads/${WORK_DIR}"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
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
        --hg19 )                GENOME_VERSION="hg19"
                                ;;
        --b37 )                 GENOME_VERSION="b37"
                                ;;
        --new_5M_folder )       shift
                                NEW_5M_DIR=$1
                                ;;
    esac
    shift
done

echo -e "START: $(date)\nBam dir: ${BAM_DIR}\nResults dir: $RESULTS_DIR\nBam regex: ${BAM_REGEX}\nBam suffix: ${BAM_SUFFIX}\nKb bin size: $KB_BIN_SIZE\nFull work dir: $FULL_WORK_DIR"

ml php R/4.0.2 biology bedtools samtools
export R_LIBS="/home/groups/cgawad/R_LIBS"

SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
if [ ! -d $FULL_WORK_DIR ]; then
    mkdir $FULL_WORK_DIR
fi
cd $GINKGO_DIR

> ${FULL_WORK_DIR}/list
for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    echo "Preparing $SAMPLE"
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
if [ $GENOME_VERSION = "hg19" ]; then
    sed -i "s/chosen_genome=hg38/chosen_genome=hg19/" ${FULL_WORK_DIR}/config
elif [ $GENOME_VERSION = "b37" ]; then
    sed -i "s/chosen_genome=hg38/chosen_genome=b37/" ${FULL_WORK_DIR}/config
fi
bash scripts/analyze.sh $WORK_DIR

for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    rm ${FULL_WORK_DIR}/${SAMPLE}.bed.gz
done

mkdir -p $RESULTS_DIR
mv ${FULL_WORK_DIR}/* ${RESULTS_DIR}/
if [ "$NEW_5M_DIR" != "0" ]; then
    mkdir -p $NEW_5M_DIR
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        mv ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} ${NEW_5M_DIR}/
        mv ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}.bai ${NEW_5M_DIR}/
    done
fi

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
