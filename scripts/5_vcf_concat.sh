#!/bin/bash
#
#SBATCH --job-name=5_vcf_merge
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=31G
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --scratch_dir )             shift
                                    SCRATCH_DIR=$1
                                    ;;
        --project )                 shift
                                    PROJECT=$1
                                    ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $PROJECT ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"
cd $SCRATCH_DIR

ml biology bwa samtools bcftools java/1.8.0_131 
ml biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=srcc-license-srcf.stanford.edu:8990


echo "### Merging VCFs ### - START: $(date)"
VCF_ARRAY=( $(find ${SCRATCH_DIR} -maxdepth 1 -name "*_variant.vcf" | sed "s/_variant.vcf//") )
VCF_NUMBER=${#VCF_ARRAY[@]}
VCF_COUNT=1
for VCF in ${VCF_ARRAY[@]}; do
    echo "VCF filtering $VCF_COUNT of $VCF_NUMBER - ${VCF}.vcf"
    bcftools view -e "ALT[*] == '<INS>'" ${VCF}_variant.vcf | bcftools view -e "REF == 'M'" | \
        bcftools view -e "ALT[*] == 'M'" | sentieon util vcfconvert - ${VCF}_variant_filtered.vcf
    bgzip -f ${VCF}_variant_filtered.vcf
    tabix ${VCF}_variant_filtered.vcf.gz
    VCF_COUNT=$((VCF_COUNT+1))
done
echo "VCF filtering done"
bcftools merge --force-samples -o ${PROJECT}.somatic_merged.vcf *_variant_filtered.vcf.gz
# Attempt to filter out still remaining problematic <INS> record that was still in vcf, possible this won't remove all of the junk, causing the run to still fail
bgzip -f ${PROJECT}.somatic_merged.vcf
tabix ${PROJECT}.somatic_merged.vcf.gz
echo "VCFs merged"
echo "### Merging VCFs ### - END: $(date)"


if [ ! -f ${PROJECT}.somatic_merged.vcf.gz ]; then
    echo "Final file ${PROJECT}.somatic_merged.vcf.gz not found. Exiting with code 1"
    exit 1
fi
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"