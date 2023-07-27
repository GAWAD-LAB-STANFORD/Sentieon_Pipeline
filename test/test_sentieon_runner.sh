#SBATCH --job-name=sentieon_svc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

#This script is named really poorly, it runs the germline_variant_calling.sh script for germline variant calling on already deduped and
#sorted bam files

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

RESULTS_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-22_MRD_project_Results"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
NUMBER_THREADS=4
NORMAL_SAMPLE_NAME="EEG05_Bulk_PBMC_WES_Capt10_S58"
SCRIPT_DIR="/oak/stanford/groups/cgawad/Scripts/Sentieon_Pipeline_Under_Constr/"
SCRIPT_NAME="germline_variant_calling.sh"
SAMPLE_PREFIX="EEG05"

SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.g.vcf" ) )
STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"

#SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )

echo "### Germline Calling ### - START: $(date)"

ERROR_DIR="${RESULTS_DIR}/std_err_out_files/""%A_germline_calling_%x.err"""
#for SAMPLE in ${SAMPLE_ARRAY[@]}; do
 #   SAMPLE=${SAMPLE%".deduped_sorted.bam"}
    #sbatch --error ${ERROR_DIR} --cpus-per-task 4  --wrap "${SCRIPT_DIR}${SCRIPT_NAME} $SAMPLE"
    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1))} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    sbatch --cpus-per-task $NUMBER_THREADS --parsable -e $STD_ERR_OUT_DIR/germline_call.err -o $STD_ERR_OUT_DIR/germline_call.out \
         --array=1-${TEMP_JOB_COUNT} germline_variant_calling.sh \
         ${TEMP_SAMPLES_STRING}
#done

echo "### Germline Calling ### - DONE: $(date)"
