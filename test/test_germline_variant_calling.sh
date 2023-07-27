#!/bin/bash
#
#SBATCH --job-name=sentieon_gvc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

#SAMPLE_ARRAY=( $(echo ${1} | sed 's/:/ /g') )
#SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
	

RESULTS_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-22_EEG_project_Results"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
NUMBER_THREADS=4
SAMPLE_NAME=${SAMPLE}

#SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )

echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${RESULTS_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${RESULTS_DIR}/std_err_out_files/""%A_variant_call_2%x.err"
SAMPLE=${SAMPLE%".deduped_sorted.bam"}
BAM="${SAMPLE}.bam"
SORTED_BAM="${SAMPLE}.sorted.bam"
DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
TUMOR_REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
RECALIBRATED_BAM="${SAMPLE}.recalibrated_realigned_deduped_sorted.bam"
JOINT_VCF="EEG05_joint_germline.vcf"
TUMOR_RECAL_TABLE="${SAMPLE}_recal_data.table"
NORMAL_REALIGN_BAM="${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
NORMAL_RECAL_TABLE="${NORMAL_SAMPLE_NAME}_recal_data.table"
SOMATIC_VCF="${SAMPLE}_somatic.vcf"
TMP_OUT_TN_VCF=${RESULTS_DIR}"/${SAMPLE}_temp.vcf"
OUT_TN_VCF=${RESULTS_DIR}"/${SAMPLE}_variant.vcf"
dbSNP="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
#Trying out joint genotyping, --emit_mode gvcf may cause problems
SAMPLE_PREFIX="EEG05"


SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.g.vcf" ) )
for i in ${SAMPLE_ARRAY[@]}; do
	echo $i
done
TEMP_ARRAY_START=1
TEMP_ARRAY_INCREMENT=1000
TEMP_SAMPLES_STRING=$( IFS=$' '; echo "${SAMPLE_ARRAY[*]}" )

 TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$' '; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    echo ${TEMP_SAMPLES_STRING}

STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"

echo ${TEMP_SAMPLE_STRING}


cd ${RESULTS_DIR}
sbatch --cpus-per-task $NUMBER_THREADS --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out --wrap "sentieon driver -r $REF_FASTA --algo GVCFtyper ${JOINT_VCF} ${SAMPLE_PREFIX}*.g.vcf"
echo "### Variant calling ### - END: $(date)"


if [ ! -f $OUT_TN_VCF ]; then
    echo "No $VARIANT_VCF found. Exiting with code 1"
    exit 1
fi



