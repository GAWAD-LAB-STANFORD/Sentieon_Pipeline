#!/bin/bash
#
#SBATCH --job-name=sentieon_scan2
#SBATCH --time=7-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=128G



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
	--ref )		    shift
			    REF_FASTA=$1
			    ;;
	--dbsnp )	    shift    
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
	--cross_dir ) 	    shift
			    CROSS_SAMPLE_DIR=$1
			    ;;
    esac
    shift
done


ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location


#SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01
#export LD_PRELOAD=$SENTIEON_INSTALL_DIR/lib/libjemalloc.so.1

#ml system jemalloc/5.3.0
#export LD_PRELOAD=/share/software/user/open/jemalloc/5.3.0/lib/libjemalloc.so
#export MALLOC_CONF=lg_dirty_mult:-1

ml system jemalloc/5.3.0
export LD_PRELOAD=/share/software/user/open/jemalloc/5.3.0/lib/libjemalloc.so
MALLOC_CONF=metadata_thp:auto,background_thread:true,dirty_decay_ms:30000,muzzy_decay_ms:30000


cd ${RESULTS_DIR}

export bwt_max_mem=128G

echo "normal sample is ${NORMAL_BAM_PATH}"
echo "cross dir is ${CROSS_SAMPLE_DIR}"

SC_BAMS=$(find $RESULTS_DIR -maxdepth 1 -name "TB_04_1678_1*.realigned_deduped_sorted.bam" ! -name "${NORMAL_BAM_PATH}")

echo "sc-bams is ${SC_BAMS}"

SCAN2_BAM_ARGS=""

for i in ${SC_BAMS[@]}; do
        echo "arg is ${i}"
	TEMP=${i/#/--sc-bam }
        SCAN2_BAM_ARGS="${SCAN2_BAM_ARGS} ${TEMP}"
done
TEMP="--sc-bam /scratch/users/sschulz/leukemia_project/SJETV022_G.realigned_deduped_sorted.bam"

SCAN2_BAM_ARGS="${SCAN2_BAM_ARGS} ${TEMP}"

echo $SCAN2_BAM_ARGS

#need to call variants from another donor to do proper indel calling
CROSS_BAMS=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "E8-1_S1*.bam" ! -name "*bulk*")

echo "cross_bams is ${CROSS_BAMS}"

CROSS_BAM_ARGS=""

for i in ${CROSS_BAMS[@]}; do
        echo "arg is ${i}"
        TEMP=${i/#/--sc-bam }
        CROSS_BAM_ARGS="${CROSS_BAM_ARGS} ${TEMP}"
done


cross_bulk=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "bulk*.bam")
for i in ${cross_bulk[@]}; do
        echo "arg is ${i}"
        TEMP=${i/#/--sc-bam }
        CROSS_BAM_ARGS="${CROSS_BAM_ARGS} ${TEMP}"
done


echo $CROSS_BAM_ARGS

BAM_ARGS=""
SCAN2_ARGS="${SCAN2_BAM_ARGS} ${CROSS_BAM_ARGS}"
BAM_ARGS=$(echo ${SCAN2_ARGS} | sed 's/--sc-bam/-i/g')
echo "bam_args is ${BAM_ARGS}"
BAM_ARGS=${BAM_ARGS}


cd ${RESULTS_DIR}

#SC_BAMS=$(find $RESULTS_DIR -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" ! -name "${NORMAL_BAM_PATH}")
#
#echo "sc-bams is ${SC_BAMS}"
#
#SCAN2_BAM_ARGS=""
#
#for i in ${SC_BAMS[@]}; do
#        echo "arg is ${i}"
#        TEMP=${i/#/-i }
#        SCAN2_BAM_ARGS="${SCAN2_BAM_ARGS} ${TEMP}"
#done
#
mkdir -p ${RESULTS_DIR}/${SCAN2_RESULTS}/gatk

echo "bam_args is ${BAM_ARGS}"

sentieon driver \
	--interval $REGIONS_BED \
	-r $REF_FASTA \
	 ${BAM_ARGS} \
	--algo Haplotyper --trim_soft_clip --dbsnp $DBSNP_VCF --min_map_qual 1 "${RESULTS_DIR}/${SCAN2_RESULTS}/gatk/hc_raw.mmq1.vcf"

sentieon driver \
	--interval $REGIONS_BED \
	-r $REF_FASTA \
	${BAM_ARGS} \
	--algo Haplotyper --trim_soft_clip --dbsnp $DBSNP_VCF --min_map_qual 60 "${RESULTS_DIR}/${SCAN2_RESULTS}/gatk/hc_raw.mmq60.vcf"
