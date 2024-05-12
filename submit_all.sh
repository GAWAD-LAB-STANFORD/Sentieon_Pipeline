#!/bin/bash
#
#SBATCH --job-name=submit_all
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

# TODO README
# TODO change positional arguments to optional arguments

PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"
PIPELINE_COMMAND="$@"
# set -x may be possible to replace echoing important commands
HELP="\
Purpose: \n\t\
    To run Sentieon for GATK and other analyses of paired-end DNA or RNA sequences \n\n\
Required arguments: -p/--project <arg>, and either -f/--fastq_dir <arg> or -r/--results_dir <arg> \n\
Optional arguments: -s/--scratch_dir <arg>, --err_out_dir <arg>, --skip_scratch, -b/--run_dir <arg>, \n\t\
    --sample_sheet <arg>, --skip_variant_call, --only_variant_call, \n\t\
    --R1_suffix <arg>, --R2_suffix <arg>, --element, --skip_trimming, --rna, \n\t\
    --bam_suffix <arg>, --normal_sample_name <arg>, --scan2, --cross_dir <arg>, --skip_panel <arg>, \n\t\
    --exome, --targeted, --exome_bed_version <arg>, --panel_bed <arg>, --panel_interval_list <arg>, \n\t
    --manta, --ginkgo_mb_sizes <arg>, --slurm <arg> \n\n\
Defaults: \n\t\
    If no fastq_dir specified, uses results_dir \n\t\
    If no results_dir specified, makes new directory in fastq_dir \n\t\
    scratch_dir: /scratch/groups/cgawad/date_project_Scratch \n\t\
    sample_sheet: SampleSheet.csv \n\t\
    R1_suffix: _L001_R1_001.fastq.gz or _R1_001.fastq.gz or _R1.fastq.gz \n\t\
    R2_suffix: _L001_R2_001.fastq.gz or _R2_001.fastq.gz or _R2.fastq.gz \n\t\
    Will not assume element BCL/fastq data \n\t\
    Will run trimmomatic \n\t\
    WGS assumed \n\t\
    Will not run Scan2 \n\t\
    Will skip Scan2 panel \n\t\
    Will run Ginkgo on 5M read downsampled BAMs for WGS \n\t\
    Other Ginkgo runs will only be run for WGS \n\t\
    Will not call germline variants unless normal sample name specified \n\t\
    Will not run manta \n\t\
    Exome BED version: 1 \n\t\
    \n\n\
Run after demultiplexing and with fastq directory: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --fastq_dir /oak/stanford/groups/cgawad/2020-01-01_Fastqs/ --project 2020-01-01_Project --normal_sample_name IL7RLow-430-scIndex-Plate1-gDNA-TargetCapture-sc-430-A06\n\n\
Run after demultiplexing and with results directory: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --fastq_dir /oak/stanford/groups/cgawad/2020-01-01_Fastqs/ --results_dir /oak/stanford/groups/cgawad/2020-01-01_Results/ --project 2020-01-01_Project --normal_sample_name IL7RLow-430-scIndex-Plate1-gDNA-TargetCapture-sc-430-A06\n\n\
Run with demultiplexing and fastq directory: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --run_dir /oak/stanford/groups/cgawad/Illumina_Data/MiniSeq/2020-01-01_BCLs --fastq_dir /oak/stanford/groups/cgawad/2020-01-01_Fastqs/ --project 2020-01-01_Project --normal_sample_name IL7RLow-430-scIndex-Plate1-gDNA-TargetCapture-sc-430-A06\n\n\
Run with demultiplexing and results directory: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --run_dir /oak/stanford/groups/cgawad/Illumina_Data/MiniSeq/2020-01-01_BCLs --results_dir /oak/stanford/groups/cgawad/2020-01-01_Results/ --project 2020-01-01_Project --normal_sample_name IL7RLow-430-scIndex-Plate1-gDNA-TargetCapture-sc-430-A06\n\n\
Run with demultiplexing, fastq directory, and results directory: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --run_dir /oak/stanford/groups/cgawad/Illumina_Data/MiniSeq/2020-01-01_BCLs --fastq_dir /oak/stanford/groups/cgawad/2020-01-01_Fastqs/ --results_dir /oak/stanford/groups/cgawad/2020-01-01_Results/ --project 2020-01-01_Project --normal_sample_name IL7RLow-430-scIndex-Plate1-gDNA-TargetCapture-sc-430-A06\n\n\
README.md is pending updates"

# Reads in command line option arguments and assigns them to variables
SKIP_SCRATCH=0
SKIP_VARIANT_CALL=0
ONLY_VARIANT_CALL=0
SKIP_TRIMMOMATIC=0
RNA=0
BAM_SUFFIX=".recalibrated_realigned_deduped_sorted.bam"
SCAN2=0
TARGETED=0
SKIP_PANEL=1
EXOME_BED_VERSION=1
MANTA=0
ELEMENT=0
STEP=0
TEMP_ARRAY_START=0
DEPENDENCY=""
DEPENDER=""
while [ "$1" != "" ]; do
    case $1 in
        -h | --help )               echo -e $HELP
                                    exit 0
                                    ;;
        -f | --fastq_dir )          shift
                                    FASTQ_DIR=$1
                                    ;;
        -r | --results_dir )        shift
                                    RESULTS_DIR=$1
                                    ;;
        -p | --project )            shift
                                    PROJECT=$1
                                    ;;
        -d | --pipeline_dir )       shift
                                    PIPELINE_DIR=$1
                                    ;;
        -s | --scratch_dir )        shift
                                    SCRATCH_DIR=$1
                                    ;;
        --err_out_dir )             shift
                                    STD_ERR_OUT_DIR=$1
                                    ;;
        --skip_scratch )            SKIP_SCRATCH=1
                                    ;;
        -b | --run_dir )            shift
                                    RUN_DIR=$1
                                    ;;
        --sample_sheet )            shift
                                    SAMPLE_SHEET=$1
                                    ;;
        --R1_suffix )               shift
                                    R1_SUFFIX=$1
                                    ;;
        --R2_suffix )               shift
                                    R2_SUFFIX=$1
                                    ;;
        --skip_variant_call )	    SKIP_VARIANT_CALL=0
                                    ;;
        --only_variant_call )	    ONLY_VARIANT_CALL=0
                                    ;;
        --skip_trimming )           SKIP_TRIMMOMATIC=1
                                    ;;
        --rna )                     RNA=1
                                    ;;
        --bam_suffix )              shift
                                    BAM_SUFFIX=$1
                                    ;;
        --scan2 )                   SCAN2=1
                                    ;;
        --cross_dir )               shift
                                    CROSS_SAMPLE_DIR=$1
                                    ;;
        --normal_sample_name )      shift
                                    NORMAL_SAMPLE_NAME=$1
                                    ;;
        --exome ) 		            TARGETED=1
                                    ;;
        --targeted ) 		        TARGETED=1
                                    ;;
        --skip_panel ) 		        shift
                                    SKIP_PANEL=$1
                                    ;;
        --exome_bed_version )       shift
                                    EXOME_BED_VERSION=$1
                                    ;;
        --panel_bed )               shift
                                    PANEL_BED=$1
                                    ;;
        --panel_interval_list )     shift
                                    PANEL_INTERVAL_LIST=$1
                                    ;;
        --manta )                   MANTA=1
                                    ;;
        --element )                 ELEMENT=1
                                    ;;
        --ginkgo_mb_sizes ) 	    shift
                                    GINKGO_MB_ARRAY=( $(echo $1 | sed 's/,/ /g') )
                                    ;;
        --step )		            shift
                                    STEP=$1
                                    ;;
        --temp_array_start )        shift
                                    TEMP_ARRAY_START=$1
                                    ;;
        --slurm )                   shift
                                    SLURM_OPTIONS=${@:1}
                                    ;;
    esac
    shift
done


# Hardcoded paths and variables
PYTHON_LIBS="/home/groups/cgawad/python_libs/bin"
PYTHON_LIBS_SITE_PACKAGES="/home/groups/cgawad/python_libs/lib/python3.6/site-packages"
READS_PER_SPLIT=5000000
TEMP_ARRAY_INCREMENT=1000
SCRIPT_DIR="${PIPELINE_DIR}/scripts"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
ANNOVAR_DIR="/oak/stanford/groups/cgawad/Reference_Files/ANNOVAR"
TRANCHE="99.9"

# hg38 reference files
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
BISMARK_GENOME="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Bismark"
REF_FASTA="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta"
REF_NAME="human"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"
N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.bed"
N22CHR_INTERVAL_LIST="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n22chr_031723.interval_list"
N22CHR_BED="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n22chr.bed"
DBSNP_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
WGS_SCATTERED_CALLINGS="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/wgs_calling_regions.hg38.interval_list"
INTERVAL_STRING="chr1_chr2_chr3_chr4_chr5_chr6_chr7_chr8_chr9_chr10_chr11_chr12_chr13_chr14_chr15_chr16_chr17_chr18_chr19_chr20_chr21_chr22_chrX_chrY_chrM"
SCATTERED_CALLING_DIR="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/scattered_calling_intervals"
EXOME_TARGETS_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_3col.bed"
EXOME_TARGETS_BED_VER2="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-hyb-panel-v2-targets-hg38.bed"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_5col.interval_list"
INTERVAL_ARRAY=( $(echo $INTERVAL_STRING | sed 's/_/ /g') )
ANNOVAR_GENOME_VERSION="hg38"

# Ensure we have the required variables set and set other variables
if ([ -z $FASTQ_DIR ] && [ -z $RESULTS_DIR ]) || [ -z $PROJECT ] || [ -z $PIPELINE_DIR ]; then
    echo "Variables not supplied correctly. Use -h/--help options for assistance. Exiting with code 1"
    exit 1
fi

if ([ -z $FASTQ_DIR ] && [ $ONLY_VARIANT_CALL -eq 0 ]); then
    FASTQ_DIR="$RESULTS_DIR"
    OPTIONS+=( "-f $FASTQ_DIR" )
elif [ -z $RESULTS_DIR ]; then
    RESULTS_DIR="${FASTQ_DIR}/$(date '+%Y-%m-%d')_${PROJECT}_Results"
fi
if [ -z $SCRATCH_DIR ] && [ $SKIP_SCRATCH -eq 0 ]; then
    SCRATCH_DIR="/scratch/groups/cgawad/$(date '+%Y-%m-%d')_${PROJECT}_Scratch"
elif [ $SKIP_SCRATCH -eq 1 ]; then
    SCRATCH_DIR="$RESULTS_DIR"
fi
if [ -z $STD_ERR_OUT_DIR ]; then
    STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
fi
# Make directories if they don't exist
mkdir -p $FASTQ_DIR
mkdir -p $RESULTS_DIR
mkdir -p $SCRATCH_DIR
mkdir -p $STD_ERR_OUT_DIR

# Add parameters to OPTIONS variable to retain them with each subsequent pipeline resubmission
OPTIONS=( "-r $RESULTS_DIR -d $PIPELINE_DIR -p $PROJECT -s $SCRATCH_DIR --err_out_dir $STD_ERR_OUT_DIR " )
if [ ! -z $RUN_DIR ] && [ $ONLY_VARIANT_CALL -eq 1 ]; then
    echo "Variables not supplied correctly. Cannot perform demultiplexing while only variant calling from BAMs. Exiting with code 1"
    exit 1
fi
if [ ! -z $RUN_DIR ] && [ -z $SAMPLE_SHEET ]; then
    if [ $ELEMENT -eq 1 ]; then
        SAMPLE_SHEET="${RUN_DIR}/RunManifest.csv"
    else
        SAMPLE_SHEET="${RUN_DIR}/SampleSheet.csv"
    fi
elif [ -z $RUN_DIR ] && [ ! -z $SAMPLE_SHEET ]; then
    echo "Variables not supplied correctly. Please specify a run diretory for demultiplexing with --run_dir. Exiting with code 1"
    exit 1
fi 
if [ ! -z $RUN_DIR ] && [ ! -z $SAMPLE_SHEET ]; then
    if [ ! -f $SAMPLE_SHEET ]; then
        echo "Sample sheet $SAMPLE_SHEET not found. Exiting with code 1"
        exit 1
    fi
    OPTIONS+=( "--run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET" )
fi
if [ ! -z $FASTQ_DIR ]; then
    OPTIONS+=( "-f $FASTQ_DIR" )
fi
if [ $SKIP_VARIANT_CALL -eq 1 ] && [ $ONLY_VARIANT_CALL -eq 1 ]; then
    echo "Variables not supplied correctly. Please specify either --skip_variant_call or --only_variant_call, not both. Exiting with code 1"
    exit 1
elif [ $SKIP_VARIANT_CALL -eq 1 ]; then
    OPTIONS+=( "--skip_variant_call" )
elif [ $ONLY_VARIANT_CALL -eq 1 ]; then
    OPTIONS+=( "--only_variant_call" )
fi
if [ ! -z $R1_SUFFIX ]; then
    OPTIONS+=( "--R1_suffix $R1_SUFFIX" )
fi
if [ ! -z $R2_SUFFIX ]; then
    OPTIONS+=( "--R2_suffix $R2_SUFFIX" )
fi
if [ $ELEMENT -eq 1 ]; then
    OPTIONS+=( "--element" ) 
fi
if [ $SKIP_TRIMMOMATIC -eq 1 ]; then
    OPTIONS+=( "--skip_trimming" )
fi
if [ $RNA -eq 1 ]; then
    OPTIONS+=( "--rna" )
    if [ "$BAM_SUFFIX" == ".recalibrated_realigned_deduped_sorted.bam" ]; then
        BAM_SUFFIX=".rna.recalibrated_realigned_deduped_sorted.bam"
    fi
    SKIP_TRIMMOMATIC=1
fi
if [ $BAM_SUFFIX != ".recalibrated_realigned_deduped_sorted.bam" ]; then
    OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
fi
if [ ! -z $NORMAL_SAMPLE_NAME ]; then
    OPTIONS+=( "--normal_sample_name $NORMAL_SAMPLE_NAME" ) 
fi
if [ $SCAN2 -eq 1 ]; then
    OPTIONS+=( "--scan2" )
fi
if [ ! -z $CROSS_SAMPLE_DIR ]; then
    OPTIONS+=( "--cross_dir $CROSS_SAMPLE_DIR" )
fi
if [ $SKIP_PANEL -eq 0 ]; then
    OPTIONS+=( "--skip_panel 0" )
fi
if ([ $SCAN2 -eq 1 ] && [ -z $NORMAL_SAMPLE_NAME ]); then
    echo "Normal sample name not found, but required for Scan2. Please specify using --normal_sample_name. Exiting with code 1"
    exit 1
fi
if [ $TARGETED -eq 1 ]; then
    OPTIONS+=( "--targeted" )
    TARGETS_BED=$EXOME_TARGETS_BED
    INTERVAL_LIST=$EXOME_INTERVAL_LIST
    if [ $EXOME_BED_VERSION -eq 2 ]; then
        OPTIONS+=( "--exome_bed_version 2" )
        TARGETS_BED=$EXOME_TARGETS_BED_VER2
    fi
    if [ ! -z $PANEL_BED ]; then
        OPTIONS+=( "--panel_bed $PANEL_BED" )
        TARGETS_BED=$PANEL_BED
    fi
    if [ ! -z $PANEL_BED ]; then
        OPTIONS+=( "--panel_interval_list $PANEL_INTERVAL_LIST" )
        INTERVAL_LIST=$PANEL_INTERVAL_LIST
    fi
else
    TARGETS_BED=$N25CHR_BED
    INTERVAL_LIST=$N25CHR_INTERVAL_LIST
fi
if [ $MANTA -eq 1 ]; then
    OPTIONS+=( "--manta" )
fi
if [ ${#GINKGO_MB_ARRAY[@]} -ne 0 ]; then
    GINKGO_MB_STRING=$( IFS=$':'; echo "${GINKGO_MB_ARRAY[*]}" )
    OPTIONS+=( "--ginkgo_mb_sizes $GINKGO_MB_STRING" ) 
fi

# On first run, stdout all options from OPTIONS variable for pipeline resubmission parameters/arguments
TEMP_PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"
PIPELINE_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_pipeline_status.txt
cd $RESULTS_DIR
if [ "$TEMP_PIPELINE_DIR" = "$PIPELINE_DIR" ]; then
    echo -e "\nSTART: $(date)\nSentieon Pipeline\n\n$PIPELINE_DIR/submit_all.sh $PIPELINE_COMMAND\n\nProject: $PROJECT\nResults dir: $RESULTS_DIR\nScratch dir: $SCRATCH_DIR\nErr out dir: $STD_ERR_OUT_DIR\n" >> $PIPELINE_STATUS
    echo -e "\nOPTIONS variable holding parameters/arguments for pipeline resubmission: ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
fi


if [ ! -z $SLURM_OPTIONS ]; then
    echo "Option: Slurm - entire pipeline run will be queued with user parameters" >> $PIPELINE_STATUS
    sbatch -J $PROJECT ${SLURM_OPTIONS[@]} \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh ${OPTIONS[@]}
    exit 0
fi


# Don't use --mem, use --mem-per-cpu and --cpu-per-task to allocate resources unless you don't want to allocate resources based on what task needs.
# In my experience, --mem reserves entire node if used with --cpu-per-task

if ([ $STEP -eq 0 ] && [ -z $RUN_DIR ] && [ $ONLY_VARIANT_CALL -eq 0 ]) || [ $STEP -eq 1 ] || [ $STEP -eq 2 ]; then
    if [ -z $R1_SUFFIX ] || [ -z $R2_SUFFIX ]; then
        R1_SUFFIX="_L001_R1_001.fastq.gz"
        R2_SUFFIX="_L001_R2_001.fastq.gz"
        if [ $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" | wc -l) -eq 0 ]; then
            R1_SUFFIX="_R1_001.fastq.gz"
            R2_SUFFIX="_R2_001.fastq.gz"
        fi
        if [ $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" | wc -l) -eq 0 ]; then
            R1_SUFFIX="_R1.fastq.gz"
            R2_SUFFIX="_R2.fastq.gz"
        fi
    fi
    # TODO Does this remove unassigned and undetermined?
    SAMPLE_ARRAY=( $(find $FASTQ_DIR -maxdepth 1 -name "*${R1_SUFFIX}" -exec basename {} \; | \
        grep -v "Unassigned" | grep -v "Undetermined" | sed "s/${R1_SUFFIX}//") )
    if [ ${#SAMPLE_ARRAY[@]} -eq 0 ]; then
        echo "No fastq.gz files found in the fastq directory. Exiting with code 1" >> $PIPELINE_STATUS
        echo "END: $(date)" >> $PIPELINE_STATUS
        exit 1
    fi
fi


if [ $STEP -eq 0 ] && [ ! -z $RUN_DIR ] && [ $ONLY_VARIANT_CALL -eq 0 ] && [ $ELEMENT -eq 0 ]; then
    echo "### Step 0 - Demultiplexing ### - START: $(date)" >> $PIPELINE_STATUS
    echo -e "Run dir: $RUN_DIR\nSample sheet: $SAMPLE_SHEET" >> $PIPELINE_STATUS
    echo -e "\nsbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/0_demultiplexer.sh \
        --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET --fastq_dir $FASTQ_DIR --pipeline_status $PIPELINE_STATUS\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/0_demultiplexer.sh \
        --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET --fastq_dir $FASTQ_DIR --pipeline_status $PIPELINE_STATUS)
    echo -e "\nsbatch --dependency=afterok:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 1 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    DEPENDER=$(sbatch --dependency=afterok:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 1 ${OPTIONS[@]})
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif [ $STEP -eq 0 ] && [ $ELEMENT -eq 1 ]; then
    echo "### Step 0 - Demultiplexing ### - START: $(date)" >> $PIPELINE_STATUS
    echo "Element type demultiplexing specified" >> $PIPELINE_STATUS
    echo -e "\nsbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/0_element_demultiplex.sh \
        --run_dir $RUN_DIR --fastq_dir $FASTQ_DIR --pipeline_status $PIPELINE_STATUS\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/0_element_demultiplex.sh \
        --run_dir $RUN_DIR --fastq_dir $FASTQ_DIR --pipeline_status $PIPELINE_STATUS)
    echo -e "\nsbatch --parsable --dependency=afterok:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 1 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    DEPPENDER=$(sbatch --parsable --dependency=afterok:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 1 ${OPTIONS[@]})
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif ([ $STEP -eq 0 ] && [ -z $RUN_DIR ] && [ $ONLY_VARIANT_CALL -eq 0 ]) || [ $STEP -eq 1 ]; then
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}" >> $PIPELINE_STATUS
        echo "### Step 1 - BAM construction ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        echo -e "Jobs: $JOB_COUNT" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
        mkdir -p Extra_Sentieon_Files
    fi
    
    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} -p cgawad ${SCRIPT_DIR}/1_sentieon_BAM_construction.sh \
        --scratch_dir $SCRATCH_DIR --skip_trimmomatic $SKIP_TRIMMOMATIC --script_dir $SCRIPT_DIR \
        --tools_dir $TOOLS_DIR --R1_suffix $R1_SUFFIX --R2_suffix $R2_SUFFIX --ref_fasta $REF_FASTA \
        --ref_name $REF_NAME --sample_string $TEMP_SAMPLES_STRING --fastq_dir $FASTQ_DIR \
         --targets_bed $TARGETS_BED --rna $RNA --bam_suffix $BAM_SUFFIX\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} -p cgawad ${SCRIPT_DIR}/1_sentieon_BAM_construction.sh \
        --scratch_dir $SCRATCH_DIR --skip_trimmomatic $SKIP_TRIMMOMATIC --script_dir $SCRIPT_DIR \
        --tools_dir $TOOLS_DIR --R1_suffix $R1_SUFFIX --R2_suffix $R2_SUFFIX --ref_fasta $REF_FASTA \
        --ref_name $REF_NAME --sample_string $TEMP_SAMPLES_STRING --fastq_dir $FASTQ_DIR \
         --targets_bed $TARGETS_BED --rna $RNA --bam_suffix $BAM_SUFFIX)
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    echo -e "$(date)\nIncrement: $TEMP_ARRAY_INCREMENT\nNew start: $TEMP_ARRAY_START" >> $PIPELINE_STATUS
    
    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 1 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 1 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]})
        echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
    else
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 2 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 2 ${OPTIONS[@]})
        echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
    fi
elif [ $STEP -eq 2 ]; then
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        SAMPLE_COUNT=1
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -f ${SCRATCH_DIR}/${SAMPLE}${BAM_SUFFIX} ]; then
                echo -e "\tSample number $SAMPLE_COUNT - ${SAMPLE}${BAM_SUFFIX} file not found" >> $PIPELINE_STATUS
            fi
            SAMPLE_COUNT=$((SAMPLE_COUNT+1))
        done
        BAM_FILE_COUNT=$(ls *${SCRATCH_DIR}/${BAM_SUFFIX} | wc -l)
        if [ $BAM_FILE_COUNT -eq 0 ]; then
            echo "No BAMs found. Exiting with code 1" >> $PIPELINE_STATUS
            echo "END: $(date)" >> $PIPELINE_STATUS
            exit 1
        else
            echo "$BAM_FILE_COUNT BAM files out of a possible ${#SAMPLE_ARRAY[@]} maximum" >> $PIPELINE_STATUS
        fi
        echo "### Step 1 - BAM construction ### - END: $(date)" >> $PIPELINE_STATUS
        SAMPLE_ARRAY=( $(find $SCRATCH_DIR -maxdepth 1 -name "*${BAM_SUFFIX}" -exec basename {} \; | sed "s/$BAM_SUFFIX//") )
        echo "### Step 2 - QC metrics ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        TEMP_ARRAY_START=1
    fi

    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} -p cgawad ${SCRIPT_DIR}/2_metrics_calc.sh \
        --scratch_dir $SCRATCH_DIR --script_dir $SCRIPT_DIR --tools_dir $TOOLS_DIR --ref_fasta $REF_FASTA \
        --sample_string $TEMP_SAMPLES_STRING --targeted $TARGETED --targets_bed $TARGETS_BED \
        --interval_list $INTERVAL_LIST --bam_suffix $BAM_SUFFIX" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} -p cgawad ${SCRIPT_DIR}/2_metrics_calc.sh \
        --scratch_dir $SCRATCH_DIR --script_dir $SCRIPT_DIR --tools_dir $TOOLS_DIR --ref_fasta $REF_FASTA \
        --sample_string $TEMP_SAMPLES_STRING --targeted $TARGETED --targets_bed $TARGETS_BED \
        --interval_list $INTERVAL_LIST --bam_suffix $BAM_SUFFIX)
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    echo -e "$(date)\nIncrement: $TEMP_ARRAY_INCREMENT\nNew start: $TEMP_ARRAY_START" >> $PIPELINE_STATUS
    
    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 2 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 2 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]})
    else
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 3 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 3 ${OPTIONS[@]})
    fi
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif [ $STEP -eq 3 ] && [ $SCAN2 -eq 1 ] && [ $TEMP_ARRAY_START -eq 0 ]; then
    echo "### Step 2 - QC metrics ### - END: $(date)" >> $PIPELINE_STATUS
    echo "### Asynchronous Scan2 ### - $(date)" >> $PIPELINE_STATUS
    SAMPLE_ARRAY=( $(find $SCRATCH_DIR -maxdepth 1 -name "*${BAM_SUFFIX}" -exec basename {} \; | sed "s/$BAM_SUFFIX//") )
    JOB_COUNT=${#SAMPLE_ARRAY[@]}
    echo "Jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
    SAMPLES_STRING=$( IFS=$':'; echo "${SAMPLE_ARRAY[*]}" )
    NORMAL_PATH="${SCRATCH_DIR}/${NORMAL_SAMPLE_NAME}${BAM_SUFFIX}"
    #For SCAN2 should only include autosomal chromosomes for WGS
    if [ $TARGETED -eq 0 ]; then
        INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n22chr.bed"
    else
        INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel_targets_grch38_n22chr_noXYUns.interval_list"
        TARGETS_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_3col_autosomes_SCAN2.bed"
    fi
    echo "\nsbatch --time=7-00:00:00 -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/3_scan2.sh \
        --project $PROJECT --scratch_dir $SCRATCH_DIR --genome_version $ANNOVAR_GENOME_VERSION \
        --script_dir $SCRIPT_DIR --normal_path $NORMAL_PATH --sample_string $SAMPLES_STRING \
        --std_err_out $STD_ERR_OUT_DIR --normal_name $NORMAL_SAMPLE_NAME  --pipeline_dir $PIPELINE_DIR \
        --targeted $TARGETED --targets_bed $TARGETS_BED --interval_list $INTERVAL_LIST \
        --annovar_dir $ANNOVAR_DIR --skip_panel $SKIP_PANEL --cross_dir $CROSS_SAMPLE_DIR\n" >> $PIPELINE_STATUS
    sbatch --time=7-00:00:00 -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/3_scan2.sh \
        --project $PROJECT --scratch_dir $SCRATCH_DIR --genome_version $ANNOVAR_GENOME_VERSION \
        --script_dir $SCRIPT_DIR --normal_path $NORMAL_PATH --sample_string $SAMPLES_STRING \
        --std_err_out $STD_ERR_OUT_DIR --normal_name $NORMAL_SAMPLE_NAME  --pipeline_dir $PIPELINE_DIR \
        --targeted $TARGETED --targets_bed $TARGETS_BED --interval_list $INTERVAL_LIST \
        --annovar_dir $ANNOVAR_DIR --skip_panel $SKIP_PANEL --cross_dir $CROSS_SAMPLE_DIR
    sbatch -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 3 ${OPTIONS[@]}
elif [ $STEP -eq 3 ] && [ $TEMP_ARRAY_START -eq 0 ]; then
    if [ $SCAN2 -eq 0 ]; then
        echo "### Step 2 - QC metrics ### - END: $(date)" >> $PIPELINE_STATUS
    fi
    echo "### Asynchronous merge metrics ### - $(date)" >> $PIPELINE_STATUS
    if [ $TARGETED -eq 0 ]; then
        echo -e "\nsbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/3_ginkgo_cnv.sh \
            --bam_dir $SCRATCH_DIR --scratch_dir ${SCRATCH_DIR}/ginkgo_5M --bam_regex .5M.bam \
            --bam_suffix .5M.bam --project 5M\n" >> $PIPELINE_STATUS
        sbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/3_ginkgo_cnv.sh \
            --bam_dir $SCRATCH_DIR --scratch_dir ${SCRATCH_DIR}/ginkgo_5M --bam_regex .5M.bam \
            --bam_suffix .5M.bam --project 5M
        echo "Asynchronous ginkgo for 5 million reads submitted"
    fi
    if [ $TARGETED -eq 0 ] && [ ! -z $GINKGO_MB_ARRAY ]; then
        for MB_SIZE in ${GINKGO_MB_ARRAY[@]}; do
            echo -e "\nsbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
                ${SCRIPT_DIR}/3_ginkgo_cnv.sh \
                --bam_dir $SCRATCH_DIR --scratch_dir ${SCRATCH_DIR}/ginkgo_${MB_SIZE}M --bam_regex $BAM_SUFFIX \
                --bam_suffix $BAM_SUFFIX --project ${MB_SIZE}M --mb_size $MB_SIZE\n" >> $PIPELINE_STATUS
            sbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
                ${SCRIPT_DIR}/3_ginkgo_cnv.sh \
                --bam_dir $SCRATCH_DIR --scratch_dir ${SCRATCH_DIR}/ginkgo_${MB_SIZE}M --bam_regex $BAM_SUFFIX \
                --bam_suffix $BAM_SUFFIX --project ${MB_SIZE}M --mb_size $MB_SIZE
            echo "Asynchronous ginkgo for $MB_SIZE million reads submitted"
        done
    fi
    if [ ! -z $RUN_DIR ]; then
        echo -e "\nsbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/3_merge_metrics.sh \
            --scratch_dir $SCRATCH_DIR --script_dir $SCRIPT_DIR --project $PROJECT \
            --targeted $TARGETED --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET\n" >> $PIPELINE_STATUS
        sbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/3_merge_metrics.sh \
            --scratch_dir $SCRATCH_DIR --script_dir $SCRIPT_DIR --project $PROJECT \
            --targeted $TARGETED --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET
    else
        echo -e "\nsbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/3_merge_metrics.sh \
            --scratch_dir $SCRATCH_DIR --script_dir $SCRIPT_DIR --project $PROJECT --targeted $TARGETED\n" >> $PIPELINE_STATUS
        sbatch -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/3_merge_metrics.sh \
            --scratch_dir $SCRATCH_DIR --script_dir $SCRIPT_DIR --project $PROJECT --targeted $TARGETED
    fi
       
    if [ $SKIP_VARIANT_CALL -eq 1 ]; then
        echo "Ending without identfication of data" >> $PIPELINE_STATUS
        if [ "$SCRATCH_DIR" != "$RESULTS_DIR" ]; then
            echo "### Moving results from scratch dir to results dir ### - START: $(date)"
            rsync -ar $SCRATCH_DIR/ $RESULTS_DIR/
            echo "### Moving results from scratch dir to results dir ### - END: $(date)"
        fi
        echo "END: $(date)" >> $PIPELINE_STATUS
        exit 0
    fi
fi


if ([ $STEP -eq 0 ] && [ $ONLY_VARIANT_CALL -eq 1 ]) || [ $STEP -ge 3 ]; then
    SAMPLE_ARRAY=( $(find $SCRATCH_DIR -maxdepth 1 -name "*${BAM_SUFFIX}" -exec basename {} \; | sed "s/$BAM_SUFFIX//") )
    if [ ${#SAMPLE_ARRAY[@]} -eq 0 ]; then
        echo "No files ending with bam suffix $BAM_SUFFIX found in the results directory. Exiting with code 1" >> $PIPELINE_STATUS
        echo "END: $(date)" >> $PIPELINE_STATUS
        exit 1
    fi
fi


if [ $STEP -eq 3 ]; then
    # TODO-Get the variant calls to work and properly use this script's STEP stuff, i think just adding new steps is the way to go
    # TODO-Make script to generate panel of normal file ONCE, I think I'm just going to make a script you run seperately to do this
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        echo "### Step 3 - Germline variant calling ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        echo "Jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
    fi

    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/3_sentieon_germline_variant_calling.sh  \
        --scratch_dir $SCRATCH_DIR --ref_fasta $REF_FASTA --sample_string $TEMP_SAMPLES_STRING \
        --targets_bed $TARGETS_BED --bam_suffix $BAM_SUFFIX\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/3_sentieon_germline_variant_calling.sh  \
        --scratch_dir $SCRATCH_DIR --ref_fasta $REF_FASTA --sample_string $TEMP_SAMPLES_STRING \
        --targets_bed $TARGETS_BED --bam_suffix $BAM_SUFFIX)
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    echo -e "$(date)\nIncrement: $TEMP_ARRAY_INCREMENT\nNew start: $TEMP_ARRAY_START" >> $PIPELINE_STATUS

    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 3 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 3 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]})
    elif [ -z $NORMAL_SAMPLE_NAME ]; then
        echo "Skipping Step 4 Somatic variant calling, going directly to Step 5 Joint genotyping" >> $PIPELINE_STATUS
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 5 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 5 ${OPTIONS[@]})
    else
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 4 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 4 ${OPTIONS[@]})
    fi
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif [ $STEP -eq 4 ]; then
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        SAMPLE_COUNT=1
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -f ${SCRATCH_DIR}/${SAMPLE}_germline_call.g.vcf ]; then
                echo -e "\tSample number $SAMPLE_COUNT - ${SAMPLE}_germline_call.g.vcf file not found" >> $PIPELINE_STATUS
            fi
            SAMPLE_COUNT=$((SAMPLE_COUNT+1))
        done
        VCF_FILE_COUNT=$(ls ${SCRATCH_DIR}/*_germline_call.g.vcf | wc -l)
        if [ $VCF_FILE_COUNT -eq 0 ]; then
            echo "No VCFs found. Exiting with code 1" >> $PIPELINE_STATUS
            echo "END: $(date)" >> $PIPELINE_STATUS
            exit 1
        else
            echo "$VCF_FILE_COUNT VCF files out of a possible ${#SAMPLE_ARRAY[@]} maximum" >> $PIPELINE_STATUS
        fi
        echo "### Step 3 - Germline variant calling ### - END: $(date)" >> $PIPELINE_STATUS
        echo "### Step 4 - Somatic variant calling ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        echo "Jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
    fi
    
    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )     
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/4_sentieon_somatic_variant_calling.sh  \
        --scratch_dir $SCRATCH_DIR --reference_dir $REFERENCE_DIR --ref_fasta $REF_FASTA \
        --normal_sample_name $NORMAL_SAMPLE_NAME --sample_string $TEMP_SAMPLES_STRING \
        --dbSNP $DBSNP_VCF --targets_bed $TARGETS_BED --rna $RNA --bam_suffix $BAM_SUFFIX\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/4_sentieon_somatic_variant_calling.sh  \
        --scratch_dir $SCRATCH_DIR --reference_dir $REFERENCE_DIR --ref_fasta $REF_FASTA \
        --normal_sample_name $NORMAL_SAMPLE_NAME --sample_string $TEMP_SAMPLES_STRING \
        --dbSNP $DBSNP_VCF --targets_bed $TARGETS_BED --rna $RNA --bam_suffix $BAM_SUFFIX)
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    echo -e "$(date)\nIncrement: $TEMP_ARRAY_INCREMENT\nNew start: $TEMP_ARRAY_START" >> $PIPELINE_STATUS
    
    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 4 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 4 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]})
    else
        echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 5 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step 5 ${OPTIONS[@]})
    fi
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif [ $STEP -eq 5 ]; then
    if [ ! -z $NORMAL_SAMPLE_NAME ]; then
        SAMPLE_COUNT=1
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -f ${SCRATCH_DIR}/${SAMPLE}_variant.vcf ]; then
                echo -e "\tSample number $SAMPLE_COUNT - ${SAMPLE}_variant.vcf file not found" >> $PIPELINE_STATUS
            fi
            SAMPLE_COUNT=$((SAMPLE_COUNT+1))
        done
        VCF_FILE_COUNT=$(ls ${SCRATCH_DIR}/*_variant.vcf | wc -l)
        if [ $VCF_FILE_COUNT -eq 0 ]; then
            echo "No VCFs found. Exiting with code 1" >> $PIPELINE_STATUS
            echo "END: $(date)" >> $PIPELINE_STATUS
            exit 1
        else
            echo "$VCF_FILE_COUNT VCF files out of a possible ${#SAMPLE_ARRAY[@]} maximum" >> $PIPELINE_STATUS
        fi
        echo "### Step 4 - Somatic variant calling ### - END: $(date)" >> $PIPELINE_STATUS
    else
        SAMPLE_COUNT=1
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -f ${SCRATCH_DIR}/${SAMPLE}_germline_call.g.vcf ]; then
                echo -e "\tSample number $SAMPLE_COUNT - ${SAMPLE}_germline_call.g.vcf file not found" >> $PIPELINE_STATUS
            fi
            SAMPLE_COUNT=$((SAMPLE_COUNT+1))
        done
        VCF_FILE_COUNT=$(ls ${SCRATCH_DIR}/*_germline_call.g.vcf | wc -l)
        if [ $VCF_FILE_COUNT -eq 0 ]; then
            echo "No VCFs found. Exiting with code 1" >> $PIPELINE_STATUS
            echo "END: $(date)" >> $PIPELINE_STATUS
            exit 1
        else
            echo "$VCF_FILE_COUNT VCF files out of a possible ${#SAMPLE_ARRAY[@]} maximum" >> $PIPELINE_STATUS
        fi
        echo "### Step 3 - Germline variant calling ### - END: $(date)" >> $PIPELINE_STATUS
    fi
    echo "### Step 5 - Germline joint genotyping and merge somatic variant VCFs  ### - START: $(date)" >> $PIPELINE_STATUS
    echo "### Germline joint genotyping ### - $(date)" >> $PIPELINE_STATUS
    echo -e "\nsbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/5_sentieon_joint_genotyping.sh \
        --scratch_dir $SCRATCH_DIR --ref_fasta $REF_FASTA \
        --project $PROJECT --targets_bed $TARGETS_BED\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/5_sentieon_joint_genotyping.sh \
        --scratch_dir $SCRATCH_DIR --ref_fasta $REF_FASTA \
        --project $PROJECT --targets_bed $TARGETS_BED)
    if [ ! -z $NORMAL_SAMPLE_NAME ]; then
        echo "### Merge somatic variant VCFs ### - $(date)" >> $PIPELINE_STATUS
        echo -e "\nsbatch -e ${STD_ERR_OUT_DIR}/%A_%a_%x.err -o ${STD_ERR_OUT_DIR}/%A_%a_%x.out \
            --parsable ${SCRIPT_DIR}/5_vcf_concat.sh \
            --scratch_dir $SCRATCH_DIR --project $PROJECT\n" >> $PIPELINE_STATUS
        DEPENDENCY="$DEPENDENCY:$(sbatch -e ${STD_ERR_OUT_DIR}/%A_%a_%x.err -o ${STD_ERR_OUT_DIR}/%A_%a_%x.out \
            --parsable ${SCRIPT_DIR}/5_vcf_concat.sh \
            --scratch_dir $SCRATCH_DIR --project $PROJECT)"
    fi
    echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 6 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 6 ${OPTIONS[@]})
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif [ $STEP -eq 6 ]; then
    if [ ! -z $NORMAL_SAMPLE_NAME ]; then
        if [ ! -f ${PROJECT}.somatic_merged.vcf.gz ]; then
            echo "Final file ${PROJECT}.somatic_merged.vcf.gz not found. Exiting with code 1"
            exit 1
        fi
    fi
    if [ ! -f ${PROJECT}.germline_merged.vcf.gz ]; then
        echo "Final file ${PROJECT}.germline_merged.vcf.gz not found. Exiting with code 1"
        exit 1
    fi
    echo "### Step 5 - Germline joint genotyping and merge somatic variant VCFs  ### - END: $(date)" >> $PIPELINE_STATUS
    echo "### Step 6 - Annotation ### - START: $(date)" >> $PIPELINE_STATUS
    ####TODO#####
    # TODO: Should make a script that deletes the rows with normal sample name in them, might just do it in python but could use shell script to and itd be faster
    # TODO: Get sigprofiler to work (it doesn't now), get other stuff from annotation thing to work
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err \
        -o $STD_ERR_OUT_DIR/%A_%a_%x.out ${SCRIPT_DIR}/6_annovar.sh \
        --somatic_germline germline --tranche $TRANCHE --script_dir $SCRIPT_DIR \
        --annovar_genome_version $ANNOVAR_GENOME_VERSION --annovar_dir $ANNOVAR_DIR \
        --tools_dir $TOOLS_DIR --scratch_dir $SCRATCH_DIR --std_err_out_dir $STD_ERR_OUT_DIR \
        --reference_dir $REFERENCE_DIR --targeted $TARGETED --ref_fasta $REF_FASTA \
        --normal_sample_name $NORMAL_SAMPLE_NAME --project $PROJECT\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err \
        -o $STD_ERR_OUT_DIR/%A_%a_%x.out ${SCRIPT_DIR}/6_annovar.sh \
        --somatic_germline germline --tranche $TRANCHE --script_dir $SCRIPT_DIR \
        --annovar_genome_version $ANNOVAR_GENOME_VERSION --annovar_dir $ANNOVAR_DIR \
        --tools_dir $TOOLS_DIR --scratch_dir $SCRATCH_DIR --std_err_out_dir $STD_ERR_OUT_DIR \
        --reference_dir $REFERENCE_DIR --targeted $TARGETED --ref_fasta $REF_FASTA \
        --normal_sample_name $NORMAL_SAMPLE_NAME --project $PROJECT)
    if [ ! -z $NORMAL_SAMPLE_NAME ]; then
        echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err \
            -o $STD_ERR_OUT_DIR/%A_%a_%x.out ${SCRIPT_DIR}/6_annovar.sh \
            --somatic_germline somatic --tranche $TRANCHE --script_dir $SCRIPT_DIR \
            --annovar_genome_version $ANNOVAR_GENOME_VERSION --annovar_dir $ANNOVAR_DIR \
            --tools_dir $TOOLS_DIR --scratch_dir $SCRATCH_DIR --std_err_out_dir $STD_ERR_OUT_DIR \
            --reference_dir $REFERENCE_DIR --targeted $TARGETED --ref_fasta $REF_FASTA \
            --normal_sample_name $NORMAL_SAMPLE_NAME --project $PROJECT\n" >> $PIPELINE_STATUS
        DEPENDENCY="$DEPENDENCY:$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err \
            -o $STD_ERR_OUT_DIR/%A_%a_%x.out ${SCRIPT_DIR}/6_annovar.sh \
            --somatic_germline somatic --tranche $TRANCHE --script_dir $SCRIPT_DIR \
            --annovar_genome_version $ANNOVAR_GENOME_VERSION --annovar_dir $ANNOVAR_DIR \
            --tools_dir $TOOLS_DIR --scratch_dir $SCRATCH_DIR --std_err_out_dir $STD_ERR_OUT_DIR \
            --reference_dir $REFERENCE_DIR --targeted $TARGETED --ref_fasta $REF_FASTA \
            --normal_sample_name $NORMAL_SAMPLE_NAME --project $PROJECT)"
    fi
    echo -e "\nsbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 7 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 7 ${OPTIONS[@]})
    echo -e "Dependency job array number: $DEPENDENCY\nDepender job number: $DEPENDER" >> $PIPELINE_STATUS
elif [ $STEP -eq 7 ]; then
    if [ ! -z $NORMAL_SAMPLE_NAME ]; then
        if [ ! -f ${PROJECT}.somatic_extract_snp.vcf.gz ]; then
            echo "Final file ${PROJECT}.somatic_extract_snp.vcf.gz not found. Exiting with code 1"
            exit 1
        fi
    fi
    if [ ! -f ${PROJECT}.germline_extract_snp.vcf.gz ]; then
        echo "Final file ${PROJECT}.germline_extract_snp.vcf.gz not found. Exiting with code 1"
        exit 1
    fi
    echo "### Step 6 - Annotation ### - END: $(date)" >> $PIPELINE_STATUS
    echo "### Step 7 - Structural variant call ### - START: $(date)" >> $PIPELINE_STATUS

    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.err \
        ${SCRIPT_DIR}/7_filter_annotated_variants.sh \
        --project $PROJECT --scratch_dir $SCRATCH_DIR --pipeline_dir $PIPELINE_DIR \
        --std_err_out_dir $STD_ERR_OUT_DIR --targeted $TARGETED\n" >> $PIPELINE_STATUS
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.err \
        ${SCRIPT_DIR}/7_filter_annotated_variants.sh \
        --project $PROJECT --scratch_dir $SCRATCH_DIR --pipeline_dir $PIPELINE_DIR \
        --std_err_out_dir $STD_ERR_OUT_DIR --targeted $TARGETED)
    if [ $MANTA -eq 1 ]; then
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        echo "Jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
        SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
        echo "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/7_manta_sv.sh \
            --sample_string $SAMPLES_STRING --ref_fasta $REF_FASTA --scratch_dir $SCRATCH_DIR \
            --scratch_dir $SCRATCH_DIR --targeted $TARGETED\n" >> $PIPELINE_STATUS
        DEPENDENCY="$DEPENDENCY:$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/7_manta_sv.sh \
            --sample_string $SAMPLES_STRING --ref_fasta $REF_FASTA --scratch_dir $SCRATCH_DIR \
            --scratch_dir $SCRATCH_DIR --targeted $TARGETED)"
        echo "Asynchronous manta jobs submitted"
    fi
    DEPENDER=$(sbatch --parsable --dependency=afterany:$DEPENDENCY -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step 8 ${OPTIONS[@]})
elif [ $STEP -eq 8 ]; then
    echo "### Step 7 - Structural variant call ### - END: $(date)" >> $PIPELINE_STATUS
    if [ "$SCRATCH_DIR" != "$RESULTS_DIR" ]; then
        echo "### Moving results from scratch dir to results dir ### - START: $(date)"
        mkdir -p $SCRATCH_DIR/01_final_outputs
        rsync -a --exclude '01_final_outputs' $SCRATCH_DIR/01* $SCRATCH_DIR/01_final_outputs/
        rsync -ar $SCRATCH_DIR/ $RESULTS_DIR/
        echo "### Moving results from scratch dir to results dir ### - END: $(date)"
    fi
    echo "END: $(date)" >> $PIPELINE_STATUS
fi
