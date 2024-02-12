#!/bin/bash

#SBATCH --job-name=3_sentieon_germline_calling
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=300G
#SBATCH --cpus-per-task=8

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --results_dir )             shift
                                    RESULTS_DIR=$1
                                    ;;
        --reference_dir )           shift
                                    REFERENCE_DIR=$1
                                    ;;
        --ref_fasta )               shift
                                    REF_FASTA=$1
                                    ;;
        --tools_dir )               shift
                                    TOOLS_DIR=$1
                                    ;;
        --R1_suffix )               shift
                                    R1_SUFFIX=$1
                                    ;;
        --R2_suffix )                     shift
                                    R2_SUFFIX=$1
                                    ;;
        --ref_fasta )               shift
                                    REF_FASTA=$1
                                    ;;
        --sample_string )           shift
                                    SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                                    ;;
        --targets_bed )             shift
                                    TARGETS_BED=$1
                                    ;;
    esac
    shift
done

if [ -z $RESULTS_DIR ] || [ -z $REFERENCE_DIR ] || [ -z $REF_FASTA ] || [ -z $SAMPLE_ARRAY ] || \
    [ -z $TARGETS_BED ]; then
    echo "Variables not supplied correctly. Check script for intake parameters. All are required to be specified. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"

REALIGNED_BAM="${SAMPLE}"
SAMPLE_NAME="${REALIGNED_BAM%.realigned_deduped_sorted.bam}"
VARIANT_VCF="${SAMPLE_NAME}_germline_call.g.vcf"

ml purge
ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

echo "### Variant calling ### - START: $(date)"
sentieon driver -r $REF_FASTA -i $REALIGNED_BAM --interval $TARGETS_BED \
    -q ${SAMPLE_NAME}_recal_data.table --algo Haplotyper --emit_mode gvcf $VARIANT_VCF
echo "### Variant calling ### - END: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"