#!/bin/bash
#
#SBATCH --job-name=4_sentieon_somatic_variant_calling
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=115G
#SBATCH --nice=[-20]

NUMBER_THREADS=16
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
        --normal_sample_name )      shift
                                    NORMAL_SAMPLE_NAME=$1
                                    ;;
        --sample_string )           shift
                                    SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                                    ;;
        --dbSNP )                   shift
                                    dbSNP=$1
                                    ;;
        --targets_bed )             shift
                                    TARGETS_BED=$1
                                    ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $REFERENCE_DIR ] || [ -z $REF_FASTA ] || [ -z $NORMAL_SAMPLE_NAME ] || \
    [ -z $SAMPLE_ARRAY ] || [ -z $dbSNP ] || [ -z $TARGETS_BED ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"

ml purge
ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131 bcftools/1.16
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${SCRATCH_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${SCRATCH_DIR}/std_err_out_files/""%A_variant_call_2%x.err"
GERMLINE_RESOURCE="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/af-only-gnomad.hg38.vcf.gz"
#CONTAMINATION_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz"
PANEL_OF_NORMAL="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/1000g_pon.hg38.vcf.gz"   

cd ${SCRATCH_DIR}
CONTAMINATION_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/af-only-gnomad.hg38.vcf.gz"

echo "### Variant calling ### - START: $(date)"

ERROR_DIR1="${SCRATCH_DIR}/std_err_out_files/""%A_variant_call%x.err"
ERROR_DIR2="${SCRATCH_DIR}/std_err_out_files/""%A_variant_call_2%x.err"


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
TMP_OUT_TN_VCF="${SCRATCH_DIR}/${SAMPLE}_temp.vcf"
OUT_TN_VCF="${SCRATCH_DIR}/${SAMPLE}_variant.vcf"
ORIENTATION_DATA="${SCRATCH_DIR}/${SAMPLE}_orienation_data"
CONTAMINATION_DATA="${SCRATCH_DIR}/${SAMPLE}_contamination_data"
SEGMENTS="${CONTAMINATION_DATA}.segments"

#somethin's goin on where control samples have all the somatic calls of control samples, not sure what is happening

#Panel of normal only needs to be generated once per normal file, I am just lazy and put it here and uncomment and recomment as needed
#TODO: make a new script to generate the panel of normal using multiple normal sample files, don't need to know because each patient only
#has one PBMC normal sample at the time of writing this

#sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
#   -i ${SCRATCH_DIR}"/"${TUMOR_REALIGNED_BAM}  \
#   --algo OrientationBias --tumor_sample ${SAMPLE} \
  #     $ORIENTATION_DATA

#sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
#   -i ${SCRATCH_DIR}"/"${TUMOR_REALIGNED_BAM} \
#	--algo ContaminationModel --tumor_sample ${SAMPLE} --vcf ${CONTAMINATION_VCF} \
#		$CONTAMINATION_DATA

#For some reason using brackets like they tell you to on SENTIEON's website breaks this
#Can't get it to run the two other algo calls in one sentieon call so seperated them, prob will be less eficient Sadge

 sentieon driver -t $NUMBER_THREADS -r $REF_FASTA --interval $TARGETS_BED \
   -i ${SCRATCH_DIR}"/"${TUMOR_REALIGNED_BAM} -q ${SCRATCH_DIR}"/"${TUMOR_RECAL_TABLE} \
   -i ${SCRATCH_DIR}"/"${NORMAL_REALIGN_BAM} -q ${SCRATCH_DIR}"/"${NORMAL_RECAL_TABLE} \
   --algo TNscope --tumor_sample ${SAMPLE} \
      --normal_sample ${NORMAL_SAMPLE_NAME} \
      --dbsnp $dbSNP \
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
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"