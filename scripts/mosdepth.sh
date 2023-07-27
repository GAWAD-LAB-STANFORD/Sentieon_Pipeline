#!/bin/bash
#
#SBATCH --job-name=mosdepth
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
MOSDEPTH="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
GENOME_VERSION="hg38"
MOSDEPTH_REF_DIR="/oak/stanford/groups/cgawad/Reference_Files/mosdepth_hg38"
ECDNA="${MOSDEPTH_REF_DIR}/ecDNA_2_sorted.bed"
ENHANCERS="${MOSDEPTH_REF_DIR}/NA12878_enhancers_grch38_s.bed"
XGEN_EXOME="${MOSDEPTH_REF_DIR}/xgen-exome-research-panel-targets_grch38_6col_s.bed"
PROMOTERS="${MOSDEPTH_REF_DIR}/Promoters_GrCh38_s.bed"
MICROSATELLITES="${MOSDEPTH_REF_DIR}/microsatellite_s.bed"
CPG_ISLANDS="${MOSDEPTH_REF_DIR}/CPG_Islands_s.bed"
REPEATS="${MOSDEPTH_REF_DIR}/repeats_grch38_s.bed"

while [ "$1" != "" ]; do
    case $1 in
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --b37 )             GENOME_VERSION="b37"
                            ;; 
        --bam_dir )         shift
                            BAM_DIR=$1
                            ;;
        --bam_regex )       shift
                            BAM_REGEX=$1
                            ;;
        --bam_suffix )      shift
                            BAM_SUFFIX=$1
                            ;;             
    esac
    shift
done

cd $BAM_DIR
if [ $GENOME_VERSION = "b37" ]; then
    MOSDEPTH_REF_DIR="/oak/stanford/groups/cgawad/Reference_Files/"
    ECDNA="${MOSDEPTH_REF_DIR}/"
    ENHANCERS="${MOSDEPTH_REF_DIR}/"
    XGEN_EXOME="${MOSDEPTH_REF_DIR}/"
    PROMOTERS="${MOSDEPTH_REF_DIR}/"
    MICROSATELLITES="${MOSDEPTH_REF_DIR}/"
    CPG_ISLANDS="${MOSDEPTH_REF_DIR}/"
    REPEATS="${MOSDEPTH_REF_DIR}/"
fi
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"
echo -e "Genome version: $GENOME_VERSION\nResults dir: $RESULTS_DIR\nSample: $SAMPLE"

echo "### Performing methylation analysis ### - START: $(date)"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $ECDNA ${RESULTS_DIR}/${SAMPLE}.ecDNA ${SAMPLE}${BAM_SUFFIX}
echo "ecDNA done"
${MOSDEPTH}/mosdepth -t4 ${SAMPLE}.wgs $BAM
echo "WGS done"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 –by $ENHANCERS ${RESULTS_DIR}/${SAMPLE}.enhancer ${SAMPLE}${BAM_SUFFIX}
echo "enhancer done"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $XGEN_EXOME ${RESULTS_DIR}/${SAMPLE}.exome ${SAMPLE}${BAM_SUFFIX}
echo "exome done"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $PROMOTERS ${RESULTS_DIR}/${SAMPLE}.promoter ${SAMPLE}${BAM_SUFFIX}
echo "promoter done"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $MICROSATELLITES ${RESULTS_DIR}/${SAMPLE}.microsatellite ${SAMPLE}${BAM_SUFFIX}
echo "microsatellite done"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $CPG_ISLANDS ${RESULTS_DIR}/${SAMPLE}.CpGI ${SAMPLE}${BAM_SUFFIX}
echo "cpg islands done"
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $REPEATS ${RESULTS_DIR}/${SAMPLE}.repeats ${SAMPLE}${BAM_SUFFIX}
echo "repeats done"
echo "### Performing methylation analysis ### - START: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"