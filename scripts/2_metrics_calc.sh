#!/bin/bash
#
#SBATCH --job-name=2_metrics_calc
#SBATCH --cpus-per-task=2
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=31G
#SBATCH --nodes=1

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --scratch_dir )         shift
                                SCRATCH_DIR=$1
                                ;;
        --script_dir )          shift
                                SCRIPT_DIR=$1
                                ;;
        --tools_dir )           shift
                                TOOLS_DIR=$1
                                ;;
        --ref_fasta ) 	        shift
                                REF_FASTA=$1
                                ;;
        --sample_string )       shift
                                SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                                ;;
        --targeted )            shift
                                TARGETED=$1
                                ;;
        --targets_bed )         shift
                                TARGETS_BED=$1
                                ;;
        --interval_list )       shift
                                INTERVAL_LIST=$1
                                ;;
        --bam_suffix )          shift
                                BAM_SUFFIX=$1
                                ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $SCRIPT_DIR ] || [ -z $TOOLS_DIR ] || [ -z $REF_FASTA ] || \
    [ -z $SAMPLE_ARRAY ] || [ -z $TARGETED ] || [ -z $TARGETS_BED ] || [ -z $INTERVAL_LIST ]; then
    echo "Variables not supplied correctly. Check script for intake parameters. All are required to be specified. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $SCRATCH_DIR

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
N25CHR_INTERVAL_LIST="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.bed"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
QUALIMAP_TOOL="${TOOLS_DIR}/qualimap_v2.2.1/qualimap"
PRESEQ_TOOL_DIR="${TOOLS_DIR}/preseq"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_5col.interval_list"
VARIANT_VCF="${SAMPLE}.g.vcf"

ml gcc/12.1.0 gsl/2.3 java/1.8.0_131 biology htslib samtools bedtools gatk
ml biology bcftools/1.6 sentieon/202112.01

export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=license4.stanford.edu:5443

echo "### Calculating QC metrics Sample: $SAMPLE ### - START: $(date)"
TOTAL_READS=$(samtools view -c ${SAMPLE}${BAM_SUFFIX})
FRACTION=$(awk -v y="$TOTAL_READS" 'BEGIN {printf "%3f", 5000000 / y}')
if [ $TOTAL_READS -ge 5000000 ] && [ ! -z $FRACTION ] && [ $TARGETED -eq 0 ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31g -Xms31G" DownsampleSam \
        -I ${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.5M.bam \
        --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT \
        --MAX_RECORDS_IN_RAM 5500000
    echo "Downsampling for 5 million reads done"
    samtools index ${SAMPLE}.5M.bam
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.wgs_5M_read_coverage.tsv
    bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${SAMPLE}.5M.bam >> ${SAMPLE}.5M.read_coverage.tsv
    echo "Coverage for 5 million reads done"

    samtools view -b -L $N25CHR_BED ${SAMPLE}.5M.bam > ${SAMPLE}.5M.n25chr.bam
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}.5M.n25chr.unsorted.mr ${SAMPLE}.5M.n25chr.bam
    sort -k1,1 -k2,2n -k3,3n ${SAMPLE}.5M.n25chr.unsorted.mr > ${SAMPLE}.5M.n25chr.sorted.mr
    if [ ! -f ${SAMPLE}.5M.n25chr.sorted.mr ]; then
        echo "Problem making ${SAMPLE}.5M.n25chr.sorted.mr, cannot run PreSeq for 5 million reads"
    else
        $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}.5M.preseq_future_coverage.tsv ${SAMPLE}.5M.n25chr.sorted.mr
        rm ${SAMPLE}.5M.n25chr.bam* ${SAMPLE}.5M.n25chr.unsorted.mr* ${SAMPLE}.5M.n25chr.sorted.mr*
        if [ ! -f ${SAMPLE}.5M.preseq_future_coverage.tsv ]; then
            echo "Problem making ${SAMPLE}.5M.preseq_future_coverage.tsv, PreSeq for 5 million reads failed"
        else
            echo "PreSeq for 5 million reads done"
        fi
    fi
else
    echo "Bam has $TOTAL_READS reads, cannot downsample to 5 million reads"
fi

if [ $TARGETED -eq 0 ]; then
    samtools view -b -L $N25CHR_BED ${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}.n25chr.bam
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}.n25chr.unsorted.mr ${SAMPLE}.n25chr.bam
    sort -k1,1 -k2,2n -k3,3n ${SAMPLE}.n25chr.unsorted.mr > ${SAMPLE}.n25chr.sorted.mr
    if [ ! -f ${SAMPLE}.n25chr.sorted.mr ]; then
        echo "Problem making ${SAMPLE}.n25chr.sorted.mr, cannot run PreSeq for whole sample"
    else
        $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}.preseq_future_coverage.tsv ${SAMPLE}.n25chr.sorted.mr
        rm ${SAMPLE}.n25chr.bam* ${SAMPLE}.n25chr.unsorted.mr* ${SAMPLE}.n25chr.sorted.mr*
        if [ ! -f ${SAMPLE}.preseq_future_coverage.tsv ]; then
            echo "Problem making ${SAMPLE}.preseq_future_coverage.tsv, PreSeq for whole sample failed"
        else
            echo "PreSeq for whole sample done"
        fi
    fi
fi

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
    if [ -f ${SAMPLE}.5M.bam ]; then
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.targeted_5M_read_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${SAMPLE}.5M.bam >> ${SAMPLE}.targeted_5M_read_coverage.tsv
    echo "5 million read targeted coverage done"
    fi

    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.targeted_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${BAM_NAME} >> ${SAMPLE}.targeted_coverage.tsv
    echo "Exome coverage done"
fi
echo "Calculating QC metric"

mkdir -p ${SAMPLE}_temp_qualimap_output
$QUALIMAP_TOOL bamqc -nt 4 -nw 3000 --java-mem-size=31G -bam ${BAM_NAME} -gff $N25CHR_BED \
    -c -hm 3 -outdir ${SCRATCH_DIR}/${SAMPLE}_temp_qualimap_output -outformat PDF
if [ ! -f ${SAMPLE}_temp_qualimap_output/report.pdf ]; then
    echo "QualiMap encountered a problem and did not complete"
else
    ml system poppler/0.47.0
    pdfseparate -f 1 -l 6 ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}_temp_qualimap_output/pages1-%d.pdf
    pdfseparate -f 284 -l 296 ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}_temp_qualimap_output/pages2-%d.pdf
    pdfunite ${SAMPLE}_temp_qualimap_output/pages*.pdf ${SAMPLE}.multiple_metrics.qualimap_report.pdf
    # mv ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}.multiple_metrics.qualimap_report.pdf
    mv ${SAMPLE}_temp_qualimap_output/genome_results.txt ${SAMPLE}.multiple_metrics.qualimap_genome_results.txt
    echo "QualiMap done"
fi
rm -r ${SAMPLE}_temp_qualimap_output

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

echo "###Calculating QC METRICS Done #### Sample: $SAMPLE Time: $(date)"

echo -e "END: $(date)\nRuntime: $(($(date +%s) $START_TIME)) seconds"