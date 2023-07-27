#!/bin/bash

#SBATCH --job-name=germline_calling
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH --cpus-per-task=8

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
        --cross_dir )       shift
                            CROSS_SAMPLE_DIR=$1
                            ;;
	--sample_string )   shift
			    SAMPLE_STRING=$1
			    ;;
    esac
    shift
done

SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
NUMBER_THREADS=16

REALIGNED_BAM="${SAMPLE}"
SAMPLE_NAME="${REALIGNED_BAM%.realigned_deduped_sorted.bam}"
VARIANT_VCF="mmq60_${SAMPLE_NAME}_germline_call.g.vcf"

ml purge
ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

echo "### Variant calling ### - START: $(date)"
sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $REALIGNED_BAM --interval $REGIONS_BED \
    -q ${SAMPLE_NAME}_recal_data.table --algo Haplotyper --trim_soft_clip --dbsnp $DBSNP_VCF --min_map_qual 60 --emit_mode gvcf \
     $VARIANT_VCF
echo "### Variant calling ### - END: $(date)"
