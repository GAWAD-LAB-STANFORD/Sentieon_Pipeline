#!/bin/bash
#
#SBATCH --job-name=get_recal_table
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --error=/scratch/users/sschulz/H1_cell_test/get_recal_table.err
#SBATCH --mail-type=ALL

ml biology gatk/4.1.4.1 bedtools/2.27.1 samtools/1.8 bwa/0.7.17 sentieon/202112.01
ml sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=${SENTIEON_LICENSE:-srcc-license-srcf.stanford.edu:8990} #your license file location

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
REF_FASTA="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta"
NUMBER_THREADS=16

while [ "$1" != "" ]; do
    case $1 in

        --results-dir )     shift
                            RESULTS_DIR=$1
                            ;;
		--table-name ) 		shift
							RECAL_TABLE_NAME=$1
							;;
		--sample-bam )     shift
							SAMPLE_BAM=$1
 
    esac
    shift
done

cd $RESULTS_DIR

##ONLY RUN THIS IF YOU ARE SURE THE BAM FILES ARE REALIGNED AND DEDUPED ALREADY

samtools index $SAMPLE_BAM

sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
	-i $SAMPLE_BAM --algo QualCal ${RECAL_TABLE_NAME}

#csv should be unecessary bug can edit this to get it later

#sentieon driver -t $NUMBER_THREADS --algo QualCal --plot \
#    --before ${SAMPLE}_recal_data.table --after ${SAMPLE}_recal_data.table.after ${SAMPLE}_recal_result.csv
#sentieon plot QualCal -o ${SAMPLE}_BQSR_PDF ${SAMPLE}_recal_result.csv
