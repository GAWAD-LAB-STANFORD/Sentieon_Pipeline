#!/bin/bash
#
#SBATCH --job-name=3_ginkgo_cnv
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=31G
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
GINKGO_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/ginkgo"
WORK_DIR=$(date '+%Y-%m-%d_%H-%M-%S')
FULL_WORK_DIR="${GINKGO_DIR}/uploads/${WORK_DIR}"
BAM_REGEX=".*.recalibrated_realigned_deduped_sorted.bam"
BAM_SUFFIX=".recalibrated_realigned_deduped_sorted.bam"
KB_BIN_SIZE="500"
GROUP_SEGMENTATION=0
GENOME_VERSION="hg38"
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
        --scratch_dir )         shift
                                SCRATCH_DIR=$1
                                ;;
        --group_segmentation )  GROUP_SEGMENTATION=1
                                ;;
        --mb_size )             shift
                                MB_SIZE=$1
                                ;;
        --project )             shift
                                PROJECT=$1
                                ;;
    esac
    shift
done

if [ -z $BAM_DIR ] || [ -z $PROJECT ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nBam dir: $BAM_DIR\nResults dir: $SCRATCH_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX\nKb bin size: $KB_BIN_SIZE\nFull work dir: $FULL_WORK_DIR"
if [ -z $SCRATCH_DIR ]; then
    SCRATCH_DIR=$BAM_DIR
fi
mkdir -p $FULL_WORK_DIR
mkdir -p $SCRATCH_DIR
cd $GINKGO_DIR

ml php/7.3.0 ghostscript/9.53.2 java gsl/2.3 R/4.0.2 biology bedtools samtools/1.8
export R_LIBS="/home/groups/cgawad/R_LIBS"

SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}"
if [ -z $SCRATCH_DIR ]; then
    SCRATCH_DIR=$BAM_DIR
fi
> $FULL_WORK_DIR/list

if [ ! -z $MB_SIZE ]; then
    mkdir -p $BAM_DIR/
    SAMPLE_COUNT=1
    NUMBER_OF_SAMPLES=${#SAMPLE_ARRAY[@]}
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        echo "Sample $SAMPLE_COUNT of $NUMBER_OF_SAMPLES - $SAMPLE"
        
        TOTAL_READS=$(samtools view -c ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX})
        FULL_SIZE=${MB_SIZE}000000
        FRACTION=$(awk -v x="$FULL_SIZE" y="$TOTAL_READS" 'BEGIN {printf "%3f", x / y}')
        if [ $TOTAL_READS -ge ${MB_SIZE}000000 ] && [ ! -z $FRACTION ] && [ $TARGETED -eq 0 ]; then
            gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31g -Xms31G" DownsampleSam \
                -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${FULL_WORK_DIR}/${SAMPLE}.${MB_SIZE}M.bam \
                --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT \
                --MAX_RECORDS_IN_RAM 5500000
            echo -e "\tDownsampled to $MB_SIZE million reads"
            samtools index ${FULL_WORK_DIR}/${SAMPLE}.${MB_SIZE}M.bam
            
            bedtools bamtobed -i ${FULL_WORK_DIR}/${SAMPLE}.${MB_SIZE}M.bam > ${FULL_WORK_DIR}/${SAMPLE}.bed
            gzip ${FULL_WORK_DIR}/${SAMPLE}.bed
            echo "${SAMPLE}.bed.gz" >> ${FULL_WORK_DIR}/list
            echo -e "\tPrepared for ginkgo"
            rm ${FULL_WORK_DIR}/${SAMPLE}.${MB_SIZE}M.bam
            echo -e "\tRemoved downsampled bam"
        else
            echo -e "\tBam is less than $MB_SIZE million reads, cannot downsample"
        fi
        SAMPLE_COUNT=$((SAMPLE_COUNT+1))
    done
else
    SAMPLE_COUNT=1
    NUMBER_OF_SAMPLES=${#SAMPLE_ARRAY[@]}
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        echo "Sample $SAMPLE_COUNT of $NUMBER_OF_SAMPLES - $SAMPLE"
        bedtools bamtobed -i ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} > ${FULL_WORK_DIR}/${SAMPLE}.bed
        gzip ${FULL_WORK_DIR}/${SAMPLE}.bed
        echo "${SAMPLE}.bed.gz" >> ${FULL_WORK_DIR}/list
        echo -e "\tPrepared for ginkgo"
        SAMPLE_COUNT=$((SAMPLE_COUNT+1))
    done
fi

cp config.txt ${FULL_WORK_DIR}/config
sed -i "s/variable_500000_76_bwa/variable_${KB_BIN_SIZE}000_76_bwa/" ${FULL_WORK_DIR}/config
if [ $GROUP_SEGMENTATION -eq 1 ]; then
    sed -i "s/segMeth=0/segMeth=1/" ${FULL_WORK_DIR}/config
fi
bash scripts/sentieon_pipeline_analyze.sh $FULL_WORK_DIR

for SAMPLE in ${SAMPLE_ARRAY[@]}; do
   rm ${FULL_WORK_DIR}/${SAMPLE}.bed.gz
done

mv ${FULL_WORK_DIR}/* ${SCRATCH_DIR}/
ml system poppler/0.47.0
pdfunite ${SCRATCH_DIR}/*CN.pdf ${SCRATCH_DIR}/${PROJECT}_combined_ginkgo_cnv.pdf

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
