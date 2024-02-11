#!/bin/bash
#
#SBATCH --job-name=vcf_merge
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --cpus-per-task=2
#SBATCH --mem=31G

set -x

RESULTS_DIR=$1
PROJECT=$2
echo "about to make vcf_list"
echo "results dir: ${RESULTS_DIR}"

cd ${RESULTS_DIR}
VCF_LIST=( $(find ${RESULTS_DIR} -maxdepth 1 -name "*variant.vcf" ) )

#Currently major bugs i think from merging vcfs, transition to using gather vcf instead
ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131 bcftools/1.16
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location


for vcf in ${VCF_LIST[@]}; do
	FILTERED_VCF_FN=${vcf%.vcf}_filtered.vcf
    bcftools view -e "ALT[*] == '<INS>'" $vcf | \
    bcftools view -e "REF == 'M'" | \
    bcftools view -e "ALT[*] == 'M'" | \
    sentieon util vcfconvert - ${FILTERED_VCF_FN}
	bcftools index ${FILTERED_VCF_FN}
	bgzip -f ${FILTERED_VCF_FN}
	tabix "${FILTERED_VCF_FN}.gz"
done

echo "exited for loop"

VCF_LIST=( $(find ${RESULTS_DIR} -maxdepth 1 -name "*_filtered.vcf.gz" ! -name "*PBMC*") )

bcftools merge --force-samples -o "$RESULTS_DIR/${PROJECT}_svc_merged.vcf" *_filtered.vcf.gz

#Attempt to filter out still remaining problematic <INS> record that was still in vcf, possible this won't remove all of the junk, causing the run to still fail

bcftools index ${PROJECT}_svc_merged.vcf
bgzip -f ${PROJECT}_svc_merged.vcf
tabix "${PROJECT}_svc_merged.vcf.gz"

echo "merging done"
