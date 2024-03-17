#!/bin/bash
#
#SBATCH --job-name=5_sentieon_joint_genotyping
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
        --project )                 shift
                                    PROJECT=$1
                                    ;;
        --targets_bed )             shift
                                    TARGETS_BED=$1
                                    ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $REF_FASTA ] || [ -z $PROJECT ] || [ -z $TARGETS_BED ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"
cd $SCRATCH_DIR

ml biology bcftools bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=license4.stanford.edu:5443

echo "### Joint genotyping ### - START: $(date)"
sentieon driver --interval $TARGETS_BED -r $REF_FASTA --algo GVCFtyper ${PROJECT}.germline_merged.vcf *_germline_call.g.vcf
bgzip -f ${PROJECT}.germline_merged.vcf
tabix ${PROJECT}.germline_merged.vcf.gz
echo "### Joint genotyping ### - END: $(date)"


if [ ! -f ${PROJECT}.germline_merged.vcf ]; then
    echo "Final file ${PROJECT}.germline_merged.vcf not found. Exiting with code 1"
    exit 1
fi
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"