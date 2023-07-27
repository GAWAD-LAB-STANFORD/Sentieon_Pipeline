#SBATCH --job-name=sentieon_svc_runner
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

#This script supplies samples for annovar.sh to use, which runs annotations on vcf files

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

RESULTS_DIR="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-22_EEG_project_Results"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
NUMBER_THREADS=4
NORMAL_SAMPLE_NAME="EEG05_Bulk_PBMC_WES_Capt10_S58"

SAMPLE_PREFIX="EEG05"

#SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "EEG05_PBMC_merged.vcf" -exec basename {} \;) ) 
#SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )

SAMPLE="EEG05_svc_merged.vcf"
cd ${RESULTS_DIR}
echo "### Variant annotation ### - START: $(date)"

ERROR_DIR="${RESULTS_DIR}/std_err_out_files/""%A_variant_annotation_%x.err"""
#for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    sbatch --error ${ERROR_DIR} --cpus-per-task 4  /oak/stanford/groups/cgawad/Scripts/Sentieon_Pipeline_Under_Constr/annovar.sh $SAMPLE
#done

echo "### Variant annotation ### - DONE: $(date)"
