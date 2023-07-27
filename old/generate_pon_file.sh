#!/bin/bash
#
#SBATCH --job-name=panel_of_normal
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=95:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=94G

#This script generates a panel of normal file for use with sentieon's somatic variant calling, in the future if you need more than one pon file
#edit this script to do it for multiple samples

RESULTS_DIR="/oak/stanford/groups/cgawad/Illumina_Data/NextSeq2000/2022_06_06_VascM_EEG/2022-06-19_MRD_project_Results"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
cd ${RESULTS_DIR}
NORMAL_SAMPLE_NAME="EEG05_Bulk_PBMC_WES_Capt10_S58"
NORMAL_RECALIBRATED_BAM="${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
REFERENCE="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
NUMBER_THREADS=4
OUT_NORMAL_VCF="${NORMAL_SAMPLE_NAME}_pon"

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location


sentieon driver -t $NUMBER_THREADS -r $REFERENCE -i $NORMAL_RECALIBRATED_BAM \
   --algo TNscope --tumor_sample $NORMAL_SAMPLE_NAME $OUT_NORMAL_VCF
