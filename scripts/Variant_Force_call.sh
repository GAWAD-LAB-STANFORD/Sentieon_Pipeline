#!/bin/bash
#
#SBATCH --job-name=sentieon_somatic_calling
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=115G
#SBATCH --nice=[-20]

ml purge
ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131 bcftools/1.16
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

while [ "$1" != "" ]; do
    case $1 in
        -h | --help )           echo -e $HELP
                                exit 0
                                ;;
        -r | --results_dir )    shift
                                RESULTS_DIR=$1
                                ;;
        -p | --project )        shift
                                PROJECT=$1
                                ;;
    -n |--normal_sample_name )  shift
                                NORMAL_SAMPLE_NAME=$1
                                ;;
       -a | --filtered_Vcf )    shift
                                PRE_FILTERED_VCF=$1 filtered
                                ;;
        --sample_prefix )    shift
                             SAMPLE_PREFIX=$1
                             ;;

    esac
    shift
done

OUTPUT_DIR=$RESULTS_DIR
RESULTS_DIR=$SCRATCH/$PROJECT
mkdir -p $RESULTS_DIR
cd $RESULTS_DIR/

if [ -z $STD_ERR_OUT_DIR ]; then
    STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
fi
echo final directory is $OUTPUT_DIR
echo working directory is $RESULTS_DIR

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
REF_FASTA="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta"
#NUMBER_THREADS=$4
NORMAL_SAMPLE_NAME=$NORMAL_SAMPLE_NAME
EXOME_TARGETS_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_3col.bed"

TARGETS_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_3col.bed"
NUMBER_THREADS=16


SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "*.recalibrated_realigned_deduped_sorted.bam" -exec basename {} \;) )
JOB_COUNT=${#SAMPLE_ARRAY[@]}
TEMP_ARRAY_START=1
TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
echo ${TEMP_SAMPLES_STRING}

SAMPLE_STRING=TEMP_SAMPLES_STRING

SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') )

echo "results_dir is ${RESULTS_DIR}"
echo "REFERENCE_DIR IS ${REFERENCE_DIR}"
echo "NUMBER_THREADS IS ${NUMBER_THREADS}"
echo "NORMAL_SAMPLE_NAME IS ${NORMAL_SAMPLE_NAME}"
echo "Sample prefix is ${SAMPLE_PREFIX}"
echo "sample string is ${SAMPLE_STRING}"

for SAMPLE in "${SAMPLE_ARRAY[@]}"
do
    echo "SAMPLE is $SAMPLE"
done

echo ${SAMPLE_ARRAY}

echo "slurm array task id is: ${SLURM_ARRAY_TASK_ID}"
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
#SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )
echo "SAMPLE is ${SAMPLE}"
echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${RESULTS_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${RESULTS_DIR}/std_err_out_files/""%A_variant_call_2%x.err"
GERMLINE_RESOURCE="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/af-only-gnomad.hg38.vcf.gz"
#CONTAMINATION_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz"
PANEL_OF_NORMAL="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/1000g_pon.hg38.vcf.gz"   

cd ${RESULTS_DIR}
CONTAMINATION_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/af-only-gnomad.hg38.vcf.gz"

echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${RESULTS_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${RESULTS_DIR}/std_err_out_files/""%A_variant_call_2%x.err"


SAMPLE=${SAMPLE%".realigned_deduped_sorted.bam"}
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

#somethin's goin on where control samples have all the somatic calls of control samples, not sure what is happening

#Panel of normal only needs to be generated once per normal file, I am just lazy and put it here and uncomment and recomment as needed
#TODO: make a new script to generate the panel of normal using multiple normal sample files, don't need to know because each patient only
#has one PBMC normal sample at the time of writing this

#sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
#   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM}  \
#   --algo OrientationBias --tumor_sample ${SAMPLE} \
  #     $ORIENTATION_DATA

#sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
#   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM} \
#	--algo ContaminationModel --tumor_sample ${SAMPLE} --vcf ${CONTAMINATION_VCF} \
#		$CONTAMINATION_DATA

#For some reason using brackets like they tell you to on SENTIEON's website breaks this
#Can't get it to run the two other algo calls in one sentieon call so seperated them, prob will be less eficient Sadge

 sentieon driver -t $NUMBER_THREADS -r $REF_FASTA --interval $TARGETS_BED \
   -i ${RESULTS_DIR}"/"${TUMOR_REALIGNED_BAM} -q ${RESULTS_DIR}"/"${TUMOR_RECAL_TABLE} \
   -i ${RESULTS_DIR}"/"${NORMAL_REALIGN_BAM} -q ${RESULTS_DIR}"/"${NORMAL_RECAL_TABLE} \
   --algo TNscope --tumor_sample ${SAMPLE} \
      --normal_sample ${NORMAL_SAMPLE_NAME} \
      --force-call-filtered-alleles \
      --alleles $Pre_filtered_Vcf \
      ----min-pruning 1  \
      --dbsnp $dbSNP \
      --prune_factor 1 \
      --pon $PANEL_OF_NORMAL \
	  --disable_detector sv \
	${OUT_TN_VCF}

#This command will filter out weird ALT alleles, note this overwrites the vcf file so use with caution
#cat ${OUT_TN_VCF}.before_filter | awk -F'\t' '/^#/ || $5 ~ /^[ACGTNacgtn<]+|\*|\.)$/' > $OUT_TN_VCF

#this command uses bcftools over awk and is more stringent, my preference is actually awk but bcftools was suggested by sentieon developer and will also likely avoid unintended consequences while on the flipside not preventing similar errors with other types of mutations
#bcftools view -V 'bnd' ${OUT_TN_VCF}.before_filter | sentieon util vcfconvert - ${OUT_TN_VCF}

# ^^^ The filtering step has been moved to 4_vcf_concat.sh

echo DEBUG: checking whether problematic alt allele was found:
cat $OUT_TN_VCF | awk '{ if ($4 == "M") { print } }'

#sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
#   --algo TNfilter --tumor_sample ${SAMPLE} \
#   --normal_sample $NORMAL_SAMPLE_NAME \
#   -v $TMP_OUT_TN_VCF \
#   --contamination $CONTAMINATION_DATA  \
#   --orientation_priors $ORIENTATION_DATA \
#	 $OUT_TN_VCF




echo "### Variant calling ### - END: $(date)"


if [ ! -f $OUT_TN_VCF ]; then
    echo "No $VARIANT_VCF found. Exiting with code 1"
    exit 1
fi


JOINT_VCF="${PROJECT}_joint_germline_merged.vcf"
sentieon driver --interval $TARGETS_BED -r $REF_FASTA --algo GVCFtyper ${JOINT_VCF} ${SAMPLE_PREFIX}*.g.vcf

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

