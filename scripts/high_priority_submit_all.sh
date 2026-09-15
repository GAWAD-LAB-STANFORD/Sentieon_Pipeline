#!/bin/bash
#
#SBATCH --job-name=sentieon_submit_all
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=30G
#SBATCH --nice=[-2147483645]

#PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"

PIPELINE_DIR="/oak/stanford/groups/cgawad/Scripts/Sentieon_Pipeline"
HELP="\
Purpose: \n\t\
    This pipeline is built to run Sentieon \n\n\
Required arguments: \n\
Optional arguments: \n\
Defaults: \n\t\
     \n\n\
Run after demultiplexing: \n\t\
    sh ${PIPELINE_DIR}/high_priority_submit_all.sh --fastq_dir /oak/stanford/groups/cgawad/MRD_project/ --project MRD_project \n\n\
Run with demultiplexing: \n\t\
    sh ${PIPELINE_DIR}/high_priority_submit_all.sh --run_dir /oak/stanford/groups/cgawad/Illumina_Data/MiniSeq/191126_MN01236_0003_A000H2WWHT --fastq_dir /oak/stanford/groups/cgawad/MRD_project/ --project MRD_project \n\n\
For more information, read the README.md"

# Reads in command line option arguments and assigns them to variables
RNA=0
SKIP_TRIMMOMATIC=0
NUMBER_THREADS=4
VARIANT_CLASS=1
BAM_SUFFIX=".bqsr.marked.bam"
SCAN2_BULK=0
SCAN2=1
METHYLATION=1
CIRCLE_MAP=1
STEP=0
TEMP_ARRAY_START=0
SKIP_VARIANT_CALL=0
ONLY_VARIANT_CALL=0
GATK=1
DEPENDENCIES=()
BAM_DIR=0
UMI_PATTERN=0
CELL_BARCODES=0
TARGETED=0
SKIP_BAM=0
SKIP_QC=0
ONLY_STEP=0
TEST_SCAN2=0
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
                                FINAL_DIR=$1
                                ;;
        -p | --project )        shift
                                PROJECT=$1
                                ;;
        -d | --pipeline_dir )   shift
                                PIPELINE_DIR=$1
                                ;;
        --rna )                 RNA=1
                                ;;
        --skip_trimming )       SKIP_TRIMMOMATIC=1
                                ;;
        --number_threads )      shift
                                NUMBER_THREADS=$1
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
        --skip_methylation )    METHYLATION=0
                                ;;
        --gatk )                GATK=1
                                ;;
        --skip_circle_map )     CIRCLE_MAP=0
                                ;;
        --step0 )		STEP=0
				;;
	--step1 )               STEP=1
                                ;;
        --step2 )               STEP=2
                                ;;
        --step3 )               STEP=3
                                ;;
        --step4 )		STEP=4
				;;
	--step5 )		STEP=5
				;;
	--step6 )		STEP=6
				;;
	--step7 )		STEP=7
				;;
	--stepQC )		STEP=15
				;;
	--temp_array_start )    shift
                                TEMP_ARRAY_START=$1
                                ;;
        --slurm )               shift
                                SLURM_OPTIONS=${@:1}
                                ;;
	--skip_variant_call )	SKIP_VARIANT_CALL=0
				;;
	--only_variant_call )	ONLY_VARIANT_CALL=0
				;;
	--normal_sample_name )  shift
				NORMAL_SAMPLE_NAME=$1
				;;
	--only_bam )            ONLY_BAM=1
				;;
	--bam_dir )		shift
				BAM_DIR=$1
				;;
	--sample_prefix )	shift
				SAMPLE_PREFIX=$1
				;;
	--skip_bam ) 		shift
				SKIP_BAM=$1
				;;
        --skip_qc )             shift
				SKIP_QC=$1
				;;
	--umi_pattern )		shift
				UMI_PATTERN=$1
				;;
	--cell_barcodes )	shift
				CELL_BARCODES=$1
				;;
	--exome ) 		TARGETED=1
				;;
	--targeted ) 		TARGETED=1
			 	;;
	--cross_dir )           shift
                                CROSS_SAMPLE_DIR=$1
                                ;;
	--step1 )		STEP=1
			        ;;
	--step2 ) 	 	STEP=2
				;;
	--step3 ) 		STEP=3
				;;
	--step4 )		STEP=4
				;;
	--final_dir ) 		shift
				FINAL_DIR=$1
				;;
	--only_step ) 		ONLY_STEP=1
				;;
	--test_scan2 ) 		TEST_SCAN2=1
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
TRANCHE="99.9"


# hg38 reference files
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files"
BISMARK_GENOME="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Bismark"
REF_FASTA="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta"
REF_GENOME="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_bedtools.genome"
N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.bed"
DBSNP_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
WGS_SCATTERED_CALLINGS="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/wgs_calling_regions.hg38.interval_list"
INTERVAL_STRING="chr1_chr2_chr3_chr4_chr5_chr6_chr7_chr8_chr9_chr10_chr11_chr12_chr13_chr14_chr15_chr16_chr17_chr18_chr19_chr20_chr21_chr22_chrX_chrY_chrM"
SCATTERED_CALLING_DIR="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/scattered_calling_intervals"
EXOME_TARGETS_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_3col.bed"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_5col.interval_list"
INTERVAL_ARRAY=( $(echo $INTERVAL_STRING | sed 's/_/ /g') )
ANNOVAR_GENOME_VERSION="hg38"

# Ensure we have the requires variables set and set other variables
if ([ -z $FASTQ_DIR ] && [ -z $RESULTS_DIR ]) || [ -z $PROJECT ] || [ -z $PIPELINE_DIR ]; then
    echo "Variables not supplied correctly. Use -h/--help options for assistance. Exiting with code 1"
    exit 1
fi



#if [ -z $FASTQ_DIR ]; then
#    FASTQ_DIR="$RESULTS_DIR"
#elif [ -z $RESULTS_DIR ]; then
#    RESULTS_DIR="${FASTQ_DIR}/$(date '+%Y-%m-%d')_${PROJECT}_Results"
#fi

# Make results and std error output directories if they don't exist
#Have to put OPTIONS+= any arguments you want to continually be used through cycles of high_priority_submit_all.sh

#if [ ! -d $FASTQ_DIR ]; then
#    FASTQ_DIR=$SCRATCH/$PROJECT/fastqs
#    mkdir $FASTQ_DIR
#fi


#Remember options from previous loops through high_priority_submit_all.sh

OUTPUT_DIR=$RESULTS_DIR
RESULTS_DIR=$SCRATCH/$PROJECT
mkdir -p $RESULTS_DIR
cd $RESULTS_DIR/

if [ -z $STD_ERR_OUT_DIR ]; then
    STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
fi
echo final directory is $FINAL_DIR
echo working directory is $RESULTS_DIR
if [ ! -d $STD_ERR_OUT_DIR ]; then
    mkdir $STD_ERR_OUT_DIR
fi
OPTIONS=( "--err_out_dir $STD_ERR_OUT_DIR -f $FASTQ_DIR -r $RESULTS_DIR -d $PIPELINE_DIR -p $PROJECT" )
if [ ! -z $FINAL_DIR ]; then
    OPTIONS+=( "--final_dir ${FINAL_DIR}" ) 
    mkdir -p $FINAL_DIR
fi
if [ ! -z $RUN_DIR ] && [ $ONLY_VARIANT_CALL -eq 1 ]; then
    echo "Variables not supplied correctly. Cannot perform demultiplexing while only calling variants. Exiting with code 1"
    exit 1
fi
if [ ! -z $RUN_DIR ] && [ -z $SAMPLE_SHEET ]; then
    SAMPLE_SHEET="${RUN_DIR}/SampleSheet.csv"
elif [ -z $RUN_DIR ] && [ ! -z $SAMPLE_SHEET ]; then ### idk what's going on here this seems broken
    echo "Variables not supplied correctly. Please specify a run diretory for demultiplexing with --run_dir. Exiting with code 1"
    exit 1
fi
# If you add new options please make sure to add them to OPTIONS as --number_threads is below 
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
if [ $RNA -eq 1 ]; then
    OPTIONS+=( "--rna" )
    if [ "$BAM_SUFFIX" == ".bqsr.marked.bam" ]; then
        BAM_SUFFIX=".rna.bam"
    fi
    SKIP_TRIMMOMATIC=1
fi
if [ $SKIP_TRIMMOMATIC -eq 1 ]; then
    OPTIONS+=( "--skip_trimming" )
fi
if [ $NUMBER_THREADS -ne 4 ]; then
    OPTIONS+=( "--number_threads $NUMBER_THREADS" )
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
if [ $METHYLATION -eq 0 ]; then
    OPTIONS+=( "--skip_methylation" )
fi


if [ ! -z $SAMPLE_PREFIX ]; then 
    OPTIONS+=( "--sample_prefix ${SAMPLE_PREFIX}" )
fi

if [ -n $NORMAL_SAMPLE_NAME ]; then
    OPTIONS+=( "--normal_sample_name ${NORMAL_SAMPLE_NAME}" ) 
fi


if [ -n $ONLY_BAM ]; then
    OPTIONS+=( "--only_bam ${ONLY_BAM}" )
fi

if [ -n $SKIP_QC ]; then
    OPTIONS+=( "--skip_qc ${SKIP_QC}" )
fi

if [ -n $UMI_PATTERN ]; then
    OPTIONS+=( "--umi_pattern ${UMI_PATTERN}" )
fi
if [ -n $CELL_BARCODES ]; then
    OPTIONS+=( "--cell_barcodes ${CELL_BARCODES}" )
fi
if [ ! -z $CROSS_SAMPLE_DIR ]; then
    OPTIONS+=( "--cross_dir ${CROSS_SAMPLE_DIR}" )
fi
if [ $TEST_SCAN2 -eq 1 ]; then
    OPTIONS+=( "--test_scan2" )
fi

if [ $STEP -eq 0 ] && [ -z $RUN_DIR ]; then
    STEP=1
fi

#change targets_bed and interval_list for exome sequencing if --exome flag is used
if [ $TARGETED -eq 1 ]; then
        OPTIONS+=( "--exome" )
        TARGETS_BED=$EXOME_TARGETS_BED
        INTERVAL_LIST=$EXOME_INTERVAL_LIST
    else
        TARGETS_BED=$N25CHR_BED
        INTERVAL_LIST=$N25CHR_INTERVAL_LIST
    fi



echo "options are ${OPTIONS[@]}"

# Ensure we have normal sample name (stuff breaks if not)
if [ -z $NORMAL_SAMPLE_NAME ]; then
	echo "normal sample name not found, necessary for variant calling. Exiting with code 1"
	exit 1
fi

#Output description of options used to pipeline status
TEMP_PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"
PIPELINE_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_pipeline_status.txt
cd $RESULTS_DIR
if [ "$TEMP_PIPELINE_DIR" = "$PIPELINE_DIR" ]; then
    echo -e "\nSTART: $(date)\nSentieon Pipeline\nErr out dir: $STD_ERR_OUT_DIR\nResults dir: $RESULTS_DIR\nProject: $PROJECT" >> $PIPELINE_STATUS
    echo "Fastq dir: $FASTQ_DIR" >> $PIPELINE_STATUS >> $PIPELINE_STATUS
    if [ ! -z $R1_SUFFIX ]; then
        echo "Option: R1 and R2 fastq pattern: $R1_SUFFIX $R2_SUFFIX" >> $PIPELINE_STATUS
    fi
    if [ $RNA -eq 1 ]; then
        echo "Option: Analyze RNA data instead of DNA data" >> $PIPELINE_STATUS
    fi
    if [ $SKIP_TRIMMOMATIC -eq 1 ]; then
        echo "Option: Skip trimming - will not run trimmomatic" >> $PIPELINE_STATUS
    fi
    if [ $NUMBER_THREADS -ne 4 ]; then
        echo "Option: Number of threads: $NUMBER_THREADS" >> $PIPELINE_STATUS
    fi
    if [ $CIRCLE_MAP -eq 0 ]; then
        echo "Option: Circle map search for possible circular DNA regions" >> $PIPELINE_STATUS
    fi
    if [ $METHYLATION -eq 0 ]; then
        echo "Option: Skip methylation analysis" >> $PIPELINE_STATUS
    fi
    if [ $GATK -eq 1 ]; then
        echo "Default: GATK variant calling" >> $PIPELINE_STATUS
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
        ${PIPELINE_DIR}/high_priority_submit_all.sh ${OPTIONS[@]}
    exit 0
fi


#TODO: Instead of providing a sample_prefix, have the script get sample_prefixes somehow (find every instance where first n letters are shared by > 2 fastq files or by > 1 fastq file with same R#_SUFFIX, then make a dictionary with a key that is that prefix and a sample string that is all sample names shared under that prefix, then for each sample prefix in that dictionary run the pippeline on that set of samples.


#Don't use --mem, use --mem-per-cpu and --cpu-per-task to allocate resources unless you don't want to allocate resources based on what task needs.
#In my experience, --mem reserves entire node if used with --cpu-per-task

if [ $STEP -le 1 ]; then
		#Assign suffix and use to get sample names
		if [ $STEP -ne 0 ] && [ $ONLY_VARIANT_CALL -eq 0 ]; then
		    if [ -z $R1_SUFFIX ] || [ -z $R2_SUFFIX ]; then
			R1_SUFFIX="_L001_R1_001.fastq.gz"
			R2_SUFFIX="_L001_R2_001.fastq.gz"
			if [ $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" | wc -l) -eq 0 ]; then
			    R1_SUFFIX="_R1_001.fastq.gz"
			    R2_SUFFIX="_R2_001.fastq.gz"
			fi
		    fi
		    SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" -exec basename {} \;) ) 


		   SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" -not -name "Undetermined*" -exec basename {} \; | \
			grep -v "Undetermined" | sed "s/${R1_SUFFIX}//") )
#		    if [ ${#SAMPLE_ARRAY[@]} -eq 0 ] && [ $STEP -le 1 ]; then
#			echo "No fastq.gz files found in the fastq directory. Exiting with code 1"
#			echo "No fastq.gz files found in the fastq directory. Exiting with code 1" >> $PIPELINE_STATUS
#			echo -e "END: $(date)" >> $PIPELINE_STATUS
#			exit 1
#		    fi
		    if [ $STEP -eq 1 ]; then
			echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}" >> $PIPELINE_STATUS
		    fi
		fi

	

	#If step set to 0, demultiplex
	if [ $STEP -eq 0 ]; then
	    echo "### Step 0 - Demultiplexing ### - START: $(date)" >> $PIPELINE_STATUS
	    echo -e "Run dir: $RUN_DIR\nSample sheet: $SAMPLE_SHEET" >> $PIPELINE_STATUS
	    DEPENDENCIES+=( $(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_demultiplex_%x.err -o ${STD_ERR_OUT_DIR}/%A_demultiplex_%x.out \
		${SCRIPT_DIR}/0_demultiplexer.sh --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET --fastq_dir $FASTQ_DIR \
		--pipeline_status $PIPELINE_STATUS) )
	    echo -e "\nsbatch --dependency=afterok:${DEPENDENCIES[0]} -J $PROJECT \
		-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
		${PIPELINE_DIR}/high_priority_submit_all.sh --step1 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
	    if [ $ONLY_STEP -eq 1 ]; then
		echo "--only_step argument given, exiting"
		exit
	    fi
	    
	    sbatch --dependency=afterok:${DEPENDENCIES[0]} -J $PROJECT \
		-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
		${PIPELINE_DIR}/high_priority_submit_all.sh --step1 ${OPTIONS[@]}


		elif [ $STEP -eq 1 ]; then
		    if [ $TEMP_ARRAY_START -eq 0 ]; then
			echo "### Step 1 - BAM construction ### - START: $(date)" >> $PIPELINE_STATUS
			JOB_COUNT=${#SAMPLE_ARRAY[@]}
			echo -e "Jobs: $JOB_COUNT" >> $PIPELINE_STATUS
			TEMP_ARRAY_START=1
		    fi
	fi

	if [ $STEP -eq 1 ]; then
	#Prep sample array for sentieon_BAM_construction.sh and setup to queue mutlipe paralell jobs into slurm for each sample    
	    SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" -not -name "Undetermined*" -exec basename {} \; | \
                        grep -v "Undetermined" | sed "s/${R1_SUFFIX}//") )
	    if [ -n ${ONLY_BAM} ]; then
		#Set --only_bam if you want to skip other fastq files in the folder
		SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*${R1_SUFFIX}" -exec basename {} \;) )
	    fi
	    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
	    echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
	    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
	    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
	    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
	    echo ${TEMP_SAMPLES_STRING}

	    if [ -z $TARGETED ]; then
	    	TARGETED=0
	    fi
	    if [ -z $SKIP_BAM ]; then
		SKIP_BAM=0
	    fi
	    if [ -z $SKIP_QC ]; then
		SKIP_QC=0
	    fi
	    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
		--array=1-${TEMP_JOB_COUNT} ${PIPELINE_DIR}/1_sentieon_BAM_construction.sh \
		$RESULTS_DIR $SKIP_TRIMMOMATIC $SCRIPT_DIR $TOOLS_DIR $R1_SUFFIX $R2_SUFFIX $REF_FASTA $NUMBER_THREADS $TEMP_SAMPLES_STRING $DBSNP_VCF" >> $PIPELINE_STATUS

	    DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
		--array=1-${TEMP_JOB_COUNT} -p cgawad ${PIPELINE_DIR}/1_sentieon_BAM_construction.sh \
		$RESULTS_DIR $SKIP_TRIMMOMATIC $SCRIPT_DIR $TOOLS_DIR $R1_SUFFIX $R2_SUFFIX $REF_FASTA $NUMBER_THREADS $TEMP_SAMPLES_STRING $FASTQ_DIR $DBSNP_VCF $PROJECT $SKIP_BAM $SKIP_QC $TARGETED $STD_ERR_OUT_DIR) )
	    TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
#honestly i don't understand the point of the code belo2
#	    if [ $TEMP_ARRAY_START -le ${#SAMPLE_ARRAY[@]} ]; then
#		echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
#		    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
#		    ${PIPELINE_DIR}/high_priority_submit_all.sh --step1 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
#		sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
#		    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
#		    ${PIPELINE_DIR}/high_priority_submit_all.sh --step1 --temp_array_start $TEMP_ARRAY_START ${OPTIONS[@]}
#	    else
#		echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
#		    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
#		    ${PIPELINE_DIR}/high_priority_submit_all.sh --step2 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS

#	    fi
	    if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
	    fi
		sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
		    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
		    ${PIPELINE_DIR}/high_priority_submit_all.sh --stepQC ${OPTIONS[@]}
	fi
fi

if [ $STEP -eq 15 ]; then

            SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "*.recalibrated_realigned_deduped_sorted.bam" -exec basename {} \;) )
            JOB_COUNT=${#SAMPLE_ARRAY[@]}
            TEMP_ARRAY_START=1
            TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
            echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
            TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
            echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
            TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
            echo ${TEMP_SAMPLES_STRING}

#	    SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "*${R1_SUFFIX}" -exec basename {} \;) )
#	    if [ -n ${ONLY_BAM} ]; then
#		#Set --only_bam if you want to skip other fastq files in the folder
#		SAMPLE_ARRAY=( $(find ${FASTQ_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*${R1_SUFFIX}" -exec basename {} \;) )
#	    fi
#	    TEMP_ARRAY_START=1
#	    TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
#	    echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
#	    TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
#	    echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
#	    TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
#	    echo "temp sample string is ${TEMP_SAMPLES_STRING}"

	    if [ -z $SKIP_BAM ]; then
		SKIP_BAM=0
	    fi
	    if [ -z $SKIP_QC ]; then
		SKIP_QC=0
	    fi
	    echo -e "\nsbatch --parsable -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
		--array=1-${TEMP_JOB_COUNT} ${PIPELINE_DIR}/1.5_metrics calc.sh \
		$RESULTS_DIR $SKIP_TRIMMOMATIC $SCRIPT_DIR $TOOLS_DIR $R1_SUFFIX $R2_SUFFIX $REF_FASTA $NUMBER_THREADS $TEMP_SAMPLES_STRING $DBSNP_VCF" >> $PIPELINE_STATUS
	    DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --parsable -e $STD_ERR_OUT_DIR/%A_calc_metrics_%a.err -o $STD_ERR_OUT_DIR/%A_calc_metrics_%a.out \
		--array=1-${TEMP_JOB_COUNT} -p cgawad ${PIPELINE_DIR}/1.5_metrics_calc.sh \
		--results_dir $RESULTS_DIR --skip_trimmomatic $SKIP_TRIMMOMATIC --script_dir $SCRIPT_DIR --tools_dir $TOOLS_DIR --r1_suffix $R1_SUFFIX --r2_suffix $R2_SUFFIX --ref_fasta $REF_FASTA --number_threads $NUMBER_THREADS --sample_string $TEMP_SAMPLES_STRING --fastq_dir $FASTQ_DIR --dbSNP $DBSNP_VCF --project $PROJECT --skip_bam $SKIP_BAM --targeted $TARGETED --std_err_out_dir $STD_ERR_OUT_DIR --targets_bed $TARGETS_BED --interval_list $INTERVAL_LIST) )
	    if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
	    fi
		sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
		    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
		    ${PIPELINE_DIR}/high_priority_submit_all.sh --step3 ${OPTIONS[@]}


fi

if [ $STEP -eq 2 ]; then
	echo "### Running Scan2 ### - Start: $(date)" >> $PIPELINE_STATUS
	SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" -exec basename {} \;) )
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        TEMP_ARRAY_START=1
        TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
        echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
        TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
        echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
        TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
        echo ${TEMP_SAMPLES_STRING}

	echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "$DEPENDENCIES" ) -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_scan2_%x.out" >> $PIPELINE_STATUS
	VCF_PATH="${OUTPUT_DIR}${SAMPLE_PREFIX}_svc_merged.vcf"
	NORMAL_PATH="${RESULTS_DIR}/${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"
	#For SCAN2 should only include autosomal chromosomes for WGS
	if [ $TARGETED -eq 0 ]; then
		INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n22chr.bed"
	else
		INTERVAL_LIST="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel_targets_grch38_n22chr_noXYUns.interval_list"
		TARGETS_BED="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/xgen-exome-research-panel-targets_grch38_3col_autosomes_SCAN2.bed"
	fi
	sbatch --time=7-00:00:00 --nice=[-2147483645] --parsable -e $STD_ERR_OUT_DIR/%A_scan2_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_%x.out ${PIPELINE_DIR}/2_scan2.sh --project $PROJECT --results_dir $RESULTS_DIR --genome_version $ANNOVAR_GENOME_VERSION --script_dir $SCRIPT_DIR --sample_prefix $SAMPLE_PREFIX --normal_path $NORMAL_PATH --sample_string $TEMP_SAMPLES_STRING --vcf_path $VCF_PATH --std_err_out $STD_ERR_OUT_DIR --normal_name $NORMAL_SAMPLE_NAME --cross_dir $CROSS_SAMPLE_DIR --pipeline_dir $PIPELINE_DIR --final_dir $FINAL_DIR --targeted $TARGETED --targets_bed $TARGETS_BED --interval_list $INTERVAL_LIST --annovar_dir $ANNOVAR_DIR
 	#sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
        #            -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
        #            ${PIPELINE_DIR}/high_priority_submit_all.sh --step3 ${OPTIONS[@]} --array=1-${TEMP_JOB_COUNT}
	###comment this after testing###
	#exit
	if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
        fi
	sbatch -J $PROJECT \
                    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                    ${PIPELINE_DIR}/high_priority_submit_all.sh --step3 ${OPTIONS[@]}


fi

if [ $STEP -eq 3 ]; then
	echo "options are ${OPTIONS[@]}"
	echo RESULTS DIR IS $RESULTS_DIR
	mkdir -p ${RESULTS_DIR}/ginkgo_outputs
	BAM_REGEX="recalibrated_realigned_deduped_sorted.bam"
	sbatch --nice=[-2147483645] -J $PROJECT \
		-e ${STD_ERR_OUT_DIR}/%A_ginkgo_%x.err -o ${STD_ERR_OUT_DIR}/%A_ginkgo_%x.out \
		${PIPELINE_DIR}/2_ginkgo_cnv.sh --new_5M_folder $RESULTS_DIR/${PROJECT}_5M_Read_BAM_Files \
		--bam_dir $RESULTS_DIR --results_dir $RESULTS_DIR --final_dir $FINAL_DIR --bam_regex ${BAM_REGEX} 

	DEPENDENCIES+=( $(sbatch --nice=[-2147483645] -J $PROJECT --parsable \
		-e ${STD_ERR_OUT_DIR}/%A_summarise_metrics_%x.err -o ${STD_ERR_OUT_DIR}/%A_summarise_metrics_%x.out \
		${PIPELINE_DIR}/2_summarize_metrics.sh $RESULTS_DIR $SCRIPT_DIR $PROJECT $TARGETED $CELL_BARCODES $UMI_PATTERN $RUN_DIR $SAMPLE_SHEET) )
	echo "dependencies are ${DEPENDENCIES[@]}"

#	sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
#                    -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
#                    ${PIPELINE_DIR}/high_priority_submit_all.sh --step3 ${OPTIONS[@]}
fi


#elif [ $STEP -eq 2 ]; then
#    SAMPLE_COUNT=1
#    MISSING_BAMS=0
#    BAMS_FOUND=0
#    for SAMPLE in ${SAMPLE_ARRAY[@]}; do
#        if [ ! -f ${SAMPLE}${BAM_SUFFIX} ]; then
#            echo "Sample number ${SAMPLE_COUNT} not found - ${SAMPLE}${BAM_SUFFIX} file not found"
#            echo "Sample number ${SAMPLE_COUNT} not found - ${SAMPLE}${BAM_SUFFIX} file not found" >> $PIPELINE_STATUS
#            MISSING_BAMS=$((MISSING_BAMS+1))
#        else
#            BAMS_FOUND=$((BAMS_FOUND+1))
#        fi
#        SAMPLE_COUNT=$((SAMPLE_COUNT+1))
#    done
#    if [ $MISSING_BAMS -ne 0 ]; then
#        echo "$BAMS_FOUND BAM files found but expected ${#SAMPLE_ARRAY[@]}"
#        echo "$BAMS_FOUND BAM files found but expected ${#SAMPLE_ARRAY[@]}" >> $PIPELINE_STATUS
#    fi
#    echo "### Step 1 - Sentieon BAM construction ### - END: $(date)" >> $PIPELINE_STATUS

#echo "Sample is "${SAMPLE_ARRAY}
#echo "Temp sample is "${TEMP_SAMPLE_ARRAY}



    # 
    # BAM_5M_SUFFIX=$(echo $BAM_SUFFIX | sed "s/.bam/.5M.bam/")
    # GINKGO_OPTIONS=()
    # if [ "$GENOME_VERSION" = "b37" ]; then
    #     GINKGO_OPTIONS+=( "--b37" )
    # fi
    # mkdir -p ${PROJECT}_Ginkgo_CNV_Analysis
    # echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
    #     ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
    #     --bam_regex .*${BAM_SUFFIX}$ --bam_regex ${BAM_SUFFIX} \
    #     --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis ${GINKGO_OPTIONS[@]}\n" >> $PIPELINE_STATUS
    # sbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
    #     ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
    #     --bam_regex .*${BAM_SUFFIX}$ --bam_regex ${BAM_SUFFIX} \
    #     --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis ${GINKGO_OPTIONS[@]}
    # if [ $(ls *${BAM_5M_SUFFIX} | wc -l) -gt 0 ]; then
    #     mkdir -p ${PROJECT}_5M_Read_BAM_Files
    #     echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
    #         ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
    #         --bam_regex .*${BAM_5M_SUFFIX}$ --bam_regex ${BAM_5M_SUFFIX} \
    #         --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis \
    #         --new_5M_folder $RESULTS_DIR/${PROJECT}_5M_Read_BAM_Files ${GINKGO_OPTIONS[@]}\n" >> $PIPELINE_STATUS
    #     sbatch -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
    #         ${SCRIPT_DIR}/ginkgo_cnv.sh --bam_dir $RESULTS_DIR \
    #         --bam_regex .*${BAM_5M_SUFFIX}$ --bam_regex ${BAM_5M_SUFFIX} \
    #         --results_dir $RESULTS_DIR/${PROJECT}_Ginkgo_CNV_Analysis \
    #         --new_5M_folder $RESULTS_DIR/${PROJECT}_5M_Read_BAM_Files ${GINKGO_OPTIONS[@]}
    # fi
    # echo "Submitted asynchronous Ginkgo CNV analysis job" >> $PIPELINE_STATUS
    # 
    # if [ $SCAN2 -eq 1 ] && [ "$GENOME_VERSION" = "b37" ]; then
    #     if [ -z $SCAN2_BULK ]; then
    #         if [ $GENOME_VERSION = "b37" ]; then
    #             SCAN2_BULK="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_WGA_WGS_BAMS/T1200-1.bam"
    #         else
    #             SCAN2_BULK="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_WGA_WGS_BAMS/T1200-1.bam"
    #         fi
    #     fi
    #     SCAN2_ARRAY=()
    #     SCAN2_BULK_SAMPLE=$(basename $SCAN2_BULK | sed "s/${BAM_SUFFIX}//" | sed 's/.bqsr.marked.bam//' | sed 's/.bam//')
    #     for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    #         if [ "$SAMPLE" != "$SCAN2_BULK_SAMPLE" ]; then
    #             SCAN2_ARRAY+=( "$SAMPLE" )
    #         fi
    #     done
    #     JOB_COUNT=${#SCAN2_ARRAY[@]}
    #     mkdir -p ${PROJECT}_Scan2_Results
    #     echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
    #         --array=1-${JOB_COUNT} ${SCRIPT_DIR}/Scan2.sh \
    #         --script_dir $SCRIPT_DIR --bam_dir $RESULTS_DIR \
    #         --bam_regex $BAM_SUFFIX  --bam_suffix $BAM_SUFFIX \
    #         --project $PROJECT --bulk $SCAN2_BULK --genome_version $GENOME_VERSION  \
    #         --std_err_out $STD_ERR_OUT_DIR --results_dir $RESULTS_DIR\n" >> $PIPELINE_STATUS
    #     sbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
    #         --array=1-${JOB_COUNT} ${SCRIPT_DIR}/Scan2.sh \
    #         --script_dir $SCRIPT_DIR --bam_dir $RESULTS_DIR \
    #         --bam_regex $BAM_SUFFIX --bam_suffix $BAM_SUFFIX \
    #         --project $PROJECT --bulk $SCAN2_BULK --genome_version $GENOME_VERSION  \
    #         --std_err_out $STD_ERR_OUT_DIR --results_dir $RESULTS_DIR
    #     echo "Submitted asynchronous Scan2 analysis job" >> $PIPELINE_STATUS
    # fi
    # 
    # if [ $METHYLATION -eq 1 ]; then
    #     METHYLATION_OPTIONS=()
    #     JOB_COUNT=${#SAMPLE_ARRAY[@]}
    #     mkdir -p ${PROJECT}_mosdepth_Results
    #     if [ "$GENOME_VERSION" = "b37" ]; then
    #         METHYLATION_OPTIONS=( "--b37" )
    #     fi
    #     echo -e "\nsbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
    #         --array=1-${JOB_COUNT} ${SCRIPT_DIR}/mosdepth.sh \
    #         --bam_dir $RESULTS_DIR --bam_suffix $BAM_SUFFIX \
    #         --results_dir ${RESULTS_DIR}/${PROJECT}_mosdepth_Results ${METHYLATION_OPTIONS[@]}\n" >> $PIPELINE_STATUS
    #     sbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
    #         --array=1-${JOB_COUNT} ${SCRIPT_DIR}/mosdepth.sh \
    #         --bam_dir $RESULTS_DIR --bam_suffix $
    #         --results_dir ${RESULTS_DIR}/${PROJECT}_mosdepth_Results ${METHYLATION_OPTIONS[@]}
    #     echo "Submitted asynchronous Scan2 analysis job" >> $PIPELINE_STATUS
    # fi





#TODO-Get the variant calls to work and properly use this script's STEP stuff, i think just adding new steps is the way to go
#TODO-Make script to generate panel of normal file ONCE, I think I'm just going to make a script you run seperately to do this

#if [ $STEP -eq 2 ]; then
	#TODO- this should probably be deleted, or updated to do germline variant calling if don't want to do it in sentieon_BAM_construction
#	echo "### Step 2 - Variant call ### - START: $(date)" >> $PIPELINE_STATUS
#	SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.deduped_sorted.bam" ! -name "*${NORMAL_SAMPLE_NAME}*" -exec basename {} \;) ) 
#	echo $SAMPLE_ARRAY
#	JOB_COUNT=${#SAMPLE_ARRAY[@]}
#	TEMP_ARRAY_START=1
#	TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$($TEMP_ARRAY_START - 1)} )
#	echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
#	TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
#	echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
#	TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
#	echo ${TEMP_SAMPLES_STRING}
#
#	DEPENDENCIES+=( $(sbatch --dependency=afterok:$( IFS=$':'; echo "${DEPENDENCIES[*]}" )  --cpus-per-task $NUMBER_THREADS --parsable -e $STD_ERR_OUT_DIR/%A_somatic_variant_call.err -o $STD_ERR_OUT_DIR/%A_somatic_variant_call.out \
#	--array=1-$TEMP_JOB_COUNT ${PIPELINE_DIR}/2_somatic_variant_calling.sh \
#	$RESULTS_DIR $SKIP_TRIMMOMATIC $SCRIPT_DIR $TOOLS_DIR $R1_SUFFIX $R2_SUFFIX $REF_FASTA $NUMBER_THREADS $TEMP_SAMPLES_STRING $FASTQ_DIR $DBSNP_VCF $PROJECT $NORMAL_SAMPLE_NAME $BAM_DIR) )
#
#	TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))
	     
#	    echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "$DEPENDENCIES" ) -J $PROJECT \
#		-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
#		${PIPELINE_DIR}/high_priority_submit_all.sh --step3 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS

#	    sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
#		-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
#		${PIPELINE_DIR}/high_priority_submit_all.sh --step3 ${OPTIONS[@]}
#fi


#Somatic variant calling step
if [ $STEP -eq 3 ]; then


        echo "### Germline  Variant Call Step ### - START: $(date)" >> $PIPELINE_STATUS
        echo "results dir is ${RESULTS_DIR}"
	cd $RESULTS_DIR

	echo "options are ${OPTIONS[@]}"

        TEMP_ARRAY_INCREMENT=1000
        SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" -exec basename {} \;) )
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        TEMP_ARRAY_START=1
        TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
        echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
        TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
        echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
        TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
        echo "temple string is: ${TEMP_SAMPLES_STRING}"
        echo "dependencies are: ${DEPENDENCIES[*]}" 
        DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --parsable -e $STD_ERR_OUT_DIR/%A_germline_variant_call.err -o $STD_ERR_OUT_DIR/%A_germline_variant_call.out \
        --array=1-${TEMP_JOB_COUNT} ${PIPELINE_DIR}/3_germline_variant_calling.sh  \
        $RESULTS_DIR $REFERENCE_DIR $REF_FASTA $NUMBER_THREADS $TEMP_SAMPLES_STRING) )

        TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))

            echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "$DEPENDENCIES" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/high_priority_submit_all.sh --step4 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS


    if [ -n $NORMAL_SAMPLE_NAME ]; then
	echo "### Somatic Variant Call Step ### - START: $(date)" >> $PIPELINE_STATUS
	echo ${RESULTS_DIR}
	echo "Sample prefix is: ${SAMPLE_PREFIX}"
	echo "Normal sample name is ${NORMAL_SAMPLE_NAME}"
	TEMP_ARRAY_INCREMENT=1000
	SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" -not -name "*${NORMAL_SAMPLE_NAME}*" -exec basename {} \;) )
	JOB_COUNT=${#SAMPLE_ARRAY[@]} 
	TEMP_ARRAY_START=1
	TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
	echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
	TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
	echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
	TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" ) 
	echo ${TEMP_SAMPLES_STRING}
	echo "dependencies are: ${DEPENDENCIES[*]}" 

	#this was broken by not having a sample_prefix, never, ever, EVER use positional arguments again

	DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --parsable -e $STD_ERR_OUT_DIR/%A_somatic_variant_call.err -o $STD_ERR_OUT_DIR/%A_somatic_variant_call.out \
	--array=1-${TEMP_JOB_COUNT} ${PIPELINE_DIR}/3_somatic_variant_calling.sh  \
	$RESULTS_DIR $REFERENCE_DIR $REF_FASTA $NUMBER_THREADS $NORMAL_SAMPLE_NAME $TEMP_SAMPLES_STRING $DBSNP_VCF $SAMPLE_PREFIX) )

	TEMP_ARRAY_START=$(($TEMP_ARRAY_START + $TEMP_ARRAY_INCREMENT))

	    echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "$DEPENDENCIES" ) -J $PROJECT \
		-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
		${PIPELINE_DIR}/high_priority_submit_all.sh --step4 ${OPTIONS[@]}\n" >> $PIPELINE_STATUS
    fi
     	    if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
            fi
    sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
	-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
	${PIPELINE_DIR}/high_priority_submit_all.sh --step4 ${OPTIONS[@]}
fi

######TODO########
#Do joint calling and merge somatic variant files if they exist
if [ $STEP -eq 4 ]; then
	echo "### Merging and Joint genotyping ### - Start: $(date)" >> $PIPELINE_STATUS
	echo "normal sample name is: ${NORMAL_SAMPLE_NAME}"
	echo "variant vcf is: $(find -name "${SAMPLE_PREFIX}*_variant.vcf")"
	if [ -n $NORMAL_SAMPLE_NAME ] && [ -n "$(find -name "${SAMPLE_PREFIX}*_variant.vcf")" ]; then
		echo "starting vcf concat"
		DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --parsable  ${PIPELINE_DIR}/4_vcf_concat.sh $RESULTS_DIR $PROJECT $SAMPLE_PREFIX) )
	fi
	if [ -n "$(find -name "${SAMPLE_PREFIX}*.g.vcf")" ]; then
		echo "Joint genotyping - Start: $(date)" >> $PIPELINE_STATUS
#		ml purge
#		ml biology bwa samtools java
#		module load biology sentieon/202112.01
#		export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
#		export SENTIEON_LICENSE=${SENTIEON_LICENSE:-srcc-license-srcf.stanford.edu:8990} #your license file location
#		cd ${RESULTS_DIR}
#		JOINT_VCF="${SAMPLE_PREFIX}_joint_germline_merged.vcf"
#		sentieon driver -r $REF_FASTA --algo GVCFtyper ${JOINT_VCF} ${SAMPLE_PREFIX}*.g.vcf


		DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --parsable  \
		${PIPELINE_DIR}/4_joint_genotyping.sh \
		$RESULTS_DIR $REFERENCE_DIR $REF_FASTA $NUMBER_THREADS $PROJECT $SAMPLE_PREFIX) )
	fi
 	    if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
            fi
	    sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
		-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
		${PIPELINE_DIR}/high_priority_submit_all.sh --step5 ${OPTIONS[@]}
fi

####TODO#####
#TODO: Should make a script that deletes the rows with normal sample name in them, might just do it in python but could use shell script to and itd be faster
#TODO: Get sigprofiler to work (it doesn't now), get other stuff from annotation thing to work
#Annotate the merged files
if [ $STEP -eq 5 ]; then
	echo "### Annotating Files ### - Start: $(date)" >> $PIPELINE_STATUS
	TEMP_ARRAY_INCREMENT=1000
	SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "*merged.vcf.gz" -not -name "*multianno*" -exec basename {} \;) )
	JOB_COUNT=${#SAMPLE_ARRAY[@]}
	TEMP_ARRAY_START=1
	TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
	echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
	TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
	echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
	TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" ) 
	echo ${TEMP_SAMPLES_STRING}
	echo "dependencies are: ${DEPENDENCIES[*]}" 
	#SAMPLE=$( (find ${RESULTS_DIR} -name "${SAMPLE_PREFIX}*merged*.vcf" -exec basename {} \;) )
	echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "$DEPENDENCIES" ) -J $PROJECT \
	-e ${STD_ERR_OUT_DIR}/%A_annotate_%x.err -o ${STD_ERR_OUT_DIR}/%A_annotate_%x.out" >> $PIPELINE_STATUS
	DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --array=1-${TEMP_JOB_COUNT} --parsable -e $STD_ERR_OUT_DIR/%A_annotate_%x.err -o $STD_ERR_OUT_DIR/%A_annotate_%x.out ${PIPELINE_DIR}/5_annovar.sh \
		$TEMP_SAMPLES_STRING $TRANCHE $PIPELINE_DIR $ANNOVAR_GENOME_VERSION $ANNOVAR_DIR $TOOLS_DIR $RESULTS_DIR $STD_ERR_OUT_DIR $REFERENCE_DIR $TARGETED $REF_FASTA $NORMAL_SAMPLE_NAME) )
 	    if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
            fi
	sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
                -e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
                ${PIPELINE_DIR}/high_priority_submit_all.sh --step6 ${OPTIONS[@]}


fi

#TODO: Make script that caculates VSQR, runs manta, other things in GATK_3

if [ $STEP -eq 6 ]; then
	echo "### Structural Variant Call ### - Start: $(date)" >> $PIPELINE_STATUS
	TEMP_ARRAY_INCREMENT=1000
        SAMPLE_ARRAY=( $(find ${RESULTS_DIR} -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" -exec basename {} \;) )
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        TEMP_ARRAY_START=1
        TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
        echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
        TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
        echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
        TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
        echo ${TEMP_SAMPLES_STRING}
        echo "dependencies are: ${DEPENDENCIES[*]}"
        #SAMPLE=$( (find ${RESULTS_DIR} -name "${SAMPLE_PREFIX}*merged*.vcf" -exec basename {} \;) )
        echo -e "\nsbatch --dependency=afterany:$( IFS=$':'; echo "$DEPENDENCIES" ) -J $PROJECT \
        -e ${STD_ERR_OUT_DIR}/%A_manta_%x.err -o ${STD_ERR_OUT_DIR}/%A_manta_%x.out" >> $PIPELINE_STATUS
        DEPENDENCIES+=( $(sbatch --nice=[-2147483645] --array=1-${TEMP_JOB_COUNT} --parsable -e $STD_ERR_OUT_DIR/%A_manta_%x.err -o $STD_ERR_OUT_DIR/%A_manta_%x.out ${PIPELINE_DIR}/6_manta_sv.sh \
                $TEMP_SAMPLES_STRING $REF_FASTA $RESULTS_DIR $FINAL_DIR $TARGETED) )
	 if [ $ONLY_STEP -eq 1 ]; then
                echo "--only_step argument given, exiting"
                exit
         fi
	sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) -J $PROJECT \
			-e ${STD_ERR_OUT_DIR}/%A_submit_all_%x.err -o ${STD_ERR_OUT_DIR}/%A_submit_all_%x.out \
			${PIPELINE_DIR}/high_priority_submit_all.sh --step7 ${OPTIONS[@]}

fi
###Todo - make this jsut run scan2 for each sample individually, it's too annoying to set scan2 up to accept multiple bams at once and i dont think it will be any faster



echo "### submit_all cycle done ### Finished: $(date)" >> $PIPELINE_STATUS
exit
