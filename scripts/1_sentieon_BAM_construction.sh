#!/bin/bash
#
#SBATCH --job-name=1_sentieon_BAM_construction
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
        --skip_trimmomatic )        shift
                                    SKIP_TRIMMOMATIC=$1
                                    ;;
        --tools_dir )               shift
                                    TOOLS_DIR=$1
                                    ;;
        --R1_suffix )               shift
                                    R1_SUFFIX=$1
                                    ;;
        --R2_suffix )               shift
                                    R2_SUFFIX=$1
                                    ;;
        --ref_fasta )               shift
                                    REF_FASTA=$1
                                    ;;
        --ref_name )                shift
                                    REF_NAME=$1
                                    ;;
        --sample_string )           shift
                                    SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                                    ;;
        --fastq_dir )               shift
                                    FASTQ_DIR=$1
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

if [ -z $SCRATCH_DIR ] || [ -z $SKIP_TRIMMOMATIC ] || [ -z $TOOLS_DIR ] || [ -z $R1_SUFFIX ] || \
    [ -z $R2_SUFFIX ] || [ -z $REF_FASTA ] || [ -z $REF_NAME ] || [ -z $SAMPLE_ARRAY ] || \
    [ -z $FASTQ_DIR ] || [ -z $TARGETS_BED ] || [ -z $RNA ] || [ -z $BAM_SUFFIX ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $SCRATCH_DIR

NUMBER_THREADS=16
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
QUALIMAP_TOOL="${TOOLS_DIR}/qualimap_v2.2.1/qualimap"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"
SAMPLE=${SAMPLE%$R1_SUFFIX}
SAMPLE_NAME=${SAMPLE}

if [ $RNA -eq 1 ]; then
    BAM="${SAMPLE}.rna.bam"
    SORTED_BAM="${SAMPLE}.rna.sorted.bam"
    DEDUPED_BAM="${SAMPLE}.rna.deduped_sorted.bam"
    REALIGNED_BAM="${SAMPLE}.rna.realigned_deduped_sorted.bam"
    RECALIBRATED_BAM="${SAMPLE}${BAM_SUFFIX}"
    VARIANT_VCF="${SAMPLE}.g.vcf"
else
    BAM="${SAMPLE}.bam"
    SORTED_BAM="${SAMPLE}.sorted.bam"
    DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
    REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
    RECALIBRATED_BAM="${SAMPLE}${BAM_SUFFIX}"
    VARIANT_VCF="${SAMPLE}.g.vcf"
fi

ml gsl/2.3 java/1.8.0_131
ml biology bwa samtools bedtools gatk bcftools sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=license4.stanford.edu:5443

R1_FASTQ=${FASTQ_DIR}/${SAMPLE}${R1_SUFFIX}
R2_FASTQ=${FASTQ_DIR}/${SAMPLE}${R2_SUFFIX}


echo "### Counting fastq read counts Sample: $SAMPLE ### - START: $(date)"
READ_COUNT=$(echo $(zcat $R1_FASTQ | wc -l ) \
    $(zcat $R2_FASTQ | wc -l) | awk '{ print ($1 + $2) / 4 }' )
echo -e "sample\tread_count" > $SCRATCH_DIR/${SAMPLE}_read_counts.tsv
echo -e "$SAMPLE\t$READ_COUNT" >> $SCRATCH_DIR/${SAMPLE}_read_counts.tsv
echo "### Counting fastq read counts Sample: $SAMPLE ### - END: $(date)"


if [ $SKIP_TRIMMOMATIC -eq 0 ]; then
    UNTRIMMED_R1_FASTQ=$R1_FASTQ
    UNTRIMMED_R2_FASTQ=$R2_FASTQ
    R1_FASTQ=$(echo $UNTRIMMED_R1_FASTQ | sed "s/_R1/_R1_trimmed/")
    R2_FASTQ=$(echo $UNTRIMMED_R2_FASTQ | sed "s/_R2/_R2_trimmed/")
    UNPAIRED_R1_FASTQ=$(echo $UNTRIMMED_R1_FASTQ | sed "s/_R1/_R1_trimmed_unpaired/")
    UNPAIRED_R2_FASTQ=$(echo $UNTRIMMED_R2_FASTQ | sed "s/_R2/_R2_trimmed_unpaired/")

    echo "### Trimming fastqs Sample: $SAMPLE ### - START: $(date)"
    java -jar ${TOOLS_DIR}/Trimmomatic-0.35/trimmomatic-0.35.jar PE -threads 16 -phred33 -trimlog \
        ${SAMPLE}_trimmomatic_log.txt \
        $UNTRIMMED_R1_FASTQ $UNTRIMMED_R2_FASTQ \
        $R1_FASTQ $UNPAIRED_R1_FASTQ \
        $R2_FASTQ $UNPAIRED_R2_FASTQ \
        ILLUMINACLIP:${TOOLS_DIR}/Trimmomatic-0.35/adapters/TruSeq3-PE-2.fa:2:30:10:2:keepBothReads \
        LEADING:20 TRAILING:20 SLIDINGWINDOW:4:20 MINLEN:36
    echo "### Trimming fastqs Sample: $SAMPLE ### - END: $(date)"
else
    R1_FASTQ=${FASTQ_DIR}/${SAMPLE}${R1_SUFFIX}
    R2_FASTQ=${FASTQ_DIR}/${SAMPLE}${R2_SUFFIX}
fi


if [ $RNA -eq 1 ]; then
    ml python/3.6.1 java/11.0.11
    ml biology star/2.5.4b
    echo "### Aligning RNA fastqs to $REF_NAME ### - START: $(date)"
    UNZIPPED_R1_FASTQ=$(basename $R1_FASTQ | sed "s/.gz//")
    UNZIPPED_R2_FASTQ=$(basename $R2_FASTQ | sed "s/.gz//")
    zcat $R1_FASTQ > $UNZIPPED_R1_FASTQ
    zcat $R2_FASTQ > $UNZIPPED_R2_FASTQ
    STAR --genomeDir \
        /oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/hg38_STAR_index/ \
        --readFilesIn $UNZIPPED_R1_FASTQ $UNZIPPED_R2_FASTQ \
        --runThreadN 4 \
        --outFileNamePrefix $SAMPLE \
        --outSAMtype BAM SortedByCoordinate \
        --outSAMunmapped Within \
        --outSAMattributes Standard
    rm $UNZIPPED_R1_FASTQ $UNZIPPED_R2_FASTQ
    mv ${SAMPLE}Aligned.sortedByCoord.out.bam $SORTED_BAM
    samtools index $SORTED_BAM
    echo "### Aligning RNA fastqs to $REF_NAME ### - END: $(date)"
    
    ml java/1.8.0_131
else
    echo "### Aligning DNA fastqs to $REF_NAME ### - START: $(date)"
    # PLATFORM is the sequencing machine (usually ILLUMINA), sample is the sample name
    # -R "@RG\tID:$id\tPL:ILLUMINA\tLB:$lb\tSM:$sm"
    # '"'"@RG\tID:$SAMPLE\tPL;ILLUMINA\tLB:$SAMPLE\tSM:$SAMPLE"'"'
    RG="@RG\tID:${SAMPLE}_ID\tSM:$SAMPLE\tPL:ILLUMINA"

    # Allocate more memory
    export bwt_max_mem=62G

    (sentieon bwa mem -R "@RG\tID:"$SAMPLE"\tSM:"$SAMPLE"\tPL:ILLUMINA" \
        -t $NUMBER_THREADS $REF_FASTA $R1_FASTQ $R2_FASTQ || echo -n 'error' ) \
        | sentieon util sort -r $REF_FASTA -o $SORTED_BAM -t $NUMBER_THREADS --sam2bam -i -
    echo "### Aligning DNA fastqs to $REF_NAME ### - END: $(date)"
fi


# echo "### Calculate and plot data metrics ### - START: $(date)"
# sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $SORTED_BAM \
#     --algo GCBias --summary ${SAMPLE}_GC_summary.txt ${SAMPLE}_GC_metric.txt \
#     --algo MeanQualityByCycle ${SAMPLE}_MQ_metric.txt \
#     --algo QualDistribution ${SAMPLE}_QD_metric.txt \
#     --algo InsertSizeMetricAlgo ${SAMPLE}_IS_metric.txt \
#     --algo AlignmentStat ${SAMPLE}_ALN_metric.txt
# 
# sentieon plot GCBias -o ${SAMPLE}_QC_metric.pdf ${SAMPLE}_GC_metric.txt
# sentieon plot MeanQualityByCycle -o ${SAMPLE}_MQ_metric.pdf ${SAMPLE}_MQ_metric.txt
# sentieon plot QualDistribution -o ${SAMPLE}_QD_metric.pdf ${SAMPLE}_QD_metric.txt
# sentieon plot InsertSizeMetricAlgo -o ${SAMPLE}_IS_metric.pdf ${SAMPLE}_IS_metric.txt
# echo "### Calculate and plot data metrics ### - END: $(date)"


echo "### Mark duplicates ### - START: $(date)"
sentieon driver -t $NUMBER_THREADS -i $SORTED_BAM \
    --algo LocusCollector --fun score_info ${SAMPLE}_score.gz
sentieon driver -t $NUMBER_THREADS -i $SORTED_BAM \
    --algo Dedup --score_info ${SAMPLE}_score.gz \
    --metrics ${SAMPLE}_duplication_metrics.tsv $DEDUPED_BAM
echo "### Mark duplicates ### - END: $(date)"


echo "### Indel realignment ### - START: $(date)"
sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
    -i $DEDUPED_BAM --algo Realigner --interval_list $TARGETS_BED $REALIGNED_BAM
echo "### Indel realignment ### - END: $(date)"


echo "### Base quality score recalibration ### - START: $(date)"
sentieon driver -t $NUMBER_THREADS -r $REF_FASTA \
    -i $REALIGNED_BAM --algo QualCal ${SAMPLE}_recal_data.table
sentieon driver -t $NUMBER_THREADS -r $REF_FASTA -i $REALIGNED_BAM \
    -q ${SAMPLE}_recal_data.table --algo QualCal \
    ${SAMPLE}_recal_data.table.after --algo ReadWriter $RECALIBRATED_BAM
sentieon driver -t $NUMBER_THREADS --algo QualCal --plot \
    --before ${SAMPLE}_recal_data.table --after ${SAMPLE}_recal_data.table.after ${SAMPLE}_recal_result.csv
sentieon plot QualCal -o ${SAMPLE}_bqsr.pdf ${SAMPLE}_recal_result.csv
echo "### Base quality score recalibration ### - END: $(date)"


if [ ! -f $RECALIBRATED_BAM ]; then
    echo "Final file $RECALIBRATED_BAM not found. Exiting with code 1"
    exit 1
fi
if [ $SKIP_TRIMMOMATIC -eq 0 ] && [ -f $SORTED_BAM ]; then
    rm ${SAMPLE}_trimmomatic_log.txt
    rm $R1_FASTQ $R2_FASTQ
    rm $UNPAIRED_R1_FASTQ $UNPAIRED_R2_FASTQ
fi
rm $BAM ${BAM}.bai $REALIGNED_BAM ${REALIGNED_BAM}.bai
mv ${SAMPLE}_score.gz* Extra_Sentieon_Files/
mv ${SAMPLE}_bqsr.pdf Extra_Sentieon_Files/
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"