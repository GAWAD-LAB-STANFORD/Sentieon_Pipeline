#!/bin/bash
#
#SBATCH --job-name=5_sentieon_joint_genotyping
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --scratch_dir )             shift
                                    SCRATCH_DIR=$1
                                    ;;
        --reference_dir )           shift
                                    REFERENCE_DIR=$1
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

if [ -z $SCRATCH_DIR ] || [ -z $REFERENCE_DIR ] || [ -z $REF_FASTA ] || [ -z $PROJECT ] || \
    [ -z $TARGETS_BED ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"
cd $SCRATCH_DIR

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

echo "### Variant calling ### - START: $(date)"
#Trying out joint genotyping, --emit_mode gvcf may cause problems

JOINT_VCF="${PROJECT}_joint_germline_merged.vcf"
sentieon driver --interval $TARGETS_BED -r $REF_FASTA --algo GVCFtyper ${JOINT_VCF} *.g.vcf

echo "### Variant calling ### - END: $(date)"


if [ ! -f $OUT_TN_VCF ]; then
    echo "No $VARIANT_VCF found. Exiting with code 1"
    exit 1
fi

ml purge
ml biology bcftools
ml biology samtools

bcftools index ${JOINT_VCF}
bgzip -f ${JOINT_VCF}
tabix "${JOINT_VCF}.gz"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"