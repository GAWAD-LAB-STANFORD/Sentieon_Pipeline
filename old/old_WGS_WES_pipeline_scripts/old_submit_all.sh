#!/bin/bash
#
#SBATCH --job-name=submit_all
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=5:00:00
#SBATCH --partition=cgawad

PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"
HELP="\
Purpose: \n\t\
    This pipeline is built to call CNVs, Indels, and SNPs from Whole Genome or Exome Sequencing pair-end fastq.gz files \n\n\
Required arguments: -p/--project <arg> and either -f/--fastq_dir <arg> or -r/--results_dir <arg> \n\
Optional arguments: -b/--run_dir <arg>, --sample_sheet <arg>, --R1_suffix <arg>, --R2_suffix <arg>, --err_out_dir <arg>, \n\t\
    --b37, --cell_barcodes <arg>, --umi_pattern <arg>, --skip_trimming, --novaseq_wgs, --mapq_min <arg>, --dup_mark_again, \n\t
    --skip_dup_mark, --remove_dups, --dup_pixel_distance <arg>, --no_variant_class, --bam_suffix <arg>, --scan2_bulk <arg>, \n\t\
    --skip_scan2, --skip_methylation, --skip_variant_call, --only_variant_call \n\t\
    --monovar, --clean_deep_seq, --gatk, --keep_reference, --exome, --panel_bed <arg>, --panel_interval_list <arg>, \n\t\
    --parallel <arg>, --genomics_db_import, --tranche <arg>, --skip_circle_map, --slurm <arg> \n\
Defaults: \n\t\
    If no fastq_dir specified, uses results_dir \n\t\
    If no results_dir specified, makes new directory in fastq_dir \n\t\
    sample_sheet: SampleSheet.csv \n\t\
    R1_suffix: _L001_R1_001.fastq.gz or _R1_001.fastq.gz \n\t\
    R2_suffix: _L001_R2_001.fastq.gz or _R1_001.fastq.gz \n\t\
    Runs WGS unless --exome specified \n\t\t\
        or unless --panel_bed <arg> and --panel_interval_list <arg> specified \n\t\
    dup_pixel_distance: 100 \n\t\
    Bam suffix: .bqsr.marked.bam \n\t\t\
        or .bqsr.unmarked.bam when running with --skip_dup_mark \n\t\t\
        or customizable when running with --only_variant_call \n\t\
    parallel: 25 \n\t\
    tranche: 99.9 \n\n\
Run after demultiplexing: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --fastq_dir /oak/stanford/groups/cgawad/MRD_project/ --project MRD_project \n\n\
Run with demultiplexing: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --run_dir /oak/stanford/groups/cgawad/Illumina_Data/MiniSeq/191126_MN01236_0003_A000H2WWHT --fastq_dir /oak/stanford/groups/cgawad/MRD_project/ --project MRD_project \n\n\
Run with demultiplexing, wait 12 hours before starting, and email notification when analysis begins and ends: \n\t\
    sh ${PIPELINE_DIR}/submit_all.sh --run_dir /oak/stanford/groups/cgawad/Illumina_Data/MiniSeq/191126_MN01236_0003_A000H2WWHT --fastq_dir /oak/stanford/groups/cgawad/MRD_project/ --project MRD_project --slurm --begin=now+12hours --mail-type=BEGIN \n\n\
For more information, read the README.md"

# Reads in command line option arguments and assigns them to variables
GENOME_VERSION=hg38
RNA=0
CELL_BARCODES=0
UMI_PATTERN=0
SKIP_TRIMMOMATIC=0
NOVASEQ_WGS=0
MAPQ_MIN=0
DUP_MARK_AGAIN=0
SKIP_DUPLICATE_MARKING=0
REMOVE_DUPS=0
DUPLICATE_PIXEL_DISTANCE=100
VARIANT_CLASS=1
BAM_SUFFIX=".bqsr.marked.bam"
SCAN2_BULK=0
SCAN2=1
SKIP_VARIANT_CALL=0
ONLY_VARIANT_CALL=0
METHYLATION=1
MONOVAR=0
CLEAN_DEEP_SEQ=0
GATK=0
TARGETED=0
BP_RESOLUTION=0
PANEL_BED=0
PANEL_INTERVAL_LIST=0
GATK_SCATTERED_CALLING=25
GENOMICS_DB_IMPORT=0
PANEL_PARALLEL=0
TRANCHE="99.9"
CIRCLE_MAP=1
CDS_STEP=1
STEP=0
STEP3_REPEAT=0
TEMP_ARRAY_START=0
PREVIOUS_CHECK=0
DEPENDENCIES=()
while [ "$1" != "" ]; do
    case $1 in
        -h | --help )           echo -e $HELP
                                exit 0
                                ;;
        -b | --run_dir )        shift
                                RUN_DIR=$1
                                ;;
        --sample_sheet )        shift
                                SAMPLE_SHEET=$1
                                ;;
        --R1_suffix )           shift
                                R1_SUFFIX=$1
                                ;;
        --R2_suffix )           shift
                                R2_SUFFIX=$1
                                ;;
        --err_out_dir )         shift
                                STD_ERR_OUT_DIR=$1
                                ;;
        -f | --fastq_dir )      shift
                                FASTQ_DIR=$1
                                ;;
        -r | --results_dir )    shift
                                RESULTS_DIR=$1
                                ;;
        -p | --project )        shift
                                PROJECT=$1
                                ;;
        -d | --pipeline_dir )   shift
                                PIPELINE_DIR=$1
                                ;;
        --b37 )                 GENOME_VERSION=b37
                                ;;
        --rna )                 RNA=1
                                ;;
        --cell_barcodes )       shift
                                CELL_BARCODES=$1
                                ;;
        --umi_pattern )         shift
                                UMI_PATTERN=$1
                                ;;
        --skip_trimming )       SKIP_TRIMMOMATIC=1
                                ;;
        --novaseq_wgs )         NOVASEQ_WGS=1
                                ;;
        --mapq_min )            shift
                                MAPQ_MIN=$1
                                ;;
        --dup_mark_again )      DUP_MARK_AGAIN=1
                                ;;
        --skip_dup_mark )       SKIP_DUPLICATE_MARKING=1
                                ;;
        --remove_dups )         REMOVE_DUPS=1
                                ;;
        --dup_pixel_distance )  shift
                                DUPLICATE_PIXEL_DISTANCE=$1
                                ;;
        --no_variant_class )    VARIANT_CLASS=0
                                ;;
        --bam_suffix )          shift
                                BAM_SUFFIX=$1
                                ;;
        --scan2_bulk )          shift
                                SCAN2_BULK=$1
                                ;;
        --skip_scan2 )          SCAN2=0
                                ;;
        --skip_variant_call )   SKIP_VARIANT_CALL=1
                                ;;
        --only_variant_call )   ONLY_VARIANT_CALL=1
                                ;;
        --skip_methylation )    METHYLATION=0
                                ;;
        --monovar )             MONOVAR=1
                                ;;
        --clean_deep_seq )      CLEAN_DEEP_SEQ=1
                                ;;
        --gatk )                GATK=1
                                ;;
        --keep_reference )      BP_RESOLUTION=1
                                ;;
        --exome )               TARGETED=1
                                ;;
        --panel_bed )           shift
                                PANEL_BED=$1
                                ;;
        --panel_interval_list ) shift
                                PANEL_INTERVAL_LIST=$1
                                ;;
        --parallel )            shift
                                GATK_SCATTERED_CALLING=$1
                                ;;
        --genomics_db_import )  GENOMICS_DB_IMPORT=1
                                ;;
        --tranche )             shift
                                TRANCHE=$1
                                ;;
        --skip_circle_map )     CIRCLE_MAP=0
                                ;;
        --cds_step2 )           CDS_STEP=2
                                ;;
        --step1 )               STEP=1
                                ;;
        --step2 )               STEP=2
                                ;;
        --step3 )               STEP=3
                                ;;
        --step4 )               STEP=4
                                ;;
        --step5 )               STEP=5
                                ;;
        --step6 )               STEP=6
                                ;;
        --step3_repeat )        STEP3_REPEAT=1
                                ;;
        --temp_array_start )    shift
                                TEMP_ARRAY_START=$1
                                ;;
        --previous_check )      PREVIOUS_CHECK=1
                                ;;
        --slurm )               shift
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
CLEAN_DEEP_SEQ_TOOL_DIR="${PIPELINE_DIR}/CleanDeepSeq_Tool"

# hg38 reference files
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
BISMARK_GENOME="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Bismark"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
REF_GENOME="${REFERENCE_DIR}/Homo_sapiens_assembly38_bedtools.genome"
N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_n25chr.bed"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
WGS_SCATTERED_CALLINGS="${REFERENCE_DIR}/wgs_calling_regions.hg38.interval_list"
INTERVAL_STRING="chr1_chr2_chr3_chr4_chr5_chr6_chr7_chr8_chr9_chr10_chr11_chr12_chr13_chr14_chr15_chr16_chr17_chr18_chr19_chr20_chr21_chr22_chrX_chrY_chrM"
SCATTERED_CALLING_DIR="${REFERENCE_DIR}/scattered_calling_intervals"
EXOME_TARGETS_BED="${REFERENCE_DIR}/xgen-exome-research-panel-targets_grch38_3col.bed"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/xgen-exome-research-panel-targets_grch38_5col.interval_list"
INTERVAL_ARRAY=( $(echo $INTERVAL_STRING | sed 's/_/ /g') )

# hg19 version b37 reference files
if [ "$GENOME_VERSION" = "b37" ]; then
    REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_b37"
    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
    REF_GENOME="${REFERENCE_DIR}/human_g1k_v37.genome"
    N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/human_g1k_v37_n25chr.interval_list"
    N25CHR_BED="${REFERENCE_DIR}/human_g1k_v37_n25chr.bed"
    DBSNP_VCF="${REFERENCE_DIR}/dbsnp_138.b37.vcf.gz"
    WGS_SCATTERED_CALLINGS="${REFERENCE_DIR}/wgs_calling_regions.v1.interval_list"
    INTERVAL_STRING="1_2_3_4_5_6_7_8_9_10_11_12_13_14_15_16_17_18_19_20_21_22_X_Y_M"
    SCATTERED_CALLING_DIR="${REFERENCE_DIR}/scattered_calling_intervals"
    EXOME_TARGETS_BED="${REFERENCE_DIR}/xgen-exome-research-panel-v2-targets_b37_3col.bed"
    EXOME_INTERVAL_LIST="${REFERENCE_DIR}/xgen-exome-research-panel-v2-targets_b37_5col.interval_list"
    INTERVAL_ARRAY=( $(echo $INTERVAL_STRING | sed 's/_/ /g') )
fi

# Ensure we have the requires variables set and set other variables
if ([ -z $FASTQ_DIR ] && [ -z $RESULTS_DIR ]) || [ -z $PROJECT ] || [ -z $PIPELINE_DIR ]; then
    echo "Variables not supplied correctly. Use -h/--help options for assistance. Exiting with code 1"
    exit 1
fi
if [ -z $FASTQ_DIR ]; then
    FASTQ_DIR="$RESULTS_DIR"
elif [ -z $RESULTS_DIR ]; then
    RESULTS_DIR="${FASTQ_DIR}/$(date '+%Y-%m-%d')_${PROJECT}_Results"
fi
if [ -z $STD_ERR_OUT_DIR ]; then
    STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
fi
# Make results and std error output directories if they don't exist
if [ ! -d $FASTQ_DIR ]; then
    mkdir $FASTQ_DIR
fi
if [ ! -d $RESULTS_DIR ]; then
    mkdir $RESULTS_DIR
fi
if [ ! -d $STD_ERR_OUT_DIR ]; then
    mkdir $STD_ERR_OUT_DIR
fi
OPTIONS=( "--err_out_dir $STD_ERR_OUT_DIR -f $FASTQ_DIR -r $RESULTS_DIR -d $PIPELINE_DIR -p $PROJECT" )
if [ ! -z $RUN_DIR ] && [ $ONLY_VARIANT_CALL -eq 1 ]; then
    echo "Variables not supplied correctly. Cannot perform demultiplexing while only calling variants. Exiting with code 1"
    exit 1
fi
if [ ! -z $RUN_DIR ] && [ -z $SAMPLE_SHEET ]; then
    SAMPLE_SHEET="${RUN_DIR}/SampleSheet.csv"
elif [ ! -z $SAMPLE_SHEET ]; then
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
if [ ! -z $R1_SUFFIX ]; then
    OPTIONS+=( "--R1_suffix $R1_SUFFIX" )
fi
if [ ! -z $R2_SUFFIX ]; then
    OPTIONS+=( "--R2_suffix $R2_SUFFIX" )
fi
if [ "$GENOME_VERSION" = "b37" ]; then
    OPTIONS+=( "--b37" )
fi
if [ $RNA -eq 1 ]; then
    OPTIONS+=( "--rna" )
    if [ "$BAM_SUFFIX" == ".bqsr.marked.bam" ]; then
        BAM_SUFFIX=".rna.bam"
    fi
    SKIP_TRIMMOMATIC=1
    SKIP_VARIANT_CALL=1
fi
if [ "$CELL_BARCODES" != "0" ]; then
    OPTIONS+=( "--cell_barcodes $CELL_BARCODES" )
    NUMBER_OF_BARCODES=$(echo $CELL_BARCODES | wc -l)
    if [ $NUMBER_OF_BARCODES -eq 0 ]; then
        echo "No barcodes found in specified barcode file. Exiting with code 1"
        exit 1
    fi
elif [ "$UMI_PATTERN" != "0" ]; then
    OPTIONS+=( "--umi_pattern $UMI_PATTERN" )
elif [ "$CELL_BARCODES" != "0" ] && [ "$UMI_PATTERN" != "0" ]; then
    echo "Variables not supplied correctly. Either specify --cell_barcodes or --umi_pattern, not both. Exiting with code 1"
    exit 1
fi
if [ $SKIP_TRIMMOMATIC -eq 1 ]; then
    OPTIONS+=( "--skip_trimming" )
fi
if [ $MAPQ_MIN -ne 0 ]; then
    OPTIONS+=( "--mapq_min $MAPQ_MIN" )
fi
if [ $NOVASEQ_WGS -eq 1 ]; then
    OPTIONS+=( "--novaseq_wgs" )
fi
if [ $DUP_MARK_AGAIN -eq 1 ]; then
    STEP=3
fi
if [ $SKIP_DUPLICATE_MARKING -eq 1 ]; then
    OPTIONS+=( "--skip_dup_mark" )
    DUPLICATE_PIXEL_DISTANCE=0
    if [ $BAM_SUFFIX == ".bqsr.marked.bam" ]; then
        BAM_SUFFIX=".bqsr.unmarked.bam"
    fi
fi
if [ $REMOVE_DUPS -eq 1 ]; then
    OPTIONS+=( "--remove_dups" )
fi
if [ $DUPLICATE_PIXEL_DISTANCE -ne 100 ]; then
    OPTIONS+=( "--dup_pixel_distance $DUPLICATE_PIXEL_DISTANCE" )
fi
if [ $VARIANT_CLASS -eq 0 ]; then
    OPTIONS+=( "--no_variant_class" )
fi
if [ $BAM_SUFFIX != ".bqsr.marked.bam" ]; then
    OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
fi
if [ $CIRCLE_MAP -eq 0 ]; then
    OPTIONS+=( "--skip_circle_map" )
fi
if [ $SKIP_VARIANT_CALL -eq 1 ] && [ $ONLY_VARIANT_CALL -eq 1 ]; then
    echo "Variables not supplied correctly. Please specify either --skip_variant_call or --only_variant_call, not both. Exiting with code 1"
    exit 1
elif [ $SKIP_VARIANT_CALL -eq 1 ]; then
    OPTIONS+=( "--skip_variant_call" )
elif [ $ONLY_VARIANT_CALL -eq 1 ]; then
    OPTIONS+=( "--only_variant_call" )
    if [ $STEP -eq 0 ]; then
        STEP=4
    fi
fi
if [ $METHYLATION -eq 0 ]; then
    OPTIONS+=( "--skip_methylation" )
fi
if [ $MONOVAR -eq 1 ]; then
    OPTIONS+=( "--monovar" )
fi
if [ $CLEAN_DEEP_SEQ -eq 1 ] && [ $GATK -eq 0 ]; then
    OPTIONS+=( "--clean_deep_seq" )
fi
if [ $CLEAN_DEEP_SEQ -eq 1 ] && [ $GATK -eq 1 ]; then
    OPTIONS+=( "--gatk" )
    GATK=1
fi
if [ $CLEAN_DEEP_SEQ -eq 0 ]; then
    GATK=1
fi
if [ $BP_RESOLUTION -eq 1 ]; then
    OPTIONS+=( "--keep_reference" )
fi
if [ "$PANEL_BED" != "0" ] && [ "$PANEL_INTERVAL_LIST" != "0" ]; then
    OPTIONS+=( "--panel_bed $PANEL_BED --panel_interval_list $PANEL_INTERVAL_LIST" )
    TARGETED=1
    TARGETS_BED=${PROJECT}.temporary_3_column_bed_interval_file.bed
    INTERVAL_LIST=$PANEL_INTERVAL_LIST
elif [ "$PANEL_BED" != "0" ] || [ "$PANEL_INTERVAL_LIST" != "0" ]; then
    echo "Variables not supplied correctly. Specify both --panel_bed and --panel_interval_list, or neither. Exiting with code 1"
    exit 1
else
    if [ $TARGETED -eq 1 ]; then
        OPTIONS+=( "--exome" )
        TARGETS_BED=$EXOME_TARGETS_BED
        INTERVAL_LIST=$EXOME_INTERVAL_LIST
    else
        TARGETS_BED=$N25CHR_BED
        INTERVAL_LIST=$N25CHR_INTERVAL_LIST
    fi
fi
if [ "$GATK_SCATTERED_CALLING" = "25" ] && [ "$GENOME_VERSION" = "b37" ]; then
    if [ "$TEMP_PIPELINE_DIR" = "$PIPELINE_DIR" ]; then
        echo "Switching scattered calling from 25 to 50 because 25 is not supported with b37"
    fi
    GATK_SCATTERED_CALLING="50"
fi
if [ "$GATK_SCATTERED_CALLING" != "25" ]; then
    OPTIONS+=( "--parallel $GATK_SCATTERED_CALLING" )
fi
if [ $GENOMICS_DB_IMPORT -eq 1 ]; then
    OPTIONS+=( "--genomics_db_import" )
fi
if [ "$TRANCHE" != "90.0" ]; then
    OPTIONS+=( "--tranche $TRANCHE" )
fi
if [ $STEP3_REPEAT -eq 1 ]; then
    OPTIONS+=( "--step3_repeat" )
    DUP_MARK_AGAIN=1
    STEP=3
fi
if [ $STEP -eq 0 ] && [ -z $RUN_DIR ]; then
    STEP=1
fi


if [ "$GATK_SCATTERED_CALLING" = "1" ]; then
    GATK_SCATTERED_CALLING=1
    INTERVAL_ARRAY=( 1 )
elif [ "$GATK_SCATTERED_CALLING" = "50" ]; then
    INTERVAL_ARRAY=()
    for i in $(seq -f "%04g" 1 $GATK_SCATTERED_CALLING); do
        INTERVAL_ARRAY+=( $i )
    done
else
    if [ "$GATK_SCATTERED_CALLING" = "356" ]; then
        SCATTERED_CALLINGS_INTERVAL_LIST=$WGS_SCATTERED_CALLINGS
    elif [ "$GATK_SCATTERED_CALLING" = "panel" ] && [ $TARGETED -eq 1 ]; then
        PANEL_PARALLEL=1
        SCATTERED_CALLINGS_INTERVAL_LIST=$INTERVAL_LIST
    else
        SCATTERED_CALLINGS_INTERVAL_LIST=$N25CHR_INTERVAL_LIST
    fi
    GATK_SCATTERED_CALLING=$(grep -v "^@" $SCATTERED_CALLINGS_INTERVAL_LIST | grep -v "^$" | wc -l)
    INTERVAL_ARRAY=()
    for i in $(seq -f "%04g" 1 $GATK_SCATTERED_CALLING); do
        INTERVAL_ARRAY+=( $(grep -v "^@" $SCATTERED_CALLINGS_INTERVAL_LIST | \
            grep -v "^$" | sed -n ${i}p | awk '{ printf "%s:%s-%s\n", $1, $2, $3 }') )
    done
fi
INTERVAL_STRING=$( IFS=$'_'; echo "${INTERVAL_ARRAY[*]}" )


TEMP_PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"
PIPELINE_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_pipeline_status.txt
cd $RESULTS_DIR
if [ "$TEMP_PIPELINE_DIR" = "$PIPELINE_DIR" ]; then
    echo -e "\nSTART: $(date)\nWGS WES Pipeline\nErr out dir: $STD_ERR_OUT_DIR\nResults dir: $RESULTS_DIR\nProject: $PROJECT" >> $PIPELINE_STATUS
    if [ "$GENOME_VERSION" = "b37" ]; then
        echo "Option: Genome version hg19 subtype b37" >> $PIPELINE_STATUS
    else
        echo "Default: Genome version hg38" >> $PIPELINE_STATUS
    fi
    if [ $STEP3_REPEAT -eq 1 ]; then
        echo "Option: Step 3 processing samples being repeated once" >> $PIPELINE_STATUS
    fi
    if [ "$PANEL_BED" != "0" ] && [ "$PANEL_INTERVAL_LIST" != "0" ]; then
        echo -e "Option: Custom gene panel\nOption: Panel bed: $PANEL_BED\nOption: Panel interval list: $PANEL_INTERVAL_LIST" >> $PIPELINE_STATUS
        cut -f 1,2,3 $PANEL_BED > $TARGETS_BED
    else
        if [ "$TARGETS_BED" = "$EXOME_TARGETS_BED" ]; then
            echo "Option: Whole Exome mode" >> $PIPELINE_STATUS
        elif [ $TARGETED -eq 1 ]; then
            echo "Option: Targeted mode" >> $PIPELINE_STATUS
        else
            echo "Default: Whole Genome mode" >> $PIPELINE_STATUS
        fi
    fi
    if [ $ONLY_VARIANT_CALL -eq 0 ]; then
        echo "Fastq dir: $FASTQ_DIR" >> $PIPELINE_STATUS >> $PIPELINE_STATUS
        if [ ! -z $R1_SUFFIX ]; then
            echo "Option: R1 and R2 fastq pattern: $R1_SUFFIX $R2_SUFFIX" >> $PIPELINE_STATUS
        fi
        if [ $RNA -eq 1 ]; then
            echo "Option: Analyze RNA data instead of DNA data" >> $PIPELINE_STATUS
        fi
        if [ "$CELL_BARCODES" != "0" ]; then
            echo "Option: Cell barcodes file: $CELL_BARCODES\nOption: Number of barcodes: $NUMBER_OF_BARCODES" >> $PIPELINE_STATUS
        elif [ "$UMI_PATTERN" != "0" ]; then
            echo "Option: UMI pattern: $UMI_PATTERN" >> $PIPELINE_STATUS
        fi
        if [ $SKIP_TRIMMOMATIC -eq 1 ]; then
            echo "Option: Skip trimming - will not run trimmomatic" >> $PIPELINE_STATUS
        fi
        if [ $MAPQ_MIN -ne 0 ]; then
            echo "Option: Removing alignments below a MAPQ value of $MAPQ_MIN" >> $PIPELINE_STATUS
        fi
        if [ $NOVASEQ_WGS -eq 1 ]; then
            echo "Option: Novaseq WGS -  Will add extra memory to certain jobs" >> $PIPELINE_STATUS
        fi
        if [ $DUP_MARK_AGAIN -eq 1 ]; then
            echo "Option: Starting from MarkDuplicates program" >> $PIPELINE_STATUS
        fi
        if [ $DUPLICATE_PIXEL_DISTANCE -eq 0 ]; then
            echo "Option: Skip marking of duplicates - will skip GATK MarkDuplicates" >> $PIPELINE_STATUS
        elif [ $DUPLICATE_PIXEL_DISTANCE -ne 100 ]; then
            echo "Option: Duplicate pixel distance changed to $DUPLICATE_PIXEL_DISTANCE" >> $PIPELINE_STATUS
        else
            echo "Default: Duplicate pixel distance: $DUPLICATE_PIXEL_DISTANCE" >> $PIPELINE_STATUS
        fi
        if [ $REMOVE_DUPS -eq 1 ]; then
            echo "Option: Removing duplicates in the BAM instead of marking them" >> $PIPELINE_STATUS
        fi
        if [ $VARIANT_CLASS -eq 0 ]; then
            OPTIONS+=( "--no_variant_class" )
        fi
        if [ $CIRCLE_MAP -eq 0 ]; then
            echo "Option: Circle map search for possible circular DNA regions" >> $PIPELINE_STATUS
        fi
        if [ $METHYLATION -eq 0 ]; then
            echo "Option: Skip methylation analysis" >> $PIPELINE_STATUS
        fi
    else
        echo "Option: Only call variants from BAMs in $RESULTS_DIR and skip fastq processing" >> $PIPELINE_STATUS
        if [ $BAM_SUFFIX != ".bqsr.marked.bam" ]; then
            echo "Option: Bam suffix: $BAM_SUFFIX" >> $PIPELINE_STATUS
        fi
    fi
    if [ $SKIP_VARIANT_CALL -eq 0 ] || [ $ONLY_VARIANT_CALL -eq 1 ]; then
        if [ $MONOVAR -eq 1 ]; then
            echo "Option: Monovar variant calling" >> $PIPELINE_STATUS
        fi
        if [ $CLEAN_DEEP_SEQ -eq 1 ]; then
            echo "Option: CleanDeepSeq variant calling" >> $PIPELINE_STATUS
        fi
        if [ $GATK -eq 1 ]; then
            echo "Default: GATK variant calling" >> $PIPELINE_STATUS
        fi
        if [ $BP_RESOLUTION -eq 1 ]; then
            echo "Option: Keep reference for GATK - BP resolution for HaplotypeCaller will keep data on all bases" >> $PIPELINE_STATUS
        fi
        if [ "$GATK_SCATTERED_CALLING" = "panel" ] && [ $TARGETED -eq 1 ]; then
            echo "Option: Panel parallelization - each panel genomic region will be a separate job" >> $PIPELINE_STATUS
        fi
        if [ "$GATK_SCATTERED_CALLING" = "25" ]; then
            echo "Default: Using $GATK_SCATTERED_CALLING intervals for variant calling" >> $PIPELINE_STATUS
        else
            echo "Option: Using $GATK_SCATTERED_CALLING intervals for variant calling" >> $PIPELINE_STATUS
        fi
        if [ $GENOMICS_DB_IMPORT -eq 1 ]; then
            echo "Option: Using GenomicsDBImport for 5_compare_variants.sh. Make sure your sample names do not have underscores" >> $PIPELINE_STATUS
        fi
        if [ $TRANCHE != "90.0" ]; then
            echo "Option: Tranche level changed to $TRANCHE" >> $PIPELINE_STATUS
        else
            echo "Default: Tranche level: $TRANCHE" >> $PIPELINE_STATUS
        fi
    fi
    if [ $SKIP_VARIANT_CALL -eq 1 ]; then
        echo "Option: Skip variant calling" >> $PIPELINE_STATUS
    fi
    echo " " >> $PIPELINE_STATUS
fi


if [ ! -z $SLURM_OPTIONS ]; then
    echo "Option: Slurm - entire pipeline run will be queued with user parameters" >> $PIPELINE_STATUS
    sbatch -J $PROJECT ${SLURM_OPTIONS[@]} \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh ${OPTIONS[@]}
    exit 0
fi


if [ $STEP -ne 0 ] && [ $ONLY_VARIANT_CALL -eq 0 ]; then
    if [ -z $R1_SUFFIX ] || [ -z $R2_SUFFIX ]; then
        R1_SUFFIX="_L001_R1_001.fastq.gz"
        R2_SUFFIX="_L001_R2_001.fastq.gz"
        if [ $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" | wc -l) -eq 0 ]; then
            R1_SUFFIX="_R1_001.fastq.gz"
            R2_SUFFIX="_R2_001.fastq.gz"
        fi
    fi
    SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" -exec basename {} \; | \
        grep -v "Undetermined" | sed "s/${R1_SUFFIX}//") )
    if [ ${#SAMPLE_ARRAY[@]} -eq 0 ]; then
        echo "No fastq.gz files found in the fastq directory. Exiting with code 1"
        echo "No fastq.gz files found in the fastq directory. Exiting with code 1" >> $PIPELINE_STATUS
        echo -e "END: $(date)" >> $PIPELINE_STATUS
        exit 1
    elif [ "$CELL_BARCODES" != "0" ]; then
        UNEXTRACTED_SAMPLE=${SAMPLE_ARRAY[0]}
        if [ $STEP -eq 1 ]; then
            echo -e "Starting fastq: $UNEXTRACTED_SAMPLE" >> $PIPELINE_STATUS
        fi
        SAMPLE_ARRAY=()
        for (( c=1; c<=$NUMBER_OF_BARCODES; c++ )); do
            SAMPLE_ARRAY+=( $(sed -n ${c}p $CELL_BARCODES | cut -f 1 | tr -d '[:blank:]') )
        done
    fi
    if [ $STEP -eq 1 ]; then
        echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}" >> $PIPELINE_STATUS
    fi
fi


if [ $STEP -eq 0 ]; then
    echo "### Fastq processing step 0 - Demultiplexing ### - START: $(date)" >> $PIPELINE_STATUS
    echo -e "Run dir: $RUN_DIR\nSample sheet: $SAMPLE_SHEET" >> $PIPELINE_STATUS
    DEPENDENCIES+=( $(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${SCRIPT_DIR}/0_demultiplexer.sh --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET --fastq_dir $FASTQ_DIR \
        --pipeline_status $PIPELINE_STATUS) )
    echo -e "\nsbatch --dependency=afterok:${DEPENDENCIES[0]} -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step1 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    sbatch --dependency=afterok:${DEPENDENCIES[0]} -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step1 ${OPTIONS[@]}
elif [ $STEP -eq 1 ]; then
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        echo "### Fastq processing step 1 - Splitting Fastqs ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        echo -e "Reads per align job: $READS_PER_SPLIT\nSplit jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
    fi
    
    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/1_split_fastqs.sh \
        $FASTQ_DIR $RESULTS_DIR $R1_SUFFIX $R2_SUFFIX $PYTHON_LIBS $PYTHON_LIBS_SITE_PACKAGES \
        $CELL_BARCODES $UMI_PATTERN $READS_PER_SPLIT $TEMP_SAMPLES_STRING\n" >> $PIPELINE_STATUS
    DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/1_split_fastqs.sh \
        $FASTQ_DIR $RESULTS_DIR $R1_SUFFIX $R2_SUFFIX $PYTHON_LIBS $PYTHON_LIBS_SITE_PACKAGES \
        $CELL_BARCODES $UMI_PATTERN $READS_PER_SPLIT $TEMP_SAMPLES_STRING) )
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    
    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step1 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step1 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}
    else
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step2 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step2 ${OPTIONS[@]}
    fi
elif [ $STEP -eq 2 ]; then
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        SAMPLE_COUNT=1
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -d split_aligning_${SAMPLE} ]; then
                echo "Sample number $SAMPLE_COUNT - split_aligning_${SAMPLE} directory not found. Exiting with code 1"
                echo "Sample number $SAMPLE_COUNT - split_aligning_${SAMPLE} directory not found. Exiting with code 1" >> $PIPELINE_STATUS
                echo -e "END: $(date)" >> $PIPELINE_STATUS
                exit 1
            fi
            SAMPLE_COUNT=$((SAMPLE_COUNT+1))
        done
        rm ${STD_ERR_OUT_DIR}/*1_split_fastqs.out ${STD_ERR_OUT_DIR}/*1_split_fastqs.err
        echo "### Fastq processing step 1 - Splitting Fastqs ### - END: $(date)" >> $PIPELINE_STATUS
        
        echo "### Fastq processing step 2 - Aligning Fastqs ### - START: $(date)" >> $PIPELINE_STATUS
        FASTQ_ARRAY=()
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            FASTQ_ARRAY+=( $(ls split_aligning_${SAMPLE}/${SAMPLE}_R1_split_[0-9]*.fastq) )
        done
        JOB_COUNT=${#FASTQ_ARRAY[@]}
        echo -e "Align jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
    fi
    FASTQ_ARRAY=()
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        FASTQ_ARRAY+=( $(ls split_aligning_${SAMPLE}/${SAMPLE}_R1_split_[0-9]*.fastq) )
    done
    
    if [ $RNA -eq 1 ]; then
        EXTRA_RAM="--mem=64G"
    fi
    TEMP_FASTQ_ARRAY=( ${FASTQ_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_FASTQ_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for fastqs $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_FASTQ_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_FASTQ_STRING=$( IFS=$':'; echo "${TEMP_FASTQ_ARRAY[*]}" )
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} $EXTRA_RAM ${SCRIPT_DIR}/2_align_reads.sh \
        $RESULTS_DIR $REF_FASTA $TOOLS_DIR $SKIP_TRIMMOMATIC $TEMP_FASTQ_STRING $RNA\n" >> $PIPELINE_STATUS
    DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} $EXTRA_RAM ${SCRIPT_DIR}/2_align_reads.sh \
        $RESULTS_DIR $REF_FASTA $TOOLS_DIR $SKIP_TRIMMOMATIC $TEMP_FASTQ_STRING $RNA) )
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    echo "New start: $TEMP_ARRAY_START"
    echo "Increment: $TEMP_ARRAY_INCREMENT"
    
    if [ $TEMP_ARRAY_START -le ${#FASTQ_ARRAY[@]} ]; then
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step2 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step2 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}
    else
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step3 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step3 ${OPTIONS[@]}
    fi
elif [ $STEP -eq 3 ]; then
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        FASTQ_ARRAY=()
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            FASTQ_ARRAY+=( $(ls split_aligning_${SAMPLE}/${SAMPLE}_R1_split_[0-9]*.fastq) )
        done
        JOB_COUNT=${#FASTQ_ARRAY[@]}
        ALIGNED_BAMS_FOUND=0
        STEP_FAILED=0
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            ALIGNED_BAMS_FOUND=$(echo $ALIGNED_BAMS_FOUND $(ls split_aligning_${SAMPLE}/${SAMPLE}_split_[0-9]*.bam | wc -l) | awk '{print $1 + $2 }')
        done
        if [ $ALIGNED_BAMS_FOUND -ne $JOB_COUNT ]; then
            echo "$ALIGNED_BAMS_FOUND BAM files found but expected $JOB_COUNT"
            echo "$ALIGNED_BAMS_FOUND BAM files found but expected $JOB_COUNT" >> $PIPELINE_STATUS
            STEP_FAILED=1
        fi
        if [ $STEP_FAILED -eq 1 ]; then
            echo -e "Exiting with code 1\nEND: $(date)" >> $PIPELINE_STATUS
            exit 1
        fi
        # rm ${STD_ERR_OUT_DIR}/*2_align_reads.out ${STD_ERR_OUT_DIR}/*2_align_reads.err
        echo "### Fastq processing step 2 - Aligning Fastqs ### - END: $(date)" >> $PIPELINE_STATUS
        
        echo "### Fastq processing step 3 - Processing samples ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        echo "Process sample jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
    fi
    
    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    if [ $NOVASEQ_WGS -eq 1 ]; then
        echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/3_process_sample.sh --cpus-per-task=6 \
            $RESULTS_DIR $GENOME_VERSION $TARGETED $SCRIPT_DIR $TOOLS_DIR $REFERENCE_DIR $TEMP_SAMPLES_STRING $DUP_MARK_AGAIN \
            $MAPQ_MIN $DUPLICATE_PIXEL_DISTANCE $REMOVE_DUPS $BAM_SUFFIX $TARGETS_BED $INTERVAL_LIST $VARIANT_CLASS $RNA\n" >> $PIPELINE_STATUS
        DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/3_process_sample.sh --cpus-per-task=6 \
            $RESULTS_DIR $GENOME_VERSION $TARGETED $SCRIPT_DIR $TOOLS_DIR $REFERENCE_DIR $TEMP_SAMPLES_STRING $DUP_MARK_AGAIN \
            $MAPQ_MIN $DUPLICATE_PIXEL_DISTANCE $REMOVE_DUPS $BAM_SUFFIX $TARGETS_BED $INTERVAL_LIST $VARIANT_CLASS $RNA) )
    elif [ $DUP_MARK_AGAIN -eq 1 ]; then
        SAMPLE_COUNT=1
        REPEAT_SAMPLES=""
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -f ${SAMPLE}${BAM_SUFFIX} ]; then
                if [ -z "$REPEAT_SAMPLES" ]; then
                    REPEAT_SAMPLES=$SAMPLE_COUNT
                else
                    REPEAT_SAMPLES="${REPEAT_SAMPLES},${SAMPLE_COUNT}"
                fi
            fi
            SAMPLE_COUNT=$((SAMPLE_COUNT+1))
        done
        echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=${REPEAT_SAMPLES} ${SCRIPT_DIR}/3_process_sample.sh --cpus-per-task=6 \
            $RESULTS_DIR $GENOME_VERSION $TARGETED $SCRIPT_DIR $TOOLS_DIR $REFERENCE_DIR $TEMP_SAMPLES_STRING $DUP_MARK_AGAIN \
            $MAPQ_MIN $DUPLICATE_PIXEL_DISTANCE $REMOVE_DUPS $BAM_SUFFIX $TARGETS_BED $INTERVAL_LIST $VARIANT_CLASS\n" >> $PIPELINE_STATUS
        DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=${REPEAT_SAMPLES} ${SCRIPT_DIR}/3_process_sample.sh --cpus-per-task=6 \
            $RESULTS_DIR $GENOME_VERSION $TARGETED $SCRIPT_DIR $TOOLS_DIR $REFERENCE_DIR $TEMP_SAMPLES_STRING $DUP_MARK_AGAIN \
            $MAPQ_MIN $DUPLICATE_PIXEL_DISTANCE $REMOVE_DUPS $BAM_SUFFIX $TARGETS_BED $INTERVAL_LIST $VARIANT_CLASS) )
    else
        echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/3_process_sample.sh \
            $RESULTS_DIR $GENOME_VERSION $TARGETED $SCRIPT_DIR $TOOLS_DIR $REFERENCE_DIR $TEMP_SAMPLES_STRING $DUP_MARK_AGAIN \
            $MAPQ_MIN $DUPLICATE_PIXEL_DISTANCE $REMOVE_DUPS $BAM_SUFFIX $TARGETS_BED $INTERVAL_LIST $VARIANT_CLASS\n" >> $PIPELINE_STATUS
        DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/3_process_sample.sh \
            $RESULTS_DIR $GENOME_VERSION $TARGETED $SCRIPT_DIR $TOOLS_DIR $REFERENCE_DIR $TEMP_SAMPLES_STRING $DUP_MARK_AGAIN \
            $MAPQ_MIN $DUPLICATE_PIXEL_DISTANCE $REMOVE_DUPS $BAM_SUFFIX $TARGETS_BED $INTERVAL_LIST $VARIANT_CLASS) )
    fi
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    
    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step3 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step3 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}
    else
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step4 --previous_check ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step4 --previous_check ${OPTIONS[@]}
    fi
elif [ $STEP -eq 4 ] && [ $PREVIOUS_CHECK -eq 1 ]; then
    SAMPLE_COUNT=1
    STEP_FAILED=0
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        if [ ! -f ${SAMPLE}${BAM_SUFFIX} ]; then
            echo "Sample number $SAMPLE_COUNT - ${SAMPLE}${BAM_SUFFIX} file not found"
            echo "Sample number $SAMPLE_COUNT - ${SAMPLE}${BAM_SUFFIX} file not found" >> $PIPELINE_STATUS
            STEP_FAILED=1
        fi
        SAMPLE_COUNT=$((SAMPLE_COUNT+1))
    done
    if [ $STEP_FAILED -eq 1 ] && [ $STEP3_REPEAT -eq 0 ]; then
        echo "Common causes:" >> $PIPELINE_STATUS
        echo "1 - Demultiplexing error leading to unpaired reads in the FASTQ(s). Demultiplexing will need to be done again" >> $PIPELINE_STATUS
        echo "2 - Very large BAM(s) caused GATK's MarkDuplicates to run out of memory. --MAX_RECORDS_IN_RAM will need to be reduced" >> $PIPELINE_STATUS
        if [ $STEP3_REPEAT -eq 0 ]; then
            echo "Will re-run step 3 once with 6 instead of 4 CPUs." >> $PIPELINE_STATUS
            echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step3_repeat --step3 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
            sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step3_repeat --step3 ${OPTIONS[@]}
        fi
        echo "Exiting with code 1." >> $PIPELINE_STATUS
        echo -e "END: $(date)" >> $PIPELINE_STATUS
        exit 1
    fi
    PREVIOUS_CHECK=0
    echo "### Fastq processing step 3 - Processing samples ### - END: $(date)" >> $PIPELINE_STATUS
    mkdir -p ${PROJECT}_Multiple_Metric_Files
    echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/summarize_metrics.sh $RESULTS_DIR $SCRIPT_DIR $PROJECT $TARGETED \
        $CELL_BARCODES $UMI_PATTERN $RUN_DIR $SAMPLE_SHEET\n" >> $PIPELINE_STATUS
    sbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/summarize_metrics.sh $RESULTS_DIR $SCRIPT_DIR $PROJECT $TARGETED \
        $CELL_BARCODES $UMI_PATTERN $RUN_DIR $SAMPLE_SHEET
    echo "Submitted asynchronous summarize metrics job" >> $PIPELINE_STATUS
    
    BAM_5M_SUFFIX=$(echo $BAM_SUFFIX | sed "s/.bam/.5M.bam/")
    GINKGO_OPTIONS=()
    if [ "$GENOME_VERSION" = "b37" ]; then
        GINKGO_OPTIONS+=( "--b37" )
    fi
    mkdir -p ${PROJECT}_Ginkgo_CNV_Analysis
    echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
        --bam_regex .*${BAM_SUFFIX}$ --bam_regex ${BAM_SUFFIX} \
        --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis ${GINKGO_OPTIONS[@]}\n" >> $PIPELINE_STATUS
    sbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
        --bam_regex .*${BAM_SUFFIX}$ --bam_regex ${BAM_SUFFIX} \
        --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis ${GINKGO_OPTIONS[@]}
    if [ $(ls *${BAM_5M_SUFFIX} | wc -l) -gt 0 ]; then
        mkdir -p ${PROJECT}_5M_Read_BAM_Files
        echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
            ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
            --bam_regex .*${BAM_5M_SUFFIX}$ --bam_regex ${BAM_5M_SUFFIX} \
            --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis \
            --new_5M_folder $RESULTS_DIR/${PROJECT}_5M_Read_BAM_Files ${GINKGO_OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
            ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
            --bam_regex .*${BAM_5M_SUFFIX}$ --bam_regex ${BAM_5M_SUFFIX} \
            --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis \
            --new_5M_folder $RESULTS_DIR/${PROJECT}_5M_Read_BAM_Files ${GINKGO_OPTIONS[@]}
    fi
    echo "Submitted asynchronous Ginkgo CNV analysis job" >> $PIPELINE_STATUS
    
    if [ $SCAN2 -eq 1 ] && [ "$GENOME_VERSION" = "b37" ]; then
        if [ -z $SCAN2_BULK ]; then
            if [ $GENOME_VERSION = "b37" ]; then
                SCAN2_BULK="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_WGA_WGS_BAMS/T1200-1.bam"
            else
                SCAN2_BULK="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_WGA_WGS_BAMS/T1200-1.bam"
            fi
        fi
        SCAN2_ARRAY=()
        SCAN2_BULK_SAMPLE=$(basename $SCAN2_BULK | sed "s/${BAM_SUFFIX}//" | sed 's/.bqsr.marked.bam//' | sed 's/.bam//')
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ "$SAMPLE" != "$SCAN2_BULK_SAMPLE" ]; then
                SCAN2_ARRAY+=( "$SAMPLE" )
            fi
        done
        JOB_COUNT=${#SCAN2_ARRAY[@]}
        mkdir -p ${PROJECT}_Scan2_Results
        echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${JOB_COUNT} ${SCRIPT_DIR}/Scan2.sh \
            --script_dir $SCRIPT_DIR --bam_dir $RESULTS_DIR \
            --bam_regex $BAM_SUFFIX  --bam_suffix $BAM_SUFFIX \
            --project $PROJECT --bulk $SCAN2_BULK --genome_version $GENOME_VERSION  \
            --std_err_out $STD_ERR_OUT_DIR --results_dir $RESULTS_DIR\n" >> $PIPELINE_STATUS
        sbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${JOB_COUNT} ${SCRIPT_DIR}/Scan2.sh \
            --script_dir $SCRIPT_DIR --bam_dir $RESULTS_DIR \
            --bam_regex $BAM_SUFFIX --bam_suffix $BAM_SUFFIX \
            --project $PROJECT --bulk $SCAN2_BULK --genome_version $GENOME_VERSION  \
            --std_err_out $STD_ERR_OUT_DIR --results_dir $RESULTS_DIR
        echo "Submitted asynchronous Scan2 analysis job" >> $PIPELINE_STATUS
    fi
    
    if [ $METHYLATION -eq 1 ]; then
        METHYLATION_OPTIONS=()
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        mkdir -p ${PROJECT}_mosdepth_Results
        if [ "$GENOME_VERSION" = "b37" ]; then
            METHYLATION_OPTIONS=( "--b37" )
        fi
        echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${JOB_COUNT} ${SCRIPT_DIR}/mosdepth.sh \
            --bam_dir $RESULTS_DIR --bam_suffix $BAM_SUFFIX \
            --results_dir ${RESULTS_DIR}/${PROJECT}_mosdepth_Results ${METHYLATION_OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${JOB_COUNT} ${SCRIPT_DIR}/mosdepth.sh \
            --bam_dir $RESULTS_DIR --bam_suffix $BAM_SUFFIX \
            --results_dir ${RESULTS_DIR}/${PROJECT}_mosdepth_Results ${METHYLATION_OPTIONS[@]}
        echo "Submitted asynchronous Scan2 analysis job" >> $PIPELINE_STATUS
    fi
fi


if [ $STEP -eq 4 ] || [ $STEP -eq 5 ]; then
    if [ $SKIP_VARIANT_CALL -eq 1 ]; then
        echo "Ending without variant calling" >> $PIPELINE_STATUS
        echo -e "END: $(date)" >> $PIPELINE_STATUS
        exit 0
    fi
    SAMPLE_ARRAY=( $(ls *${BAM_SUFFIX} | sed "s/${BAM_SUFFIX}//") )
    if [ ${#SAMPLE_ARRAY[@]} -eq 0 ]; then
        echo "No BAM files found in the results directory. Exiting with code 1"
        echo "No BAM files found in the results directory. Exiting with code 1" >> $PIPELINE_STATUS
        echo -e "END: $(date)" >> $PIPELINE_STATUS
        exit 1
    fi
fi


if [ $STEP -eq 4 ]; then
    if [ $MONOVAR -eq 1 ] && [ $TEMP_ARRAY_START -eq 0 ]; then
        echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
            ${SCRIPT_DIR}/monovar.sh \
            --bam_dir $RESULTS_DIR --ref_fasta $REF_FASTA --tools_dir $TOOLS_DIR \
            --project $PROJECT --annovar_dir $ANNOVAR_DIR --bam_suffix $BAM_SUFFIX\n" >> $PIPELINE_STATUS
        sbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
            ${SCRIPT_DIR}/monovar.sh \
            --bam_dir $RESULTS_DIR --ref_fasta $REF_FASTA --tools_dir $TOOLS_DIR \
            --project $PROJECT --annovar_dir $ANNOVAR_DIR --bam_suffix $BAM_SUFFIX
        echo "Submitted asynchronous Monovar variant calling job" >> $PIPELINE_STATUS
    fi
    
    
    if [ $CLEAN_DEEP_SEQ -eq 1 ] && [ $CDS_STEP -eq 1 ] && [ $TEMP_ARRAY_START -eq 0 ]; then
        if [ $TEMP_ARRAY_START -eq 0 ]; then
            echo "### CleanDeepSeq step 1 - Calling CleanDeepSeq variants ### - START: $(date)" >> $PIPELINE_STATUS
            JOB_COUNT=${#SAMPLE_ARRAY[@]}
            echo "Call variant jobs to run: $JOB_COUNT" >> $PIPELINE_STATUS
            TEMP_ARRAY_START=1
        fi
        TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
        TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
        echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
        TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
        echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/CDS_1_call_variants.sh \
            $RESULTS_DIR $TARGETS_BED $INTERVAL_LIST $REF_GENOME \
            $CLEAN_DEEP_SEQ_TOOL_DIR $PROJECT $BAM_SUFFIX $TEMP_SAMPLES_STRING\n" >> $PIPELINE_STATUS
        DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/CDS_1_call_variants.sh \
            $RESULTS_DIR $TARGETS_BED $INTERVAL_LIST $REF_GENOME \
            $CLEAN_DEEP_SEQ_TOOL_DIR $PROJECT $BAM_SUFFIX $TEMP_SAMPLES_STRING) )
        TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
        
        if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
            echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step4 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
            sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step4 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}
        else
            echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step4 --cds_step2 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
            sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step4 --cds_step2 ${OPTIONS[@]}
        fi
        exit 0
    elif [ $CLEAN_DEEP_SEQ -eq 1 ] && [ $CDS_STEP -eq 2 ]; then
        echo "### CleanDeepSeq step 1 - Calling CleanDeepSeq variants ### - END: $(date)" >> $PIPELINE_STATUS
        STEP_FAILED=0
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ ! -f counts.${SAMPLE}${BAM_SUFFIX}.txt ]; then
                echo "counts.${SAMPLE}${BAM_SUFFIX}.txt not found"
                echo "counts.${SAMPLE}${BAM_SUFFIX}.txt not found" >> $PIPELINE_STATUS
                STEP_FAILED=1
            fi
        done
        if [ $STEP_FAILED -eq 1 ]; then
            echo -e "Exiting with code 1\nEND: $(date)" >> $PIPELINE_STATUS
            exit 1
        fi
        echo "### CleanDeepSeq step 2 - Processing CleanDeepSeq variants ### - START: $(date)" >> $PIPELINE_STATUS
        echo -e "\nsbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/CDS_2_process_variants.sh \
            $RESULTS_DIR $TARGETS_BED $PROJECT $SCRIPT_DIR $REF_FASTA $ANNOVAR_DIR $PIPELINE_STATUS\n" >> $PIPELINE_STATUS
        DEPENDENCIES+=( $(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
            ${SCRIPT_DIR}/CDS_2_process_variants.sh \
            $RESULTS_DIR $TARGETS_BED $PROJECT $SCRIPT_DIR $REF_FASTA $ANNOVAR_DIR $PIPELINE_STATUS) )
        echo -e "\nsbatch --dependency=afterok:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step4 ${OPTIONS[@]//--clean_deep_seq/}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterok:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/submit_all.sh --step4 ${OPTIONS[@]//--clean_deep_seq/}
        exit 0
    fi
    
    
    if [ $GATK -eq 0 ]; then
        echo -e "END: $(date)" >> $PIPELINE_STATUS
        exit 0
    fi
    
    
    if [ $TEMP_ARRAY_START -eq 0 ]; then
        echo "### GATK step 1 - Calling variants ### - START: $(date)" >> $PIPELINE_STATUS
        JOB_COUNT=$(echo ${#SAMPLE_ARRAY[@]} ${#INTERVAL_ARRAY[@]} | awk '{ print $1 * $2 }')
        echo -e "Call variant jobs to run: $JOB_COUNT\nNumber of samples: ${#SAMPLE_ARRAY[@]}\nNumber of intervals: ${#INTERVAL_ARRAY[@]}" >> $PIPELINE_STATUS
        echo -e "Intervals: ${INTERVAL_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}" >> $PIPELINE_STATUS
        TEMP_ARRAY_START=1
    fi
    
    TEMP_ARRAY_INCREMENT=$((1000/${#INTERVAL_ARRAY[@]}))
    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
    TEMP_JOB_COUNT=$(echo ${#TEMP_SAMPLE_ARRAY[@]} ${#INTERVAL_ARRAY[@]} | awk '{ print $1 * $2 }')
    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/GATK_1_call_variants.sh \
        $RESULTS_DIR $GENOME_VERSION $TEMP_SAMPLES_STRING $INTERVAL_STRING $REFERENCE_DIR \
        $GATK_SCATTERED_CALLING $BAM_SUFFIX $BP_RESOLUTION $TARGETED $PANEL_PARALLEL $INTERVAL_LIST\n" >> $PIPELINE_STATUS
    DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${TEMP_JOB_COUNT} ${SCRIPT_DIR}/GATK_1_call_variants.sh \
        $RESULTS_DIR $GENOME_VERSION $TEMP_SAMPLES_STRING $INTERVAL_STRING $REFERENCE_DIR \
        $GATK_SCATTERED_CALLING $BAM_SUFFIX $BP_RESOLUTION $TARGETED $PANEL_PARALLEL $INTERVAL_LIST) )
    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
    
    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step4 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step4 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}
    else
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step5 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
            ${PIPELINE_DIR}/submit_all.sh --step5 ${OPTIONS[@]}
    fi
elif [ $STEP -eq 5 ]; then
    SAMPLE_COUNT=1
    STEP_FAILED=0
    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
        INTERVAL_COUNT=1
        for INTERVAL in ${INTERVAL_ARRAY[@]}; do
            if [ ! -f ${SAMPLE}.${INTERVAL}.g.vcf.gz ]; then
                echo "Sample number $SAMPLE_COUNT - Interval number $INTERVAL_COUNT - ${SAMPLE}.${INTERVAL}.g.vcf.gz file not found"
                echo "Sample number $SAMPLE_COUNT - Interval number $INTERVAL_COUNT - ${SAMPLE}.${INTERVAL}.g.vcf.gz file not found" >> $PIPELINE_STATUS
                STEP_FAILED=1
            fi
            INTERVAL_COUNT=$((INTERVAL_COUNT+1))
        done
        if [ $GATK_SCATTERED_CALLING -ne 1 ] && [ $PANEL_PARALLEL -eq 0 ] && [ $TARGETED -eq 1 ]; then
            for INTERVAL in ${INTERVAL_ARRAY[@]}; do
                rm ${SAMPLE}.${INTERVAL}.bam ${SAMPLE}.${INTERVAL}.bam.bai
            done
        fi
        SAMPLE_COUNT=$((SAMPLE_COUNT+1))
    done
    if [ $STEP_FAILED -eq 1 ]; then
        echo -e "Exiting with code 1\nEND: $(date)" >> $PIPELINE_STATUS
        exit 1
    fi
    echo "### GATK step 1 - Calling variants ### - END: $(date)" >> $PIPELINE_STATUS

    echo "### GATK step 2 - Combining sample gVCFs by genomic interval and genotyping ### - START: $(date)" >> $PIPELINE_STATUS
    SAMPLE_ARRAY=( $(ls *.${INTERVAL_ARRAY[0]}.g.vcf.gz | sed "s/.${INTERVAL_ARRAY[0]}.g.vcf.gz//") )
    JOB_COUNT=${#INTERVAL_ARRAY[@]}
    echo -e "Genotyper jobs to run: $JOB_COUNT\nIntervals: ${INTERVAL_ARRAY[@]}\nAll samples to process: ${SAMPLE_ARRAY[@]}" >> $PIPELINE_STATUS
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-$JOB_COUNT ${SCRIPT_DIR}/GATK_2_compare_variants.sh \
        $PROJECT $REFERENCE_DIR $RESULTS_DIR $GENOME_VERSION $GENOMICS_DB_IMPORT $INTERVAL_LIST $INTERVAL_STRING\n" >> $PIPELINE_STATUS
    DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-$JOB_COUNT ${SCRIPT_DIR}/GATK_2_compare_variants.sh \
        $PROJECT $REFERENCE_DIR $RESULTS_DIR $GENOME_VERSION $GENOMICS_DB_IMPORT $INTERVAL_LIST $INTERVAL_STRING) )
    echo -e "\nsbatch --dependency=afterany:${DEPENDENCIES[0]} -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step6 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    sbatch --dependency=afterany:${DEPENDENCIES[0]} -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        ${PIPELINE_DIR}/submit_all.sh --step6 ${OPTIONS[@]}
elif [ $STEP -eq 6 ]; then
    INTERVAL_COUNT=1
    STEP_FAILED=0
    for INTERVAL in ${INTERVAL_ARRAY[@]}; do
        if [ ! -f ${PROJECT}.${INTERVAL}.merged.vcf.gz ]; then
            echo "Interval number $INTERVAL_COUNT - ${PROJECT}.${INTERVAL}.merged.vcf.gz file not found"
            echo "Interval number $INTERVAL_COUNT - ${PROJECT}.${INTERVAL}.merged.vcf.gz file not found" >> $PIPELINE_STATUS
            STEP_FAILED=1
        fi
        INTERVAL_COUNT=$((INTERVAL_COUNT+1))
    done
    if [ $STEP_FAILED -eq 1 ]; then
        echo -e "Exiting with code 1\nEND: $(date)" >> $PIPELINE_STATUS
        exit 1
    fi
    for INTERVAL in ${INTERVAL_ARRAY[@]}; do
        rm *.${INTERVAL}.g.vcf.gz*
    done
    if [ $GENOMICS_DB_IMPORT -eq 1 ]; then
        for INTERVAL in ${INTERVAL_ARRAY[@]}; do
            rm -r ${PROJECT}.${INTERVAL}.merged_database
        done
    else
        for INTERVAL in ${INTERVAL_ARRAY[@]}; do
            rm ${PROJECT}.${INTERVAL}.merged.g.vcf.gz ${PROJECT}.${INTERVAL}.merged.g.vcf.gz.tbi
        done
    fi
    rm ${STD_ERR_OUT_DIR}/*GATK_1_call_variants.out ${STD_ERR_OUT_DIR}/*GATK_1_call_variants.err
    rm ${STD_ERR_OUT_DIR}/*GATK_2_compare_variants.out ${STD_ERR_OUT_DIR}/*GATK_2_compare_variants.err
    echo "### GATK step 2 - Combining sample gVCFs by genomic interval and genotyping ### - END: $(date)" >> $PIPELINE_STATUS


    echo "### GATK step 3 - Processing variants ### - START: $(date)" >> $PIPELINE_STATUS
    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/GATK_3_process_variants.sh \
        $RESULTS_DIR $GENOME_VERSION $PROJECT $TARGETED $TOOLS_DIR $INTERVAL_STRING $REFERENCE_DIR \
        $ANNOVAR_DIR $PANEL_BED $TRANCHE $PIPELINE_STATUS $PYTHON_LIBS $PYTHON_LIBS_SITE_PACKAGES $SCRIPT_DIR\n" >> $PIPELINE_STATUS
    DEPENDENCIES+=( $(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${SCRIPT_DIR}/GATK_3_process_variants.sh \
        $RESULTS_DIR $GENOME_VERSION $PROJECT $TARGETED $TOOLS_DIR $INTERVAL_STRING $REFERENCE_DIR \
        $ANNOVAR_DIR $PANEL_BED $TRANCHE $PIPELINE_STATUS $PYTHON_LIBS $PYTHON_LIBS_SITE_PACKAGES $SCRIPT_DIR) )
        
    if [ $CIRCLE_MAP -eq 1 ]; then
        if [ "$GENOME_VERSION" = "b37" ]; then
            ANNOVAR_GENOME_VERSION="hg19"
        else
            ANNOVAR_GENOME_VERSION="hg38"
        fi
        if [ "$PANEL_BED" = "0" ]; then
            FINAL_SNPS="${PROJECT}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv"
            FINAL_INDELS="${PROJECT}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv"
        else
            FINAL_SNPS="${PROJECT}.merged.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv"
            FINAL_INDELS="${PROJECT}.merged.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv"
        fi
        SAMPLES_STRING=$( IFS=$':'; echo "${SAMPLE_ARRAY[*]}" )
        echo -e "\nsbatch --dependency=afterany:${DEPENDENCIES[0]} \
            -e ${STD_ERR_OUT_DIR}/%A_%a_%x.err -o ${STD_ERR_OUT_DIR}/%A_%a_%x.out \
            --array=1-${JOB_COUNT} \
            ${SCRIPT_DIR}/circle_map_runner.sh \
            $RESULTS_DIR $REF_FASTA $BAM_SUFFIX $SAMPLES_STRING $FINAL_SNPS $FINAL_INDELS\n" >> $PIPELINE_STATUS
        sbatch --dependency=afterany:${DEPENDENCIES[0]} \
            -e ${STD_ERR_OUT_DIR}/%A_%a_%x.err -o ${STD_ERR_OUT_DIR}/%A_%a_%x.out \
            --array=1-${JOB_COUNT} \
            ${SCRIPT_DIR}/circle_map_runner.sh \
            $RESULTS_DIR $REF_FASTA $BAM_SUFFIX $SAMPLES_STRING $FINAL_SNPS $FINAL_INDELS
        echo "Submitted asynchronous Circle Map analysis job" >> $PIPELINE_STATUS
    fi
    echo -e "END: $(date)" >> $PIPELINE_STATUS
fi