#!/bin/bash
#
#SBATCH --job-name=3_sentieon_germline_calling
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --scratch_dir )             shift
                                    SCRATCH_DIR=$1
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
        --bam_suffix )              shift
                                    BAM_SUFFIX=$1
                                    ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $REF_FASTA ] || [ -z $SAMPLE_ARRAY ] || [ -z $TARGETS_BED ] || \
    [ -z $TARGETS_BED ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $SCRATCH_DIR

ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=${SENTIEON_LICENSE:-srcc-license-srcf.stanford.edu:8990}


echo "### Germline variant calling ### - START: $(date)"
sentieon driver -t $SLURM_CPUS_ON_NODE -r $REF_FASTA -i ${SAMPLE}${BAM_SUFFIX} --interval $TARGETS_BED \
    -q ${SAMPLE}_recal_data.table --algo Haplotyper --emit_mode gvcf ${SAMPLE}_germline_call.g.vcf
echo "### Germline variant calling ### - END: $(date)"


if [ ! -f ${SAMPLE}_germline_call.g.vcf ]; then
    echo "Final file ${SAMPLE}_germline_call.g.vcf not found. Exiting with code 1"
    exit 1
fi
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"