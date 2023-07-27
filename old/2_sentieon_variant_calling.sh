#!/bin/bash
#
#SBATCH --job-name=sentieon_svc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

RESULTS_DIR=$1
REFERENCE_DIR=$2
REF_FASTA=$3
NUMBER_THREADS=$4
SAMPLE_STRING=$5
NORMAL_SAMPLE_NAME=$6
SAMPLE_PREFIX=$7
SAMPLE_ARRAY=( $(echo ${8} | sed 's/:/ /g') )

#SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )

echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${RESULTS_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${RESULTS_DIR}/std_err_out_files/""%A_variant_call_2%x.err"

	
GERMLINE_RESOURCE="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
CONTAMINATION_VCF="${REFERENCE_DIR}/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz"

cd ${RESULTS_DIR}


echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${RESULTS_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${RESULTS_DIR}/std_err_out_files/""%A_variant_call_2%x.err"


SAMPLE=${SAMPLE%".deduped_sorted.bam"}
BAM="${SAMPLE}.bam"
SORTED_BAM="${SAMPLE}.sorted.bam"
DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
TUMOR_REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
RECALIBRATED_BAM="${SAMPLE}.recalibrated_realigned_deduped_sorted.bam"
VARIANT_VCF="${SAMPLE}.vcf"
TUMOR_RECAL_TABLE="${SAMPLE}_recal_data.table"
NORMAL_REALIGN_BAM="${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
NORMAL_RECAL_TABLE="${NORMAL_SAMPLE_NAME}_recal_data.table"
SOMATIC_VCF="${SAMPLE}_somatic.vcf"
TMP_OUT_TN_VCF="${RESULTS_DIR}/${SAMPLE}_temp.vcf"
OUT_TN_VCF="${RESULTS_DIR}/${SAMPLE}_variant.vcf"
ORIENTATION_DATA="${RESULTS_DIR}/${SAMPLE}_orienation_data"
CONTAMINATION_DATA="${RESULTS_DIR}/${SAMPLE}_contamination_data"
SEGMENTS="${CONTAMINATION_DATA}.segments"


#Panel of normal only needs to be generated once per normal file, I am just lazy and put it here and uncomment and recomment as needed
#TODO: make a new script to generate the panel of normal using multiple normal sample files, don't need to know because each patient only
#has one PBMC normal sample at the time of writing this

sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM}  \
   --algo OrientationBias --tumor_sample ${SAMPLE} \
       $ORIENTATION_DATA

sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM} \
	--algo ContaminationModel --tumor_sample ${SAMPLE} --vcf ${CONTAMINATION_VCF} \
		$CONTAMINATION_DATA

#For some reason using brackets like they tell you to on SENTIEON's website breaks this
#Can't get it to run the two other algo calls in one sentieon call so seperated them, prob will be less eficient Sadge

 sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM} -q ${RESULTS_DIR}"/"${TUMOR_RECAL_TABLE} \
   -i ${RESULTS_DIR}"/"${NORMAL_REALIGN_BAM} -q ${RESULTS_DIR}"/"${NORMAL_RECAL_TABLE} \
   --algo TNhaplotyper2 --tumor_sample ${SAMPLE} \
      --normal_sample ${NORMAL_SAMPLE_NAME} \
      --germline_vcf $GERMLINE_RESOURCE \
	$TMP_OUT_TN_VCF 


sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
   --algo TNfilter --tumor_sample ${SAMPLE} \
   --normal_sample $NORMAL_SAMPLE_NAME \
   -v $TMP_OUT_TN_VCF \
   --contamination $CONTAMINATION_DATA  \
   --orientation_priors $ORIENTATION_DATA \
	 $OUT_TN_VCF	




echo "### Variant calling ### - END: $(date)"


if [ ! -f $OUT_TN_VCF ]; then
    echo "No $VARIANT_VCF found. Exiting with code 1"
    exit 1
fi



