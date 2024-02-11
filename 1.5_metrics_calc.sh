#!/bin/bash
#
#SBATCH --job-name=1.5_metrics_calc
#SBATCH --cpus-per-task=2
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=31G
#SBATCH --nodes=1

while [ "$1" != "" ]; do
    case $1 in
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
	--skip_trimmomatic ) shift
		  	    SKIP_TRIMMOMATIC=$1
			    ;;
	--script_dir )      shift
			    SCRIPT_DIR=$1
			    ;;
	--tools_dir )       shift
			    TOOLS_DIR=$1
			    ;;
	--r1_suffix )       shift
	 		    R1_SUFFIX=$1
			    ;;
	--r2_suffix )       shift
			    R2_SUFFIX=$1
			    ;;
	--ref_fasta ) 	    shift
	   	  	    REF_FASTA=$1
			    ;;
	--number_threads )  shift
			    NUMBER_THREADS=$1
			    ;;
	--sample_string )   shift
			    SAMPLE_STRING=$1
			    ;;
	--fastq_dir ) 	    shift
			    FASTQ_DIR=$1
			    ;;
	--dbSNP ) 	    shift
			    dbSNP=$1
			    ;;
	--project ) 	    shift
			    PROJECT=$1
			    ;;
	--skip_bam ) 	    shift
			    SKIP_BAM=$1
			    ;;
	--targeted )        shift
			    TARGETED=$1
			    ;;
	--std_err_out_dir ) shift
			    STD_ERR_OUT_DIR=$1
			    ;;
	--targets_bed )     shift
			    TARGETS_BED=$1
			    ;;
	--interval_list )   shift
			    INTERVAL_LIST=$1
			    ;;
    esac
    shift
done

SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE_NAME=${SAMPLE%.recalibrated_realigned_deduped_sorted.bam}
SAMPLE=${SAMPLE_NAME}

echo "TARGETED is $TARGETED"
echo "TARGETS_BED is $TARGETS_BED"
echo "INTERVAL_LIST is $INTERVAL_LIST"

echo "1 is: $1, 2 is $2, 3 is: $3, 4 is: $4, 5 is $5, 6 is $6, 7 is $7, 8 is $8, 9 is $9, 10 is ${10}, 11 is ${11}, 13 is ${13}, 14 is ${14}, 15 is ${15}, 16 is ${16}"

SENTIEON_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_sentieon_status.txt

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"

N25CHR_INTERVAL_LIST="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.interval_list"
#N25CHR_BED="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr_fixed2.bed"
N25CHR_BED="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.bed"
echo "FASTQ_DIR IS "{FASTQ_DIR}
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
QUALIMAP_TOOL="${TOOLS_DIR}/qualimap_v2.2.1/qualimap"
PRESEQ_TOOL_DIR="${TOOLS_DIR}/preseq"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"


COUNTER=0
for i in "${SAMPLE_ARRAY[@]}"
do
  echo "Sample number $COUNTER is $i"
  COUNTER=$((COUNTER+1))
done


echo "TASK_ID is $SLURM_ARRAY_TASK_ID"
echo "SAMPLE about to be worked on is $SAMPLE"

BAM="${SAMPLE}.bam"
SORTED_BAM="${SAMPLE}.sorted.bam"
DEDUPED_BAM="${SAMPLE}.deduped_sorted.bam"
REALIGNED_BAM="${SAMPLE}.realigned_deduped_sorted.bam"
RECALIBRATED_BAM="${SAMPLE}.recalibrated_realigned_deduped_sorted.bam"
VARIANT_VCF="${SAMPLE}.g.vcf"
BAM_SUFFIX=".bqsr.bam"
BAM_NAME=${RECALIBRATED_BAM}
echo -e "START: $(date)\nSentieon Pipeline\nResults dir: $RESULTS_DIR\nSample: $SAMPLE\nRef fasta: $REF_FASTA" >> $SENTIEON_STATUS
cd $RESULTS_DIR

#ml gsl/2.3
#ml java/1.8.0_131
#ml R/4.0.2 java biology samtools bedtools gatk bcftools
#ml biology bwa samtools java

ml gcc/12.1.0 gsl/2.3 java/1.8.0_131 biology htslib samtools bedtools gatk
ml biology bcftools/1.6 sentieon/202112.01

export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

R1_FASTQ=${FASTQ_DIR}"/"${SAMPLE}${R1_SUFFIX}
R2_FASTQ=${FASTQ_DIR}"/"${SAMPLE}${R2_SUFFIX}

echo "### Aligning fastqs Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS

#PLATFORM is the sequencing machine (usually ILLUMINA), sample is the sample name
#-R "@RG\tID:$id\tPL:ILLUMINA\tLB:$lb\tSM:$sm"
#'"'"@RG\tID:$SAMPLE\tPL;ILLUMINA\tLB:$SAMPLE\tSM:$SAMPLE"'"'


RG="@RG\tID:${SAMPLE}_ID\tSM:$SAMPLE\tPL:ILLUMINA"
echo "Read group: $RG"

cd ${RESULTS_DIR}
echo "### Calculating QC metrics Sample: $SAMPLE ### - START: $(date)" >> $SENTIEON_STATUS
#	if [ $TARGETED -eq 1 ]; then
#	    echo "start Hs metrics: $(date)"

EXOME_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_5col.interval_list"

## this block of code is meant to downsample to 5 mil for exomes 500 mil for whole genomes, and compute preseq for miniseq runs
BAM_5M_SUFFIX=".5M.bam" 
TOTAL_READS=$(samtools view -c ${RECALIBRATED_BAM})
echo total reads is $TOTAL_READS
echo "start 5M read coverage stuff: $(date)"
if [ $TOTAL_READS -ge 5000000 ] && [ $TARGETED -eq 1]; then
    FRACTION=$(awk -v y="$TOTAL_READS" 'BEGIN {printf "%3f", 5000000 / y}')
    BAM_NAME=${SAMPLE}_subsampled_exome.bam
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31g -Xms31G" DownsampleSam \
    -I ${RECALIBRATED_BAM} -O ${BAM_NAME} \
    --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT \
    --MAX_RECORDS_IN_RAM 5500000
    echo "5M downsample done"
    samtools index ${BAM_NAME}
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.wgs_5M_read_coverage.tsv
    bedtools coverage -g $REF_GENOME -sorted -a $TARGETS_BED -b ${BAM_NAME} >> ${SAMPLE}.wes_5M_read_coverage.tsv
    echo "5 million read coverage done"

    samtools view -b -L $N25CHR_BED ${SAMPLE}_subsampled_exome.bam > ${SAMPLE}_subsampled_exome.n25chr.bam
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}_subsampled_exome.n25chr.unsorted.mr ${SAMPLE}_subsampled_exome.n25chr.bam
    sort -k1,1 -k2,2n -k3,3n ${SAMPLE}_subsampled_exome.n25chr.unsorted.mr > ${SAMPLE}_subsampled_exome.n25chr.sorted.mr
    if [ ! -f ${SAMPLE}_subsampled_exome.n25chr.sorted.mr ]; then
        echo "Problem making ${SAMPLE}_subsampled_exome.n25chr.sorted.mr, cannot run PreSeq for 5M"
    else
        $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}_subsampled_exome.gc_extrap.future_coverage.tsv ${SAMPLE}_subsampled_exome.n25chr.sorted.mr
        rm ${SAMPLE}_subsampled_exome.n25chr.bam* ${SAMPLE}_subsampled_exome.n25chr.unsorted.mr* ${SAMPLE}_subsampled_exome.n25chr.sorted.mr*
        if [ ! -f ${SAMPLE}_subsampled_exome.gc_extrap.future_coverage.tsv ]; then
            echo "Problem making ${SAMPLE}.gc_extrap.future_coverage.tsv, PreSeq for 5M failed"
        else
            echo "PreSeq for 5M done"
        fi
    fi
else
    echo "Either a WGS BAM or WES Bam is less than 5 million reads, cannot downsample"
fi

echo "preseq stuff: $(date)"
if [ $TOTAL_READS -le 5000000 ]; then
    samtools view -b -L $N25CHR_BED ${SAMPLE}.recalibrated_realigned_deduped_sorted.bam > ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.bam
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.unsorted.mr ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.bam
    sort -k1,1 -k2,2n -k3,3n ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.unsorted.mr > ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.sorted.mr
    if [ ! -f ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.sorted.mr ]; then
        echo "Problem making ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.sorted.mr, cannot run PreSeq for 5M"
    else
        $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}.recalibrated_realigned_deduped_sorted.gc_extrap.future_coverage.tsv ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.sorted.mr
        rm ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.bam* ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.unsorted.mr* ${SAMPLE}.recalibrated_realigned_deduped_sorted.n25chr.sorted.mr*
        if [ ! -f ${SAMPLE}.recalibrated_realigned_deduped_sorted.gc_extrap.future_coverage.tsv ]; then
            echo "Problem making ${SAMPLE}.recalibrated_realigned_deduped_sorted.gc_extrap.future_coverage.tsv, PreSeq for 5M failed"
        else
            echo "PreSeq for 5M done"
        fi
    fi    
else
    echo "BAM is larger than 5M reads. Will not compute PreSeq"
fi
	
# 	echo "downsample for non miniseq WGS as well (get coverage too)"
if [ $TOTAL_READS -ge 500000000 ] && [ $TARGETED -eq 0]; then
    FRACTION=$(awk -v y="$TOTAL_READS" 'BEGIN {printf "%3f", 500000000 / y}')

    BAM_NAME=${SAMPLE}_subsampled_wgs.bam
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31g -Xms31G" DownsampleSam \
    -I ${RECALIBRATED_BAM} -O ${BAM_NAME} \
    --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT \
    --MAX_RECORDS_IN_RAM 5500000
    echo "500M downsample done"
    samtools index ${BAM_NAME}
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.wgs_500M_read_coverage.tsv
    bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${BAM_NAME} >> ${SAMPLE}.wgs_500M_read_coverage.tsv
    echo "500 million read coverage done"
else
    echo "WGS Bam is less than 500 million reads, cannot downsample"
fi
###

#samtools view -b -L $N25CHR_BED ${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}.bqsr.marked.n25chr.bam
#echo "Bam restriction to canonical 25 chr region done"
bedtools bamtobed -i ${BAM_NAME} | cut -f 1-3 > ${SAMPLE}.bqsr.marked.n25chr.bed
echo "Bam to bed conversion done"
echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.wgs_coverage.tsv
bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${SAMPLE}.bqsr.marked.n25chr.bed >> ${SAMPLE}.wgs_coverage.tsv
echo "Coverage done"

gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectHsMetrics \
-I ${BAM_NAME} -O ${SAMPLE}.hs_metrics.tsv -R $REF_FASTA \
-BI $EXOME_INTERVAL_LIST -TI $EXOME_INTERVAL_LIST --VALIDATION_STRINGENCY SILENT \
--MAX_RECORDS_IN_RAM 3500000
echo "CollectHsMetrics done"
    
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectWgsMetrics \
-I ${BAM_NAME} -O ${SAMPLE}.wgs_metrics.tsv \
-R $REF_FASTA --VALIDATION_STRINGENCY SILENT --INTERVALS $INTERVAL_LIST \
--MAX_RECORDS_IN_RAM 3500000
echo "CollectWgsMetrics done"
    
echo "start CollectBaseDist: $(date)"
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectMultipleMetrics \
    -I ${BAM_NAME} -O ${SAMPLE}.multiple_metrics --INTERVALS $INTERVAL_LIST \
    -R $REF_FASTA --VALIDATION_STRINGENCY SILENT --PROGRAM CollectAlignmentSummaryMetrics \
    --PROGRAM CollectBaseDistributionByCycle --PROGRAM CollectInsertSizeMetrics --PROGRAM MeanQualityByCycle \
    --PROGRAM QualityScoreDistribution --PROGRAM CollectGcBiasMetrics --FILE_EXTENSION .tsv \
    --MAX_RECORDS_IN_RAM 3500000
echo "CollectMultipleMetrics done"
echo "start CollectOxoGMetrics: $(date)"
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectOxoGMetrics \
    -I ${BAM_NAME} -O ${SAMPLE}.oxog_metrics.tsv -R $REF_FASTA \
    --VALIDATION_STRINGENCY SILENT --INTERVALS $INTERVAL_LIST \
    --MAX_RECORDS_IN_RAM 3500000
echo "CollectOxoGMetrics done"

	

if [ $TARGETED -eq 1 ]; then
    if [ -f ${SAMPLE}${BAM_5M_SUFFIX} ]; then
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.targeted_5M_read_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${SAMPLE}${BAM_5M_SUFFIX} >> ${SAMPLE}.targeted_5M_read_coverage.tsv
    echo "5 million read targeted coverage done"
    fi

    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.targeted_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${BAM_NAME} >> ${SAMPLE}.targeted_coverage.tsv
    echo "Exome coverage done"
fi
echo "Calculating QC metric"


#	rm -r split_aligning_${SAMPLE}
#	rm ${SAMPLE}.rg.bam* ${SAMPLE}.bqsr ${SAMPLE}.marked.bam*
#	rm ${SAMPLE}.bqsr.marked.n25chr.bam* ${SAMPLE}.bqsr.marked.n25chr.bed
#	rm *pre.bam
	# rm -rf `pwd`/tmp*

mkdir "${RESULTS_DIR}/${SAMPLE}_temp_qualimap_output"
echo "made the qualimap directory"
echo "${QUALIMAP_TOOL} is the qualimap tool"

$QUALIMAP_TOOL bamqc -nt 4 -nw 3000 --java-mem-size=31G -bam ${BAM_NAME} -gff $N25CHR_BED \
    -c -hm 3 -outdir ${RESULTS_DIR}/${SAMPLE}_temp_qualimap_output -outformat PDF

#Temporarily removed bed input for testing since its not working with the bed input
	#$QUALIMAP_TOOL bamqc -nt 4 -nw 3000 --java-mem-size=55G -bam ${BAM_NAME} -gff $N25CHR_BED \
	#    -c -hm 3 -outdir ${RESULTS_DIR}/${SAMPLE}_temp_qualimap_output -outformat PDF
if [ ! -f ${SAMPLE}_temp_qualimap_output/report.pdf ]; then
    echo "QualiMap encountered a problem and did not complete"
else
    ml system poppler/0.47.0
    pdfseparate -f 1 -l 6 ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}_temp_qualimap_output/pages1-%d.pdf
    pdfseparate -f 284 -l 296 ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}_temp_qualimap_output/pages2-%d.pdf
    pdfunite ${SAMPLE}_temp_qualimap_output/pages*.pdf `pwd`/${SAMPLE}.multiple_metrics.qualimap_report.pdf
    # mv ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}.multiple_metrics.qualimap_report.pdf
    mv ${SAMPLE}_temp_qualimap_output/genome_results.txt `pwd`/${SAMPLE}.multiple_metrics.qualimap_genome_results.txt
	echo "QualiMap done"
fi

rm -rf *_temp_qualimap_output

mkdir Mosdepth_Results
MOSDEPTH="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
MOSDEPTH_REF_DIR="/oak/stanford/groups/cgawad/Reference_Files/mosdepth_hg38"
ECDNA="${MOSDEPTH_REF_DIR}/ecDNA_2_sorted.bed"
ENHANCERS="${MOSDEPTH_REF_DIR}/NA12878_enhancers_grch38_s.bed"
XGEN_EXOME="${MOSDEPTH_REF_DIR}/xgen-exome-research-panel-targets_grch38_6col_s.bed"
PROMOTERS="${MOSDEPTH_REF_DIR}/Promoters_GrCh38_s.bed"
MICROSATELLITES="${MOSDEPTH_REF_DIR}/microsatellite_s.bed"
CpGI="${MOSDEPTH_REF_DIR}/CPG_Islands_s.bed"
REPEATS="${MOSDEPTH_REF_DIR}/repeats_grch38_s.bed"
MOS_RESULTS_DIR=`pwd`/Mosdepth_Results

#not 100% sure if mosdepth should also use the downsampled BAMs, will replace here too tho

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $ECDNA ${MOS_RESULTS_DIR}/${SAMPLE}.ecDNA ${BAM_NAME}

zcat ${MOS_RESULTS_DIR}/${SAMPLE}.ecDNA.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.ecDNA.thresholds
echo "ecDNA done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $MICROSATELLITES ${MOS_RESULTS_DIR}/${SAMPLE}.microsatellite ${BAM_NAME}

zcat ${MOS_RESULTS_DIR}/${SAMPLE}.microsatellite.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.microsatellite.thresholds
echo "Microsatellites done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $CpGI ${MOS_RESULTS_DIR}/${SAMPLE}.CpGI ${BAM_NAME}

zcat ${MOS_RESULTS_DIR}/${SAMPLE}.CpGI.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.CpGI.thresholds
echo "CpGIs done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $REPEATS ${MOS_RESULTS_DIR}/${SAMPLE}.repeats ${BAM_NAME}

zcat ${MOS_RESULTS_DIR}/${SAMPLE}.repeats.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.repeats.thresholds
echo "repeats done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $ENHANCERS ${MOS_RESULTS_DIR}/${SAMPLE}.enhancers ${BAM_NAME}

zcat ${MOS_RESULTS_DIR}/${SAMPLE}.enhancers.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.enhancers.thresholds
echo "enhancers done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $XGEN_EXOME ${MOS_RESULTS_DIR}/${SAMPLE}.exome ${BAM_NAME}

zcat ${MOS_RESULTS_DIR}/${SAMPLE}.exome.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.exome.thresholds
echo "exome done"

echo "###Calculating QC METRICS Done #### Sample: $SAMPLE Time: $(date)" >> $SENTIEON_STATUS

echo -e "END: $(date)\nRuntime: $(($(date +%s) $START_TIME)) seconds"