#!/bin/bash
#
#SBATCH --job-name=2_metrics_calc
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=31G
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

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
    [ -z $SAMPLE_ARRAY ] || [ -z $TARGETED ] || [ -z $TARGETS_BED ] || [ -z $INTERVAL_LIST ] || \
    [ -z $BAM_SUFFIX ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $SCRATCH_DIR

REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
N25CHR_INTERVAL_LIST="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.bed"
QUALIMAP_TOOL="${TOOLS_DIR}/qualimap_v2.2.1/qualimap"
PRESEQ_TOOL_DIR="${TOOLS_DIR}/preseq"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_5col.interval_list"
VARIANT_VCF="${SAMPLE}.g.vcf"

ml gcc/12.1.0 gsl/2.3 java/1.8.0_131 biology htslib samtools bedtools gatk bcftools
ml biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/
export SENTIEON_LICENSE=license4.stanford.edu:5443


echo "### 5M read downsample with Preseq ### - START: $(date)"
TOTAL_READS=$(samtools view -c ${SAMPLE}${BAM_SUFFIX})
FRACTION=$(awk -v y="$TOTAL_READS" 'BEGIN {printf "%3f", 5000000 / y}')
if [ $TOTAL_READS -ge 5000000 ] && [ ! -z $FRACTION ] && [ $TARGETED -eq 0 ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31g -Xms31G" DownsampleSam \
        -I ${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.5M.bam \
        --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT \
        --MAX_RECORDS_IN_RAM 5500000
    echo "Downsampling for 5 million reads done"
    samtools index ${SAMPLE}.5M.bam
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}_wgs_5M_read_coverage.tsv
    bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${SAMPLE}.5M.bam >> ${SAMPLE}_wgs_5M_read_coverage.tsv
    echo "Coverage for 5 million reads done"

    samtools view -b -L $N25CHR_BED ${SAMPLE}.5M.bam > ${SAMPLE}_5M_n25chr.bam
    ml gsl/2.3
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}_5M_n25chr_unsorted.mr ${SAMPLE}_5M_n25chr.bam
    sort -k1,1 -k2,2n -k3,3n ${SAMPLE}_5M_n25chr_unsorted.mr > ${SAMPLE}_5M_n25chr_sorted.mr
    if [ ! -f ${SAMPLE}_5M_n25chr_sorted.mr ]; then
        echo "Problem making ${SAMPLE}_5M_n25chr_sorted.mr, cannot run PreSeq for 5 million reads"
    else
        $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}_5M_preseq_future_coverage.tsv ${SAMPLE}_5M_n25chr_sorted.mr
        rm ${SAMPLE}_5M_n25chr.bam* ${SAMPLE}_5M_n25chr_unsorted.mr* ${SAMPLE}_5M_n25chr_sorted.mr*
        if [ ! -f ${SAMPLE}_5M_preseq_future_coverage.tsv ]; then
            echo "Problem making ${SAMPLE}_5M_preseq_future_coverage.tsv, PreSeq for 5 million reads failed"
        else
            echo "PreSeq for 5 million reads done"
        fi
    fi
    ml gsl/2.7
else
    echo "Bam has $TOTAL_READS reads, cannot downsample to 5 million reads"
fi
echo "### 5M read downsample with Preseq ### - END: $(date)"


if [ $TARGETED -eq 0 ]; then
    echo "### WGS Preseq ### - START: $(date)"
    samtools view -b -L $N25CHR_BED ${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}_n25chr.bam
    ml gsl/2.3
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}_n25chr_unsorted.mr ${SAMPLE}_n25chr.bam
    sort -k1,1 -k2,2n -k3,3n ${SAMPLE}_n25chr_unsorted.mr > ${SAMPLE}_n25chr_sorted.mr
    if [ ! -f ${SAMPLE}_n25chr_sorted.mr ]; then
        echo "Problem making ${SAMPLE}_n25chr_sorted.mr, cannot run PreSeq for whole sample"
    else
        $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}_wgs_preseq_future_coverage.tsv ${SAMPLE}_n25chr_sorted.mr
        rm ${SAMPLE}_n25chr.bam* ${SAMPLE}_n25chr_unsorted.mr* ${SAMPLE}_n25chr_sorted.mr*
        if [ ! -f ${SAMPLE}_wgs_preseq_future_coverage.tsv ]; then
            echo "Problem making ${SAMPLE}_wgs_preseq_future_coverage.tsv, PreSeq for whole sample failed"
        else
            echo "PreSeq for whole sample done"
        fi
    fi
    echo "### WGS Preseq ### - END: $(date)"
    ml gsl/2.7
fi


echo "### Coverage ### - START: $(date)"
bedtools bamtobed -i ${SAMPLE}${BAM_SUFFIX} | cut -f 1-3 > ${SAMPLE}_n25chr.bed
echo "Bam to bed conversion done"
echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}_wgs_coverage.tsv
bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${SAMPLE}_n25chr.bed >> ${SAMPLE}_wgs_coverage.tsv
echo "Coverage done"
rm ${SAMPLE}_n25chr.bed
echo "### Coverage ### - END: $(date)"


echo "### GATK extra metrics ### - START: $(date)"
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectHsMetrics \
    -I ${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}_hs_metrics.tsv -R $REF_FASTA \
    -BI $EXOME_INTERVAL_LIST -TI $EXOME_INTERVAL_LIST --VALIDATION_STRINGENCY SILENT \
    --MAX_RECORDS_IN_RAM 3500000
echo "CollectHsMetrics done"
    
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectWgsMetrics \
    -I ${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}_wgs_metrics.tsv \
    -R $REF_FASTA --VALIDATION_STRINGENCY SILENT --INTERVALS $INTERVAL_LIST \
    --MAX_RECORDS_IN_RAM 3500000
echo "CollectWgsMetrics done"
    
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectMultipleMetrics \
    -I ${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}_extra_metrics --INTERVALS $INTERVAL_LIST \
    -R $REF_FASTA --VALIDATION_STRINGENCY SILENT --PROGRAM CollectAlignmentSummaryMetrics \
    --PROGRAM CollectBaseDistributionByCycle --PROGRAM CollectInsertSizeMetrics --PROGRAM MeanQualityByCycle \
    --PROGRAM QualityScoreDistribution --PROGRAM CollectGcBiasMetrics --FILE_EXTENSION .tsv \
    --MAX_RECORDS_IN_RAM 3500000
echo "CollectMultipleMetrics done"

gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx31G -Xmx31G" CollectOxoGMetrics \
    -I ${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}_oxog_metrics.tsv -R $REF_FASTA \
    --VALIDATION_STRINGENCY SILENT --INTERVALS $INTERVAL_LIST \
    --MAX_RECORDS_IN_RAM 3500000
echo "CollectOxoGMetrics done"

if [ $TARGETED -eq 1 ]; then
    if [ -f ${SAMPLE}.5M.bam ]; then
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}_targeted_5M_read_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${SAMPLE}.5M.bam >> ${SAMPLE}_targeted_5M_read_coverage.tsv
    echo "5 million read targeted coverage done"
    fi

    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}_targeted_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${SAMPLE}${BAM_SUFFIX} >> ${SAMPLE}_targeted_coverage.tsv
    echo "Exome coverage done"
fi
echo "### GATK extra metrics ### - END: $(date)"


echo "### Qualimap ### - START: $(date)"
mkdir -p ${SAMPLE}_temp_qualimap_output
$QUALIMAP_TOOL bamqc -nt 4 -nw 3000 --java-mem-size=31G -bam ${SAMPLE}${BAM_SUFFIX} -gff $N25CHR_BED \
    -c -hm 3 -outdir ${SCRATCH_DIR}/${SAMPLE}_temp_qualimap_output -outformat PDF
if [ ! -f ${SAMPLE}_temp_qualimap_output/report.pdf ]; then
    echo "QualiMap encountered a problem and did not complete"
else
    ml system poppler/0.47.0
    pdfseparate -f 1 -l 6 ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}_temp_qualimap_output/pages1-%d.pdf
    pdfseparate -f 284 -l 296 ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}_temp_qualimap_output/pages2-%d.pdf
    pdfunite ${SAMPLE}_temp_qualimap_output/pages*.pdf ${SAMPLE}.qualimap_report.pdf
    mv ${SAMPLE}_temp_qualimap_output/genome_results.txt ${SAMPLE}.qualimap_genome_results.txt
    echo "QualiMap done"
fi
rm -r ${SAMPLE}_temp_qualimap_output
echo "### Qualimap ### - END: $(date)"


echo "### Mosdepth ### - START: $(date)"
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
${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $ECDNA ${MOS_RESULTS_DIR}/${SAMPLE}.ecDNA ${SAMPLE}${BAM_SUFFIX}
zcat ${MOS_RESULTS_DIR}/${SAMPLE}.ecDNA.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.ecDNA.thresholds
echo "Mosdepth ecDNA done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $MICROSATELLITES ${MOS_RESULTS_DIR}/${SAMPLE}.microsatellite ${SAMPLE}${BAM_SUFFIX}
zcat ${MOS_RESULTS_DIR}/${SAMPLE}.microsatellite.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.microsatellite.thresholds
echo "Mosdepth microsatellites done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $CpGI ${MOS_RESULTS_DIR}/${SAMPLE}.CpGI ${SAMPLE}${BAM_SUFFIX}
zcat ${MOS_RESULTS_DIR}/${SAMPLE}.CpGI.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.CpGI.thresholds
echo "Mosdepth CpGIs done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $REPEATS ${MOS_RESULTS_DIR}/${SAMPLE}.repeats ${SAMPLE}${BAM_SUFFIX}
zcat ${MOS_RESULTS_DIR}/${SAMPLE}.repeats.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.repeats.thresholds
echo "Mosdepth repeats done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $ENHANCERS ${MOS_RESULTS_DIR}/${SAMPLE}.enhancers ${SAMPLE}${BAM_SUFFIX}
zcat ${MOS_RESULTS_DIR}/${SAMPLE}.enhancers.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.enhancers.thresholds
echo "Mosdepth enhancers done"

${MOSDEPTH}/mosdepth -t4 --thresholds 0,1,5,10,15,20,25,30,35,40,50,100,250,500,1000,2500,5000,10000 --by $XGEN_EXOME ${MOS_RESULTS_DIR}/${SAMPLE}.exome ${SAMPLE}${BAM_SUFFIX}
zcat ${MOS_RESULTS_DIR}/${SAMPLE}.exome.thresholds.bed.gz | awk '$23 = $3 - $2' | sed 's/ /\t/g' | cut -f5- | awk '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' | sed 's/ /\t/g' | \
awk '{$20=$1/$19; print}' | sed 's/ /\t/g' |  awk '{$21=$2/$19; print}' | sed 's/ / \t/g' | awk '{$22=$3/$19; print}' | sed 's/ /\t/g' | awk '{$23=$4/$19; print}' | \
sed 's/ /\t/g' | awk '{$24=$5/$19; print}' | sed 's/ /\t/g' | awk '{$24=$6/$19; print}' | sed 's/ /\t/g' | awk '{$26=$7/$19; print}' | sed 's/ /\t/g' | \
awk '{$27=$8/$19; print }' | sed 's/ /\t/g' | awk '{$28=$9/$19; print}' | sed 's/ /\t/g' | awk '{$29=$10/$19; print}' | sed 's/ /\t/g' | awk '{$30=$11/$19; print}' | sed 's/ /\t/g' | awk '{$31=$12/$19; print}' | \
sed 's/ /\t/g' | awk '{$32=$13/$19; print}' | sed 's/ /\t/g' | awk '{$33=$14/$19; print}' | sed 's/ /\t/g' | awk '{$34=$15/$19; print}' | sed 's/ /\t/g' | awk '{$35=$16/$19; print}'  | sed 's/ /\t/g' | awk '{$36=$17/$19; print}'  | \
sed 's/ /\t/g' | awk '{$37=$18/$19; print}'  | sed 's/ /\t/g' | cut -f20- > ${MOS_RESULTS_DIR}/${SAMPLE}.exome.thresholds
echo "Mosdepth exome done"
echo "### Mosdepth ### - END: $(date)"


echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"