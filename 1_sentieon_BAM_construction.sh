#!/bin/bash
#
#SBATCH --job-name=1_sentieon_runner
#SBATCH --cpus-per-task=12
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=180G

START_TIME=$(date +%s)
RESULTS_DIR=$1
SKIP_TRIMMOMATIC=2
SCRIPT_DIR=$3
TOOLS_DIR=$4
R1_SUFFIX=$5
R2_SUFFIX=$6
REF_FASTA=$7
NUMBER_THREADS=$8
SAMPLE_ARRAY=( $(echo ${9} | sed 's/:/ /g') )
FASTQ_DIR=${10}
dbSNP=${11}
PROJECT=${12}
SKIP_BAM=${13}
TARGETED=${14}
STD_ERR_OUT_DIR=${15}
TARGETS_BED=${16}

echo "1 is: $1, 2 is $2, 3 is: $3, 4 is: $4, 5 is $5, 6 is $6, 7 is $7, 8 is $8, 9 is $9, 10 is ${10}, 11 is ${11}, 13 is ${13}, 14 is ${14}, 15 is ${15}, 16 is ${16}"


NUMBER_THREADS=16

SENTIEON_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_sentieon_status.txt

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"

echo "FASTQ_DIR IS "{FASTQ_DIR}
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
QUALIMAP_TOOL="${TOOLS_DIR}/qualimap_v2.2.1/qualimap"
PRESEQ_TOOL_DIR="${TOOLS_DIR}/preseq"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"


COUNTER=0
for SAMPLE in "${SAMPLE_ARRAY[@]}"
do
  echo "Sample number $COUNTER is $SAMPLE"
  COUNTER=$((COUNTER+1))
done

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE=${SAMPLE%$R1_SUFFIX}
SAMPLE_NAME=${SAMPLE}

#second check if fastq was undetermined, don't bother trying to align as a BAM

if [ ${SAMPLE_NAME} == "*Undetermined*" ]; then
    exit
fi

echo "TASK_ID is $SLURM_ARRAY_TASK_ID"
echo "SAMPLE about to be worked on is $SAMPLE"

BAM="${SAMPLE}.bam"
SORTED_BAM="${SAMPLE}.sorted.bam"
DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
RECALIBRATED_BAM="${SAMPLE}.recalibrated_realigned_deduped_sorted.bam"
VARIANT_VCF="${SAMPLE}.g.vcf"
BAM_SUFFIX=".bqsr.bam"

echo -e "START: $(date)\nSentieon Pipeline\nResults dir: $RESULTS_DIR\nSample: $SAMPLE\nRef fasta: $REF_FASTA" >> $SENTIEON_STATUS
cd $RESULTS_DIR

ml gsl/2.3
ml java/1.8.0_131
ml biology samtools bedtools gatk bcftools

ml biology bwa samtools
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

R1_FASTQ=${FASTQ_DIR}"/"${SAMPLE}${R1_SUFFIX}
R2_FASTQ=${FASTQ_DIR}"/"${SAMPLE}${R2_SUFFIX}

echo "R1_FASTQ is $R1_FASTQ"

cd $RESULTS_DIR
echo "### Counting fastq read counts Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS
READ_COUNT=$(echo $(zcat $R1_FASTQ | wc -l ) \
    $(zcat $R2_FASTQ | wc -l) | awk '{ print ($1 + $2) / 4 }' )
echo -e "sample\tread_count" > $RESULTS_DIR/${SAMPLE}.read_counts.tsv
echo -e "$SAMPLE\t$READ_COUNT" >> $RESULTS_DIR/${SAMPLE}.read_counts.tsv
echo "### Counting fastq read counts Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS


if [ $SKIP_TRIMMOMATIC -eq 0 ]; then
    UNTRIMMED_R1_FASTQ=${SAMPLE}${R1_SUFFIX}
    UNTRIMMED_R2_FASTQ=${SAMPLE}${R2_SUFFIX}
    R1_FASTQ=$(echo $UNTRIMMED_R1_FASTQ | sed "s/_R1_/_R1_trimmed_/")
    R2_FASTQ=$(echo $UNTRIMMED_R2_FASTQ | sed "s/_R2_/_R2_trimmed_/")
    UNPAIRED_R1_FASTQ=$(echo $UNTRIMMED_R1_FASTQ | sed "s/_R1_/_R1_trimmed_unpaired_/")
    UNPAIRED_R2_FASTQ=$(echo $UNTRIMMED_R2_FASTQ | sed "s/_R2_/_R2_trimmed_unpaired_/")

    echo "### Trimming fastqs Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS
    java -jar ${TOOLS_DIR}/Trimmomatic-0.35/trimmomatic-0.35.jar PE -threads 16 -phred33 -trimlog \
        ${SAMPLE}_trimmomatic_log.txt \
        ${UNTRIMMED_R1_FASTQ} ${UNTRIMMED_R2_FASTQ} \
        ${R1_FASTQ} ${UNPAIRED_R1_FASTQ} \
        ${R2_FASTQ} ${UNPAIRED_R2_FASTQ} \
        ILLUMINACLIP:${TOOLS_DIR}/Trimmomatic-0.35/adapters/TruSeq3-PE-2.fa:2:30:10:2:keepBothReads \
        LEADING:20 TRAILING:20 SLIDINGWINDOW:4:20 MINLEN:36
    echo "### Trimming fastqs Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS
else
    R1_FASTQ=${FASTQ_DIR}"/"${SAMPLE}${R1_SUFFIX}
    R2_FASTQ=${FASTQ_DIR}"/"${SAMPLE}${R2_SUFFIX}
fi

echo $START_TIME
echo "R1 FASTQ: ${R1_FASTQ}"
echo "R2 FASTQ: ${R2_FASTQ}"

echo "### Aligning fastqs Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS

#PLATFORM is the sequencing machine (usually ILLUMINA), sample is the sample name
#-R "@RG\tID:$id\tPL:ILLUMINA\tLB:$lb\tSM:$sm"
#'"'"@RG\tID:$SAMPLE\tPL;ILLUMINA\tLB:$SAMPLE\tSM:$SAMPLE"'"'


RG="@RG\tID:${SAMPLE}_ID\tSM:$SAMPLE\tPL:ILLUMINA"
echo $START_TIME
echo "Read group: $RG"

if [ $SKIP_BAM -eq 0 ]; then
	#allocate more memory
	export bwt_max_mem=110G

	(sentieon bwa mem -R "@RG\tID:"$SAMPLE"\tSM:"$SAMPLE"\tPL:ILLUMINA" \
	    -t $NUMBER_THREADS $REF_FASTA $R1_FASTQ $R2_FASTQ || echo -n 'error' ) \
	    | sentieon util sort -r $REF_FASTA -o $SORTED_BAM -t $NUMBER_THREADS --sam2bam -i -

	if [ $SKIP_TRIMMOMATIC -eq 0 ] && [ -f $SORTED_BAM ]; then
	    rm ${SAMPLE}_trimmomatic_log.txt
	    rm $R1_FASTQ $R2_FASTQ
	    rm $UNPAIRED_R1_FASTQ $UNPAIRED_R2_FASTQ
	fi
	echo "### Aligning fastqs Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS


	echo "### Calculate and plot data metrics Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS
    # sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $SORTED_BAM \
    #     --algo GCBias --summary ${SAMPLE}_GC_summary.txt ${SAMPLE}_GC_metric.txt \
    #     --algo MeanQualityByCycle ${SAMPLE}_MQ_metric.txt \
    #     --algo QualDistribution ${SAMPLE}_QD_metric.txt \
    #     --algo InsertSizeMetricAlgo ${SAMPLE}_IS_metric.txt \
    #     --algo AlignmentStat ${SAMPLE}_ALN_metric.txt
    
    # sentieon plot GCBias -o ${SAMPLE}_QC_metric.pdf ${SAMPLE}_GC_metric.txt
    # sentieon plot MeanQualityByCycle -o ${SAMPLE}_MQ_metric.pdf ${SAMPLE}_MQ_metric.txt
    # sentieon plot QualDistribution -o ${SAMPLE}_QD_metric.pdf ${SAMPLE}_QD_metric.txt
    # sentieon plot InsertSizeMetricAlgo -o ${SAMPLE}_IS_metric.pdf ${SAMPLE}_IS_metric.txt
	echo "### Calculate and plot data metrics Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS


	echo "### Mark duplicates Sample: $SAMPLE ### - START: $(date)"
	sentieon driver -t $NUMBER_THREADS -i $SORTED_BAM \
	    --algo LocusCollector --fun score_info ${SAMPLE}_score.gz
	sentieon driver -t $NUMBER_THREADS -i $SORTED_BAM \
	    --algo Dedup --score_info ${SAMPLE}_score.gz \
	    --metrics ${SAMPLE}.duplication_metrics.tsv $DEDUPED_BAM
	echo "### Mark duplicates Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS


	echo "### Indel realignment Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS
	sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
	    -i $DEDUPED_BAM --algo Realigner --interval_list $TARGETS_BED $REALIGNED_BAM
	echo "### Indel realignment Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS


	echo "### Base quality score recalibration Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS
	sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
	    -i $REALIGNED_BAM --algo QualCal ${SAMPLE}_recal_data.table
	sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $REALIGNED_BAM \
	    -q ${SAMPLE}_recal_data.table --algo QualCal \
	    ${SAMPLE}_recal_data.table.after --algo ReadWriter $RECALIBRATED_BAM
	sentieon driver -t $NUMBER_THREADS --algo QualCal --plot \
	    --before ${SAMPLE}_recal_data.table --after ${SAMPLE}_recal_data.table.after ${SAMPLE}_recal_result.csv
	sentieon plot QualCal -o ${SAMPLE}_BQSR_PDF ${SAMPLE}_recal_result.csv
	echo "### Base quality score recalibration Sample: $SAMPLE ### - END: $(date)" >> $SENTIEON_STATUS
fi