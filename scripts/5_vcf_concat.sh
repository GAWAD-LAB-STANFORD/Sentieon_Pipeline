#!/bin/bash
#
#SBATCH --job-name=5_vcf_merge
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --cpus-per-task=2
#SBATCH --mem=31G

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

ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131 bcftools/1.16
ml biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=license4.stanford.edu:5443


echo "### Merging VCFs ### - START: $(date)"
VCF_ARRAY=( $(find ${SCRATCH_DIR} -maxdepth 1 -name "*variant.vcf" ) )
for vcf in ${VCF_ARRAY[@]}; do
    FILTERED_VCF_FN=$(echo $vcf | sed "s/.vcf/_filtered.vcf/")
    bcftools view -e "ALT[*] == '<INS>'" $vcf | bcftools view -e "REF == 'M'" | \
        bcftools view -e "ALT[*] == 'M'" | sentieon util vcfconvert - $FILTERED_VCF_FN
    bcftools index $FILTERED_VCF_FN
    bgzip -f $FILTERED_VCF_FN
    tabix ${FILTERED_VCF_FN}.gz
done
bcftools merge --force-samples -o ${SCRATCH_DIR}/${PROJECT}_svc_merged.vcf *_filtered.vcf.gz
# Attempt to filter out still remaining problematic <INS> record that was still in vcf, possible this won't remove all of the junk, causing the run to still fail
bcftools index ${PROJECT}.svc_merged.vcf
bgzip -f ${PROJECT}.svc_merged.vcf
tabix ${PROJECT}.svc_merged.vcf.gz
echo "### Merging VCFs ### - END: $(date)"


echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"