#!/bin/bash

#SBATCH --job-name=sentieon_germline_calling
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=200G
#SBATCH --cpus-per-task=4

RESULTS_DIR=$1
REFERENCE_DIR=$2
REF_FASTA=$3
#NUMBER_THREADS=$4
SAMPLE_STRING=$5


while [ "$1" != "" ]; do
    case $1 in

        --results-dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --sample-prefix )   shift
                            SAMPLE_PREFIX=$1
                            ;;
        --normal-path )     shift
                            NORMAL_BAM_PATH=$1
                            ;;
        --ref )             shift
                            REF_FASTA=$1
                            ;;
        --dbsnp )           shift
                            DBSNP_VCF=$1
                            ;;
        --scan2-results )   shift
                            SCAN2_RESULTS=$1
                            ;;
        --regions-bed )     shift
                            REGIONS_BED=$1
                            ;;
        --bam_args )        shift
                            BAM_ARGS=$1
                            ;;
	    --sample_string )   shift
			                SAMPLE_STRING=$1
			                ;;
        --mmq )		        shift
			                MMQ=$1
                            ;;
	    --pipeline_dir )    shift
						    PIPELINE_DIR=$1
						    ;;
    esac
    shift
done

SCRIPT_DIR=${PIPELINE_DIR}/scripts
SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
NUMBER_THREADS=16

REALIGNED_BAM="${SAMPLE}"
SAMPLE_NAME="${REALIGNED_BAM%.realigned_deduped_sorted.bam}"
basename="${SAMPLE_NAME##*/}"
VARIANT_VCF="${RESULTS_DIR}/${SCAN2_RESULTS}/gatk/mmq${MMQ}_${basename}_germline_call.g.vcf"
echo variant vcf is ${VARIANT_VCF}

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

mkdir -p ${RESULTS_DIR}/${SCAN2_RESULTS}/gatk

#if a recal table was not already made, make it now. the pipeline
#produces this file naturally, but have had situations where
#collaborators don't send recal data table so we can just 
#make it ourselves
if [ ! "$(ls -A "${SAMPLE_NAME}_recal_data.table")" ] || [ ! "$(ls -A "${SAMPLE_NAME}*bai")" ]; then
    sh $SCRIPT_DIR/get_recal_table.sh --results-dir $RESULTS_DIR --table-name ${SAMPLE_NAME}_recal_data.table --sample-bam $REALIGNED_BAM
fi


echo "### Variant calling ### - START: $(date)"
sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $REALIGNED_BAM --interval $REGIONS_BED \
    -q ${SAMPLE_NAME}_recal_data.table --algo Haplotyper --trim_soft_clip --dbsnp $DBSNP_VCF --min_map_qual $MMQ --emit_mode gvcf \
     $VARIANT_VCF
echo "### Variant calling ### - END: $(date)"
