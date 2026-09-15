#!/bin/bash
#
#SBATCH --job-name=4_sentieon_somatic_variant_calling
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad

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
        --rna )                     shift
                                    RNA=$1
                                    ;;
        --bam_suffix )              shift
                                    BAM_SUFFIX=$1
                                    ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $REFERENCE_DIR ] || [ -z $REF_FASTA ] || [ -z $NORMAL_SAMPLE_NAME ] || \
    [ -z $SAMPLE_ARRAY ] || [ -z $dbSNP ] || [ -z $TARGETS_BED ] || [ -z $RNA ] || [ -z $BAM_SUFFIX ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $SCRATCH_DIR

ml biology bwa/0.7.17 samtools/1.8 java/1.8.0_131 bcftools/1.16
ml biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=${SENTIEON_LICENSE:-srcc-license-srcf.stanford.edu:8990}

if [ $RNA -eq 1 ]; then
    REALIGNED_BAM="${SAMPLE}.rna.realigned_deduped_sorted.bam"
    RECALIBRATED_BAM="${SAMPLE}${BAM_SUFFIX}"
    VARIANT_VCF="${SAMPLE}.g.vcf"
else
    REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
    RECALIBRATED_BAM="${SAMPLE}${BAM_SUFFIX}"
    VARIANT_VCF="${SAMPLE}.g.vcf"
fi
VARIANT_VCF="${SAMPLE}.vcf"
TUMOR_RECAL_TABLE="${SAMPLE}_recal_data.table"
NORMAL_RECAL_TABLE="${NORMAL_SAMPLE_NAME}_recal_data.table"
SOMATIC_VCF="${SAMPLE}_somatic.vcf"
PANEL_OF_NORMAL="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/1000g_pon.hg38.vcf.gz"   


# Somethin's goin on where control samples have all the somatic calls of control samples, not sure what is happening

# Panel of normal only needs to be generated once per normal file, I am just lazy and put it here and uncomment and recomment as needed
# TODO: make a new script to generate the panel of normal using multiple normal sample files, don't need to know because each patient only
#   has one PBMC normal sample at the time of writing this
# ORIENTATION_DATA="${SCRATCH_DIR}/${SAMPLE}_orienation_data"
# CONTAMINATION_DATA="${SCRATCH_DIR}/${SAMPLE}_contamination_data"
# CONTAMINATION_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/af-only-gnomad.hg38.vcf.gz"
# sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i ${SCRATCH_DIR}/${SAMPLE}${BAM_SUFFIX}  \
#     --algo OrientationBias --tumor_sample ${SAMPLE} $ORIENTATION_DATA
# sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i ${SCRATCH_DIR}/${SAMPLE}${BAM_SUFFIX} \
# 	--algo ContaminationModel --tumor_sample $SAMPLE --vcf ${CONTAMINATION_VCF} $CONTAMINATION_DATA


echo "### Somatic variant calling ### - START: $(date)"
sentieon driver -t $SLURM_CPUS_ON_NODE -r $REF_FASTA --interval $TARGETS_BED \
    -i ${SCRATCH_DIR}/${SAMPLE}${BAM_SUFFIX} -q ${SCRATCH_DIR}/${TUMOR_RECAL_TABLE} \
    -i ${SCRATCH_DIR}/${NORMAL_SAMPLE_NAME}${BAM_SUFFIX} -q ${SCRATCH_DIR}/${NORMAL_RECAL_TABLE} \
    --algo TNscope --tumor_sample ${SAMPLE} --normal_sample ${NORMAL_SAMPLE_NAME} \
    --dbsnp $dbSNP --pon $PANEL_OF_NORMAL --disable_detector sv ${SAMPLE}_variant.vcf

echo DEBUG: checking whether problematic alt allele was found:
cat ${SAMPLE}_variant.vcf | awk '{ if ($4 == "M") { print } }'
echo "### Somatic variant calling ### - END: $(date)"


if [ ! -f ${SAMPLE}_variant.vcf ]; then
    echo "Final file ${SAMPLE}_variant.vcf not found. Exiting with code 1"
    exit 1
fi
mv ${SAMPLE}_recal_* Extra_Sentieon_Files/
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"