#!/bin/bash
#
#SBATCH --job-name=7_manta_sv
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --sample_string )   shift
                            SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                            ;;
        --ref_fasta )       shift
                            REF_FASTA=$1
                            ;;
        --scratch_dir )     shift
                            SCRATCH_DIR=$1
                            ;;
        --targeted )        shift
                            TARGETED=$1
                            ;;
    esac
    shift
done

if [ -z $SAMPLE_ARRAY ] || [ -z $REF_FASTA ] || [ -z $SCRATCH_DIR ] || [ -z $TARGETED ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $SCRATCH_DIR

ml purge
ml system xz/5.2.3
ml curl/7.54.0
ml php/7.3.0 gsl/2.3 biology bedtools samtools/1.8 htslib/1.8
ml java/1.8.0_131
export R_LIBS="/home/groups/cgawad/R_LIBS"

export manta=/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/manta-1.6.0.centos6_x86_64/bin

#this isn't gonna work, gotta do one manta call for somatic, specifying --normalBam and --tumorBam, and one manta call for germline which is the same as what ur doing, can use normal_sample_name to figure out normal one, idk what best method for the others is, may want to do a step 6 instead and pass bams in yeah i think that works better

#99% sure manta sv calls are just overwriting

cd $SCRATCH_DIR

if [ $TARGETED -eq 0 ]; then
    ##Run without exome option if not targeted
    if [ -z $NORMAL_SAMPLE_NAME ]; then
        #ls "*.recalibrated_realigned_deduped_sorted.bam" | sed 's/^/--bam /' | tr '\n' ' ' | sed 's/ *$//' > bam_list

        input=$SAMPLE
        echo BAMs = ${input}
        echo running manta
        $manta/configManta.py --bam $input --referenceFasta $REF_FASTA --runDir $SCRATCH_DIR --callRegions $manta/regions.bed.gz --outputContig
        ./runWorkflow.py
        echo manta finished running
        mv Manta_SV_Calls ${SAMPLE%.realigned_deduped_sorted.bam}_Manta_SV_Calls
        mv results ${SAMPLE%.realigned_deduped_sorted.bam}_Manta_SV_Calls
        echo cleaning up and copying back files to oak
    elif [[ ${SAMPLE} == ${NORMAL_SAMPLE_NAME}"*" ]]; then
        input="${SCRATCH_DIR}/${SAMPLE}"
        echo BAMs = ${input}
        echo running manta
        $manta/configManta.py --bam $input --referenceFasta $REF_FASTA --runDir $SCRATCH_DIR --callRegions $manta/regions.bed.gz --outputContig
        ./runWorkflow.py
        echo manta finished running
        mv Manta_SV_Calls ${NORMAL_SAMPLE_NAME}_Manta_SV_Calls
        mv results ${NORMAL_SAMPLE_NAME}_Manta_SV_Calls
        echo cleaning up and copying back files to oak
    else
        tumorBam="${SCRATCH_DIR}/${SAMPLE}"
        normalBam="${SCRATCH_DIR}/${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
        $manta/configManta.py  \
    --normalBam $normalBam \
    --tumorBam $tumorBam \
    --referenceFasta $REF_FASTA \
    --runDir $SCRATCH_DIR \
    --callRegions $manta/regions.bed.gz
    fi
    else
    #Run manta with exome option if TARGETED was specified	
    if [ -z $NORMAL_SAMPLE_NAME]; then
        #ls "*.recalibrated_realigned_deduped_sorted.bam" | sed 's/^/--bam /' | tr '\n' ' ' | sed 's/ *$//' > bam_list

        input=$SAMPLE
        echo BAMs = ${input}
        echo running manta
        $manta/configManta.py --bam $input --referenceFasta $REF_FASTA --runDir $SCRATCH_DIR --callRegions $manta/regions.bed.gz --outputContig
        ./runWorkflow.py
        echo manta finished running
        mv Manta_SV_Calls ${SAMPLE%.realigned_deduped_sorted.bam}_Manta_SV_Calls
        mv results ${SAMPLE%.realigned_deduped_sorted.bam}_Manta_SV_Calls
        echo cleaning up and copying back files to oak
    elif [[ ${SAMPLE} == ${NORMAL_SAMPLE_NAME}"*" ]]; then
        input="${SCRATCH_DIR}${SAMPLE}"
        echo BAMs = ${input}
        echo running manta
        $manta/configManta.py --bam $input --referenceFasta $REF_FASTA --runDir $SCRATCH_DIR --callRegions $manta/regions.bed.gz --outputContig
        ./runWorkflow.py
        echo manta finished running
        mv Manta_SV_Calls ${NORMAL_SAMPLE_NAME}_Manta_SV_Calls
        mv results ${NORMAL_SAMPLE_NAME}_Manta_SV_Calls
        echo cleaning up and copying back files to oak
    else
        tumorBam="${SCRATCH_DIR}${SAMPLE}"
        normalBam="${SCRATCH_DIR}${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
        $manta/configManta.py  \
    --normalBam $normalBam \
    --tumorBam $tumorBam \
    --referenceFasta $REF_FASTA \
    --runDir $SCRATCH_DIR \
    --exome \
    --callRegions $manta/regions.bed.gz
    fi
fi
mv Manta_SV_Calls ${SAMPLE%.realigned_deduped_sorted.bam}_Manta_SV_Calls

#should put all the folders into one folder after, then figure out a way to quickly visualize or otherwise determine what samples
#share SVs
#may need to add another step just to do this

mkdir -p Manta_SV_calls_all
mv *_Manta_SV_Calls Manta_SV_calls_all/ 

ml purge
ml system gsl/2.3 poppler/0.47.0
ml devel php biology bedtools samtools/1.6 gatk/4.1.4.1 bedtools samtools/1.8 vcftools/0.1.15
ml java/1.8.0_131 perl/5.26.0 python/3.6.1

mkdir SigProfiler_Germline_PDFs

find *_SigProfiler_Results -name '*pdf' -exec mv -t `pwd`/SigProfiler_Germline_PDFs {} +
pdfunite ./SigProfiler_Germline_PDFs/*.pdf ./SigProfiler_Germline_PDFs/01_Combined_Germline_Sigprofiler.pdf

find ./ -maxdepth 1 \( -name "*.pdf" ! -name "01_Com*" ! -name "*indel*" ! -name "*snv*" ! -name "*onal*"  \) -exec mv {} `pwd`/*Multiple_Metric_Files \;
pdfunite `pwd`/*Multiple_Metric_Files/*.pdf `pwd`/01_Combined_Metric_Plots.pdf

mv ./SigProfiler_Germline_PDFs/01_Combined_Germline_Sigprofiler.pdf `pwd`

#calculate and combine persent of regions covered
cd $SCRATCH_DIR

zcat `pwd`/Mosdepth_Results/*micro*thresholds.bed.gz | head -n1 | cut -f5- | sed "s/^/Sample\tRegion\t/g" > `pwd`/Mosdepth_Results/mos_header

cd Mosdepth_Results

ls *thresholds | parallel 'cat {} | sed "s/^/{}\t/g" | sed "s/.thresholds//g" | sed "s/\./\t/" ' > 01.Combined_Mosdepth_Region_Percent_pre.tsv

cat mos_header 01.Combined_Mosdepth_Region_Percent_pre.tsv > 01.Combined_Mosdepth_Region_Percent.tsv

mv 01.Combined_Mosdepth_Region_Percent.tsv ..

cd $SCRATCH_DIR

# calculate variant class count for germline, somatic, and somatic clonal
cut -f4,5,115,119 *extract_snp.hg38_multianno.final.tsv | grep -E '0/1|1\|1|1/1|0\|1' | cut -f1-3 | sort | uniq -c | sort -k4,4 -k1,1nr | grep -v "*" > 01.germline.merged.variant_class_count.tsv
grep PASS *svc_merged_extract_snp.hg38_multianno.tsv | cut -f4,5,124,140 | grep -E '0/1|1\|1|1/1|0\|1' | cut -f1-3 | sort | uniq -c | sort -k4,4 -k1,1nr | grep -v "*" > 01.somatic.merged.variant_class_count.tsv
cut -f4,5,115,119 01_final_clonal_somatic_calls.tsv | grep -E '0/1|1\|1|1/1|0\|1' | cut -f1-3 | sort | uniq -c | sort -k4,4 -k1,1nr | grep -v "*" > 01.somatic.clonal.merged.variant_class_count.tsv

#mkdir -p mutation_calls/
#mv *multianno* mutation_calls/
#mv *vqsr.vcf* mutation_calls/
#mv *.g.vcf* mutation_calls/
#mv candidates* mutation_calls/
#mv final_sites* mutation_calls/
#mv all_variants* mutation_calls/
#mv *calls_pre* mutation_calls/

rm -rf $SCRATCH_DIR/tmp*

rm -rf $SCRATCH_DIR/*output

echo "current directory is `pwd`"
#rm -rf $SCRATCH_DIR

echo "### Manta SV done  ###"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"