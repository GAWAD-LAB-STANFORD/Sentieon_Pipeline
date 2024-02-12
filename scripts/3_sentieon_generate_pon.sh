#!/bin/bash
#
#SBATCH --job-name=3_sentieon_gen_pon
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=115G
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad

NUMBER_THREADS=16
START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --ref_fasta )               shift
                                    REF_FASTA=$1
                                    ;;
        --normal_pattern )          shift
                                    NORMAL_PATTERN=$1
                                    ;;
        --results_dir )             shift
                                    RESULTS_DIR=$1
                                    ;;
        --script_dir )              shift
                                    SCRIPT_DIR=$1
                                    ;;
        --sample_string )           shift
                                    SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                                    ;;
    esac
    shift
done

if [ -z $REF_FASTA ] || [ -z $NORMAL_PATTERN ] || [ -z $RESULTS_DIR ] || [ -z $SAMPLE_ARRAY ]; then
    echo "Variables not supplied correctly. Check script for intake parameters. All are required to be specified. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE=${SAMPLE%".deduped_sorted.bam"}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"

NORMAL_RECALIBRATED_BAM="${NORMAL_SAMPLE_NAME}.recalibrated_realigned_deduped_sorted.bam"


sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $NORMAL_RECALIBRATED_BAM \
   --algo TNscope --tumor_sample $NORMAL_SAMPLE_NAME $OUT_NORMAL_VCF

ml purge
ml biology bcftools
ml biology samtools

DIR=$RESULTS_DIR
bcftools merge -m all -f PASS,. --force-samples $DIR/*${NORMAL_PATTERN}*.vcf.gz |\
bcftools plugin fill-AN-AC |\
bcftools filter -i 'SUM(AC)>1' > ${SAMPLE}_panel_of_normal.vcf

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"