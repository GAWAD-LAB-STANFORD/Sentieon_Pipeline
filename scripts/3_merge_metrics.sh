#!/bin/bash
#
#SBATCH --job-name=3_summarize_metrics
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1
#SBATCH --time=1-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=30G

START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --scratch_dir )     shift
                            SCRATCH_DIR=$1
                            ;;
        --script_dir )      shift
                            SCRIPT_DIR=$1
                            ;;
        --project )         shift
                            PROJECT=$1
                            ;;
        --targeted )        shift
                            TARGETED=$1
                            ;;
        --run_dir )         shift
                            RUN_DIR=$1
                            ;;
        --sample_sheet )    shift
                            SAMPLE_SHEET=$1
                            ;;
        --targeted )        shift
                            TARGETED=$1
                            ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $SCRIPT_DIR ] || [ -z $PROJECT ] || [ -z $TARGETED ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"
cd $SCRATCH_DIR

echo project is ${PROJECT} 

ml java/11.0.11 R/4.2.0 biology samtools/1.8
export R_LIBS="/home/groups/cgawad/R_LIBS"

echo "### Merging metrics ### - START: $(date)"
READ_COUNT_FILENAMES=( $(ls *_read_counts.tsv) )
sed -n 1p ${READ_COUNT_FILENAMES[0]} > ${PROJECT}.sample_read_counts_merged.tsv
for i in ${READ_COUNT_FILENAMES[@]}; do tail -n +2 $i; done >> ${PROJECT}.sample_read_counts_merged.tsv
echo "Read counts merged"

if [ ! -z $RUN_DIR ]; then
    DESIRED_CLUSTER_DENSITY=$(sed -n $(grep -n "Lane" $SAMPLE_SHEET | sed "s/:Lane.*//" | \
        awk '{print $1 + 1}')p $SAMPLE_SHEET | cut -d , -f $(grep "Lane" $SAMPLE_SHEET | \
        sed "s/,/\n/g" | nl | grep "Desired_Cluster_Density" | cut -f 1))
    INITAL_CONCENTRATION_COLUMN=$(grep "Initial_Concentration" $SAMPLE_SHEET | tr , "\n" | nl | grep "Initial_Concentration" | cut -f 1)
    LIBRARY_GROUP_COLUMN=$(grep "Library_Group" $SAMPLE_SHEET | tr , "\n" | nl | grep "Library_Group" | cut -f 1)
    if [ ! -z $INITAL_CONCENTRATION_COLUMN ] && [ ! -z $DESIRED_CLUSTER_DENSITY ]; then
        cat $SAMPLE_READ_COUNTS > ${SAMPLE_READ_COUNTS}.temp
        tail -n +$(cat -n $SAMPLE_SHEET | grep "Initial_Concentration" | cut -f 1 | tr -d '[:blank:]') $SAMPLE_SHEET | \
            cut -d , -f $INITAL_CONCENTRATION_COLUMN | awk '{print tolower($0)}' | \
            paste ${SAMPLE_READ_COUNTS}.temp - > $SAMPLE_READ_COUNTS
        if [ ! -z $LIBRARY_GROUP_COLUMN ]; then
            cat $SAMPLE_READ_COUNTS > ${SAMPLE_READ_COUNTS}.temp
            tail -n +$(cat -n $SAMPLE_SHEET | grep "Library_Group" | cut -f 1 | tr -d '[:blank:]') $SAMPLE_SHEET | \
                cut -d , -f $LIBRARY_GROUP_COLUMN | awk '{print tolower($0)}' | \
                paste ${SAMPLE_READ_COUNTS}.temp - > $SAMPLE_READ_COUNTS
        fi
        rm ${SAMPLE_READ_COUNTS}.temp
        Rscript ${SCRIPT_DIR}/correct_library_concentrations.R \
            "${RUN_DIR}/RunCompletionStatus.xml" $DESIRED_CLUSTER_DENSITY $SAMPLE_READ_COUNTS $PROJECT
        echo "Calculated library concentration corrections"
    fi
fi

ALIGNMENT_METRICS_FILENAMES=( $(ls *_extra_metrics.alignment_summary_metrics.tsv) )
echo -e sample"\t"$(sed -n 7p ${ALIGNMENT_METRICS_FILENAMES[0]}) | sed 's/ /\t/g' > ${PROJECT}.alignment_metrics_merged.tsv
for i in ${ALIGNMENT_METRICS_FILENAMES[@]}; do
    SAMPLE=$(echo $i | sed "s/_extra_metrics.alignment_summary_metrics.tsv//")
    R1=$(sed -n 8p $i)
    R2=$(sed -n 9p $i)
    PAIR=$(sed -n 10p $i)
    echo -e "$SAMPLE\t$R1\n$SAMPLE\t$R2\n$SAMPLE\t$PAIR"
done | sed 's/ /\t/g' >> ${PROJECT}.alignment_metrics_merged.tsv
echo "Alignment metrics merged"

WGS_METRICS_FILENAMES=( $(ls *_wgs_metrics.tsv) )
echo -e sample"\t"$(sed -n 7p ${WGS_METRICS_FILENAMES[0]}) | sed 's/ /\t/g' > ${PROJECT}.wgs_metrics_merged.tsv
for i in ${WGS_METRICS_FILENAMES[@]}; do echo -e $(echo $i | sed "s/_wgs_metrics.tsv//")"\t"$(sed -n 8p $i); done | sed 's/ /\t/g' >> ${PROJECT}.wgs_metrics_merged.tsv
echo "WGS metrics merged"

HS_METRICS_FILENAMES=( $(ls *_hs_metrics.tsv) )
echo -e sample"\t"$(sed -n 7p ${HS_METRICS_FILENAMES[0]}) | sed 's/ /\t/g' > ${PROJECT}.hs_metrics_merged.tsv
for i in ${HS_METRICS_FILENAMES[@]}; do echo -e $(echo $i | sed "s/_hs_metrics.tsv//")"\t"$(sed -n 8p $i); done | sed 's/ /\t/g' >> ${PROJECT}.hs_metrics_merged.tsv
echo "HS metrics merged"

OXOG_METRICS_FILENAMES=( $(ls *_oxog_metrics.tsv) )
sed -n 7p ${OXOG_METRICS_FILENAMES[0]} > ${PROJECT}.oxog_metrics_merged.tsv
for i in ${OXOG_METRICS_FILENAMES[@]}; do tail -n +8 $i | awk NF >> ${PROJECT}.oxog_metrics_merged.tsv; done
echo "Oxog metrics merged"

DUPLICATION_METRICS_FILENAMES=( $(ls *_duplication_metrics.tsv) )
echo -e sample"\t"$(sed -n 2p ${DUPLICATION_METRICS_FILENAMES[0]}) | sed 's/ /\t/g' > ${PROJECT}.duplication_metrics_merged.tsv
for i in ${DUPLICATION_METRICS_FILENAMES[@]}; do echo -e $(echo $i | sed "s/_duplication_metrics.tsv//")"\t"$(sed -n 3p $i); done | sed 's/ /\t/g' >> ${PROJECT}.duplication_metrics_merged.tsv
echo "Duplication metrics merged"

COVERAGE_FILENAMES=$(ls *_wgs_coverage.tsv)
echo -e "sample\tchrM_proportion" > ${PROJECT}.chrM_proportions_merged.tsv
for i in ${COVERAGE_FILENAMES[@]}; do
    MAIN_CHR_COUNTS=$(tail -n +2 $i | cut -f 4 | paste -sd+ | bc)
    CHRM_COUNTS=$(grep -P "chrM\t" $i | cut -f 4)
    echo -e $(echo $i | sed "s/_wgs_coverage.tsv//")"\t"$(awk 'BEGIN {print('$CHRM_COUNTS'/'$MAIN_CHR_COUNTS')}')
done >> ${PROJECT}.chrM_proportions_merged.tsv
echo "chrM proportions merged"

COVERAGE_FILENAMES=( $(ls *_wgs_coverage.tsv) )
for i in ${COVERAGE_FILENAMES[@]}; do
    SAMPLE=$(echo $i | sed "s/_wgs_coverage.tsv//")
    cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
        sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}_temp_coverage.tsv
done
TEMP_COVERAGE_FILENAMES=( $(ls *_temp_coverage.tsv) )
cut -f 1,2,3,6 ${COVERAGE_FILENAMES[0]} | \
    paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.wgs_coverage_merged.tsv
rm ${TEMP_COVERAGE_FILENAMES[@]}
echo "Coverage merged"
Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.wgs_coverage_merged.tsv $PROJECT "wgs"

DOWN_SAMPLE_COV_FILENAMES=( $(ls *_wgs_5M_read_coverage.tsv) )
if [ ${#DOWN_SAMPLE_COV_FILENAMES[@]} -ne 0 ] && [ $TARGETED -eq 0 ]; then
    for i in ${DOWN_SAMPLE_COV_FILENAMES[@]}; do
        SAMPLE=$(echo $i | sed "s/_wgs_5M_read_coverage.tsv//")
        cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
            sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}_temp_coverage.tsv
    done
    TEMP_COVERAGE_FILENAMES=( $(ls *_temp_coverage.tsv) )
    cut -f 1,2,3,6 ${DOWN_SAMPLE_COV_FILENAMES[0]} | \
        paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.wgs_5M_coverage_merged.tsv
    rm ${TEMP_COVERAGE_FILENAMES[@]}
    echo "5M coverage merged"
    Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.wgs_5M_coverage_merged.tsv $PROJECT "wgs_5M"

    DOWN_SAMPLE_PRESEQ_FILENAMES=( $(ls *_5M_preseq_future_coverage.tsv) )
    sed -n 1p ${DOWN_SAMPLE_PRESEQ_FILENAMES[0]} | sed "s/^/SAMPLE\t/" > ${PROJECT}.5M_preseq_future_coverage_merged.tsv
    for i in ${DOWN_SAMPLE_PRESEQ_FILENAMES[@]}; do
        SAMPLE=$(echo $i | sed "s/_5M_preseq_future_coverage.tsv//")
        tail -n +2 $i | sed "s/^/${SAMPLE}\t/" >> ${PROJECT}.5M_preseq_future_coverage_merged.tsv
    done
    echo "Preseq future coverage merged"
    Rscript ${SCRIPT_DIR}/graph_preseq.R ${PROJECT}.5M_preseq_future_coverage_merged.tsv $PROJECT "wgs_5M"
fi

if [ $TARGETED -eq 0 ]; then
    PRESEQ_FILENAMES=( $(ls *_wgs_preseq_future_coverage.tsv) )
    sed -n 1p ${PRESEQ_FILENAMES[0]} | sed "s/^/SAMPLE\t/" > ${PROJECT}.preseq_future_coverage_merged.tsv
    #for i in ${PRESEQ_FILENAMES[@]}; do
    #    SAMPLE=$(echo $i | sed "s/_wgs_preseq_future_coverage.tsv//")
    #    tail -n +2 $i | sed "s/^/${SAMPLE}\t/" >> ${PROJECT}.preseq_future_coverage_merged.tsv
    #done
    ls *_wgs_preseq_future_coverage.tsv | parallel "grep 999900000000.0 {} | sed 's/^/{}\t/g'" | sed 's/_wgs_preseq_future_coverage.tsv//g' >> ${PROJECT}.preseq_future_coverage_merged.tsv
    echo "Preseq future coverage merged"
    Rscript ${SCRIPT_DIR}/graph_preseq.R ${PROJECT}.preseq_future_coverage_merged.tsv $PROJECT
fi

if [ $TARGETED -eq 1 ]; then
    TARGETED_COVERAGE_FILENAMES=( $(ls *_targeted_coverage.tsv) )
    for i in ${TARGETED_COVERAGE_FILENAMES[@]}; do
        SAMPLE=$(echo $i | sed "s/_targeted_coverage.tsv//")
        cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
            sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}_temp_coverage.tsv
    done
    TEMP_COVERAGE_FILENAMES=( $(ls *_temp_coverage.tsv) )
    cut -f 1,2,3,6 ${TARGETED_COVERAGE_FILENAMES[0]} | \
        paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.targeted_coverage_merged.tsv
    rm ${TEMP_COVERAGE_FILENAMES[@]}
    echo "Targeted coverage merged"
    Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.targeted_coverage_merged.tsv $PROJECT "targeted"

    TARGETED_DOWN_SAMPLE_COV_FILENAMES=( $(ls *_targeted_5M_read_coverage.tsv) )
    if [ ${#TARGETED_DOWN_SAMPLE_COV_FILENAMES[@]} -ne 0 ]; then
        for i in ${TARGETED_DOWN_SAMPLE_COV_FILENAMES[@]}; do
            SAMPLE=$(echo $i | sed "s/_targeted_5M_read_coverage.tsv//")
            cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
                sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}_temp_coverage.tsv
        done
        TEMP_COVERAGE_FILENAMES=( $(ls *_temp_coverage.tsv) )
        cut -f 1,2,3,6 ${TARGETED_DOWN_SAMPLE_COV_FILENAMES[0]} | \
            paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.targeted_5M_coverage_merged.tsv
        rm ${TEMP_COVERAGE_FILENAMES[@]}
        echo "5M targeted coverage merged"
        Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.targeted_5M_coverage_merged.tsv $PROJECT "targeted_5M"
    fi
fi
echo "### Merging metrics ### - END: $(date)"

echo "### Deleting intermediate files ### - START: $(date)"
# rm ${READ_COUNT_FILENAMES[@]} ${ALIGNMENT_METRICS_FILENAMES[@]} ${WGS_METRICS_FILENAMES[@]} ${OXOG_METRICS_FILENAMES[@]}
# rm ${CHRM_PROP_FILENAMES[@]} ${COVERAGE_FILENAMES[@]} ${DOWN_SAMPLE_COV_FILENAMES[@]} ${DUPLICATION_METRICS_FILENAMES[@]}
# rm ${PRESEQ_FILENAMES[@]} ${DOWN_SAMPLE_PRESEQ_FILENAMES[@]} ${VARIANT_CLASS_COUNTS_FILENAMES[@]}
mkdir -p ${PROJECT}_extra_metrics
mv *extra_metrics* ${PROJECT}_extra_metrics/
# if [ -f ${PROJECT}.temporary_3_column_bed_interval_file ]; then
#     rm ${PROJECT}.temporary_3_column_bed_interval_file
# fi
# if [ $TARGETED -eq 1 ]; then
#     rm ${TARGETED_COVERAGE_FILENAMES[@]} ${TARGETED_DOWN_SAMPLE_COV_FILENAMES[@]}
# fi

grep 999900000000.0 ${PROJECT}.preseq_future_coverage_merged.tsv | sort -k1 | awk -F'\t' '$6=$3/1000000000' | sed 's/ /\t/g' | cut -f6 | sed '1i Predicted_Billion_Bases_Covered' > ${PROJECT}.preseq.qual
cat ${PROJECT}.sample_read_counts.tsv | (sed -u 1q; sort -k1) | cut -f1,2 | awk -F'\t' '$3=$2/1000000' | sed 's/ /\t/g' | cut -f1,3 | sed '1i Sample_Name\tMillion_Reads' > ${PROJECT}.read.qual
cat ${PROJECT}.duplication_metrics_merged.tsv | (sed -u 1q; sort -k1) | cut -f9 > ${PROJECT}.dup.qual
cat ${PROJECT}.chrM_proportions_merged.tsv | (sed -u 1q; sort -k1) | cut -f2 > ${PROJECT}.mito.qual
grep -v FIRST_OF_PAIR ${PROJECT}.alignment_metrics_merged.tsv | grep -v SECOND_OF_PAIR |  (sed -u 1q; sort -k1) | cut -f8,14,15,16,17,19,23,24 > ${PROJECT}.align.qual
grep CCG ${PROJECT}.oxog_metrics_merged.tsv | sort -k1 | cut -f11,12,19,20 |  sed '1i OXIDATION_ERROR_RATE\tOXIDATION_Q\tG_REF_OXO_ERROR_RATE\tG_REF_OXO_Q' > ${PROJECT}.oxo.qual
cat ${PROJECT}.hs_metrics_merged.tsv | (sed -u 1q; sort -k1) | cut -f2,3,8,14,35,39,40,42,43,47-58 > ${PROJECT}.hs.cover.qual
cat ${PROJECT}.wgs_metrics_merged.tsv | (sed -u 1q; sort -k1) | cut -f2-4,8,9,11,15-30 > ${PROJECT}.wgs.cover.qual
paste ${PROJECT}.read.qual ${PROJECT}.preseq.qual ${PROJECT}.mito.qual ${PROJECT}.dup.qual ${PROJECT}.wgs.cover.qual ${PROJECT}.align.qual ${PROJECT}.oxo.qual > 01.${PROJECT}.wgs.data.quality.tsv
paste ${PROJECT}.read.qual ${PROJECT}.preseq.qual ${PROJECT}.mito.qual ${PROJECT}.dup.qual ${PROJECT}.hs.cover.qual ${PROJECT}.align.qual ${PROJECT}.oxo.qual > 01.${PROJECT}.hs.data.quality.tsv

cp $SCRATCH_DIR/RunCompletionStatus.xml `pwd`

if [ -f "RunCompletionStatus.xml" ]; then
    tail -n +4 RunCompletionStatus.xml | sed 's/<//g' | sed 's/>/\t/g' | sed 's/ //g' | cut -f1 -d"/" > RunCompletionStatus.tsv
    cat RunCompletionStatus.tsv 01.${PROJECT}.wgs.data.quality.tsv > 01.${PROJECT}.wgs.data.run.quality.tsv
    cat RunCompletionStatus.tsv 01.${PROJECT}.hs.data.quality.tsv > 01.${PROJECT}.hs.data.run.quality.tsv
    # rm 01.${PROJECT}.wgs.data.quality.tsv
    # rm 01.${PROJECT}.hs.data.quality.tsv
fi

echo "### Deleting intermediate files ### - END: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"