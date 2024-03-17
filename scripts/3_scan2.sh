#!/bin/bash
#
#SBATCH --job-name=3_scan2
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=200G
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad

set -x

START_TIME=$(date +%s)
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/"
#BAM_REGEX=".*.bam"
#BAM_SUFFIX=".bam"

#note to self: add slurm commands to email #SBATCH --mail-type=ALL and #SBATCH --mail-user=sschulz@stanford.edu to better monitor the long scan2 runs

###IMPORTANT NOTE###

#This pipeline uses a special version of Scan2, in which gatk3 is bypassed in snakemake.gatk3_joint in lib for scan2:

#rule make_arg_file:
#    input:
#    output:
#    resources:
#        mem=200
#    shell:
#        "echo make_arg_file"
#
#rule gatk_gather:
#    input:
#    output:
#        "gatk/hc_raw.mmq{gatk_mmq}.vcf"
#    resources:
#        mem=4000
#    shell:
#        "echo gatk_gather"
#
#rule gatk_scatter:
#    input:
#        bam=expand("{bam}", bam=config['bam_map'].values()),
#    output:
#    params:
#        bamlist=expand("-i {bam}", bam=config['bam_map'].values()),
#        mmq="{gatk_mmq}"
#    resources:
#        mem=10000
#    shell:
#        "echo gatk_scatter"
#
#may eventually want to work with park lab to see if we can make a fork with sentieon, otherwise i can save a backup of the conda env with this
#change made

##IMPORT DEBUGGING NOTE##
#R SCRIPTS ASSOCIATED WITH SCAN2 WILL SUPER DUPER BREAK IF YOU DONT PUT .libPaths("/home/groups/cgawad/miniconda3/envs/scan2/lib/R/library")
#IN THEM, THIS IS ASSOCIATED WITH SOME PROBLEM WITH THE CONDA ENVIRONMENTS THAT I AM NOT SURE ABOUT, THIS WORKAROUND SHOULD FIX ERRORS AND THE SCRIPTS
#IN scan2 CONDA ENVIRONMENT ALREADY HAVE THIS LINE ADDED IN

##MAY NEED TO DO IF STATEMENT WHERE IF ITS EXOME JUST DONT INPUT REGIONS FOR CALL_MUTATIONS/MAKE_PANEL, NOT ENTIRELY SURE THE REGIONS DO ANYTHING IF ITS NOT CALLING MUTATIONS, CUZ IT SEEMS LIKE IT ACTUALLY MAKES THINGS SLOWER/HANG WHEN CALCULATING HOW TO SPLIT UP THE JOBS BY REGION

#commented out "resources.mem" part of script, may need to put this back in if Scan2 is breaking


#Default CROSS_SAMPLE_BAM folder
CROSS_SAMPLE_BAM="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/IG11_Methyl_Genome_Seq/211002_Methyl_WGS_Patent/Partial_Pipeline/Kindred"
GENOME_VERSION="hg38"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf"
SHAPEIT_DIR="${REFERENCE_DIR}"
REGIONS_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_100_windows.txt"
#default to autosomal chrom if no interval specified
TARGETS_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_n22chr.bed"
GOLD_STANDARD="/oak/stanford/groups/cgawad/Reference_Files/T1200_hg38_BAMs/T1200-1.bam"
#NORMAL_BAM_PATH="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/ANEU01_Bulk_WB_WES_Capt09_S26.realigned_deduped_sorted.bam"
SC_BAM="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/ANEU01_Bulk_EndovascularControl_WES_Capt09_S24.realigned_deduped_sorted.bam"
PANEL_OF_NORMAL="${REFERENCE_DIR}/1000g_pon.hg38.vcf.gz"

TARGETED=0
#CHANGE AFTER TESTING PELASPLEASE
STEP=0
EMAIL=0
SKIP_PANEL=1
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --project )         shift
                            PROJECT=$1
                            ;;
        --scratch_dir )     shift
                            SCRATCH_DIR=$1
                            ;;
        --genome_version )  shift
                            GENOME_VERSION=$1
                            ;;
        --script_dir )      shift
                            SCRIPT_DIR=$1
                            ;;
        --normal_path )     shift
                            NORMAL_BAM_PATH=$1
                            ;;
        --sample_string )   shift
                            SAMPLE_STRING=$1
                            ;;
        --normal_name )     shift
                            NORMAL_SAMPLE_NAME=$1
                            ;;
        --cross_dir )	    shift
                            CROSS_SAMPLE_DIR=$1
                              ;;
        --std_err_out )     shift
                            STD_ERR_OUT_DIR=$1
                            ;;
        --pipeline_dir )    shift
                            PIPELINE_DIR=$1
                            ;;
        --targeted ) 	    shift
                            TARGETED=$1
                            ;;
        --targets_bed )     shift
                            TARGETS_BED=$1
                            ;;
        --interval_list )   shift
                            INTERVAL_LIST=$1
                            ;;
        --annovar_dir )     shift
                            ANNOVAR_DIR=$1
                            ;;
        --step0 )           STEP=0
                            ;;
        --step1 )	        STEP=1
                            ;;
        --step2 ) 	        STEP=2
                            ;;
        --step3 )	        STEP=3
                            ;;
        --step4 ) 	        STEP=4
                            ;;
        --step5 )           STEP=5
                            ;;
        --step6 ) 	        STEP=6
                            ;;
        --step7 )	        STEP=7
                            ;;
        --stepJ ) 	        STEP=15
                            ;;
        --email )	        shift
                            EMAIL=$1
                            ;;
        --skip_panel )      shift
                            SKIP_PANEL=$1
                            ;;
    esac
    shift
done

if [ -z $PROJECT ] || [ -z $SCRATCH_DIR ] || [ -z $GENOME_VERSION ] || [ -z $SCRIPT_DIR ] || \
    [ -z $NORMAL_BAM_PATH ] || [ -z $SAMPLE_STRING ] || [ -z $NORMAL_SAMPLE_NAME ] || [ -z $CROSS_SAMPLE_DIR ] || \
    [ -z $STD_ERR_OUT_DIR ] || [ -z $PIPELINE_DIR ] || [ -z $TARGETED ] || [ -z $TARGETS_BED ] || \
    [ -z $INTERVAL_LIST ] || [ -z $ANNOVAR_DIR ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"

OPTIONS="--project $PROJECT"
OPTIONS="${OPTIONS} --scratch_dir ${SCRATCH_DIR}"
OPTIONS="${OPTIONS} --genome_ver $GENOME_VERSION"
OPTIONS="${OPTIONS} --script_dir $SCRIPT_DIR"
OPTIONS="${OPTIONS} --normal_path $NORMAL_BAM_PATH"
OPTIONS="${OPTIONS} --std_err_out $STD_ERR_OUT_DIR"
OPTIONS="${OPTIONS} --sample_string $SAMPLE_STRING"
OPTIONS="${OPTIONS} --normal_name $NORMAL_SAMPLE_NAME"
if [ ! -z $CROSS_SAMPLE_DIR ]; then 
    OPTIONS="${OPTIONS} --cross_dir $CROSS_SAMPLE_DIR"
fi
OPTIONS="${OPTIONS} --targeted $TARGETED"
OPTIONS="${OPTIONS} --targets_bed $TARGETS_BED"
OPTIONS="${OPTIONS} --interval_list $INTERVAL_LIST"
OPTIONS="${OPTIONS} --pipeline_dir $PIPELINE_DIR"
OPTIONS="${OPTIONS} --annovar_dir $ANNOVAR_DIR"
OPTIONS="${OPTIONS} --email $EMAIL"
OPTIONS="${OPTIONS} --skip_panel $SKIP_PANEL"



echo AT START OPTIONS ARE ${OPTIONS}
if [ $TARGETED -eq 1 ];then
    INTERVAL_LIST=$INTERVAL_LIST
    REGIONS_BED=$TARGETS_BED
fi

SCRIPT_DIR=${PIPELINE_DIR}/scripts
SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') ) 
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE_NAME=${SAMPLE%.realigned_deduped_sorted.bam}

SCAN2_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_SCAN2_status.txt

CROSS_SAMPLE_PANEL=$SCRATCH_DIR/$SCAN2_RESULTS/panel/panel.tab.gz
GATK_VCF=$SCRATCH_DIR/$SCAN2_RESULTS/gatk/hc_raw.mmq60.vcf

ml purge
ml system gsl/2.3 curl/7.54.0 devel java/1.8.0_131 perl/5.26.0
#ml math R/4.0.2 biology gatk/4.1.4.1 bedtools/2.27.1 samtools/1.8 bwa/0.7.17 sentieon/202112.01
#removed R load to test for bug found when running on other systems

ml system poppler/0.47.0

ml biology gatk/4.1.4.1 bedtools/2.27.1 samtools/1.8 bwa/0.7.17 sentieon/202112.01
ml sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

export R_LIBS="/home/groups/cgawad/R_libs"

cd $SCRATCH_DIR

#
#if [ $GENOME_VERSION = "b37" ]; then
#    REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_b37"
#    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
#    DBSNP_VCF="${REFERENCE_DIR}/Scan2/dbsnp_138.b37.vcf"
#    SHAPEIT_DIR="${REFERENCE_DIR}/Scan2/1000GP_Phase3"
#    REGIONS_BED="${REFERENCE_DIR}/Scan2/gatk_regions_example.txt"
#    GOLD_STANDARD="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_WGA_WGS_BAMS/T1200-1.bam"
#    OPTIONS+=( "--b37" )
#fi

source /home/groups/cgawad/miniconda3/etc/profile.d/conda.sh

conda deactivate

conda activate scan2 

SCAN2_RESULTS="Scan2_Results_${PROJECT}"

mkdir -p $SCAN2_RESULTS

#if [ -n $(ls /oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/Scan2_Results_) ]; then
#fi

#if [ -d Scan2_Results_${SAMPLE} ]; then
#    echo "Folder exists, will validate and re-run any ended Scan2 processes with current configuration"
#    cd Scan2_Results_${SAMPLE}
#else

cd ${SCRATCH_DIR}

NORMAL_BAM_PATH="${SCRATCH_DIR}/${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"

echo "normal sample is ${NORMAL_BAM_PATH}"

SC_BAMS=$(find $SCRATCH_DIR -maxdepth 1 -name "*.realigned_deduped_sorted.bam")

echo "sc-bams is ${SC_BAMS}"

SCAN2_BAM_ARGS=""

for i in ${SC_BAMS[@]}; do
        echo "arg is ${i}"
        TEMP=${i/#/--sc-bam }
        SCAN2_BAM_ARGS="${SCAN2_BAM_ARGS} ${TEMP}"
done

echo Scan2 bam args are: $SCAN2_BAM_ARGS
if [ $SKIP_PANEL -eq 0 ]; then
    #need to call variants from another donor to do proper indel calling
    CROSS_BAMS=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "*.bam" -not -name "*bulk*")

    echo "cross_bams is ${CROSS_BAMS}"

    CROSS_BAM_ARGS=""

    for i in ${CROSS_BAMS[@]}; do
        echo "arg is ${i}"
        TEMP=${i/#/--sc-bam }
        CROSS_BAM_ARGS="${CROSS_BAM_ARGS} ${TEMP}"
    done

    echo $CROSS_BAM_ARGS

    BAM_ARGS=""
    SCAN2_ARGS="${SCAN2_BAM_ARGS} ${CROSS_BAM_ARGS}"
    BAM_ARGS=$(echo ${SCAN2_ARGS} | sed 's/--sc-bam/-i/g')
    echo "bam_args is ${BAM_ARGS}"
    BAM_ARGS=${BAM_ARGS}
else
    echo "SKIPPING ADDING CROSS PANEL FOR VARIANT CALLING"
    BAM_ARGS=$(echo ${SCAN2_BAM_ARGS} | sed 's/--sc-bam/-i/g')
    
fi
echo BAM ARGS BEFORE STEPS START IS ${BAM_ARGS}
echo SCAN2 BAM ARGS FOR CALL MUTS BEFOER STEPS IS ${SCAN2_BAM_ARGS}

#BAM_ARGS get used for mutation calling (not direclty used for scan2 argument sample names)
TEMP=$(echo ${BAM_ARGS} | sed 's/ -i /:/g')
echo TEMP IS ${TEMP}
BAM_SAMPLE_STRING=$(echo ${TEMP} | sed 's/-i //')
echo BAM SAMPLE STRING IS ${BAM_SAMPLE_STRING}

#may need to exclude normal sample from this bam calling
BAM_NAMES=$(find $SCRATCH_DIR -maxdepth 1 -name "*.realigned_deduped_sorted.bam" -exec basename {} \;)


echo "### Running Scan2 SAMPLE: $PROJECT  ### - START: $(date)" >> $SCAN2_STATUS


echo "### Running Sentieon SAMPLE: $PROJECT  ### - START: $(date)" >> $SCAN2_STATUS

if [ $STEP -eq 0 ]; then
    if [ $EMAIL -eq 1 ]; then
                # Email the user when the job is started if --email flag was set in submit_all
                echo "Scan2 job for ${PROJECT} has started, with job name: ${SLURM_JOB_NAME}, start time: ${SLURM_JOB_START_TIME}. Please see ${PROJECT} folders std_err_out folder for more details. " | mailx -s "Scan2 job for ${PROJECT}:${SLURM_JOB_ID} has started" "${USER}@stanford.edu"
        fi
    if [ ! "$(ls -A "${SCAN2_RESULTS}")" ]; then
        ml biology bwa samtools java
        module load biology sentieon/202112.01
        export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
        export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location



        ml system jemalloc/5.3.0
        export LD_PRELOAD=/share/software/user/open/jemalloc/5.3.0/lib/libjemalloc.so
        MALLOC_CONF=metadata_thp:auto,background_thread:true,dirty_decay_ms:30000,muzzy_decay_ms:30000
        echo "Folder does not exist. Will create folder and configure for Scan2 running"
        cd $SCRATCH_DIR

        rm -R $SCAN2_RESULTS

        scan2 -d "${SCAN2_RESULTS}" init

        ### New joint genotyping codeblock here ###
        TEMP_ARRAY_INCREMENT=1000
        SAMPLE_ARRAY=( $(echo ${BAM_SAMPLE_STRING} | sed 's/:/ /g') )
        JOB_COUNT=${#SAMPLE_ARRAY[@]}
        TEMP_ARRAY_START=1
        TEMP_SAMPLE_ARRAY=( ${SAMPLE_ARRAY[@]:$(($TEMP_ARRAY_START - 1)):$TEMP_ARRAY_INCREMENT} )
        echo "temp sample array is :"${TEMP_SAMPLE_ARRAY}
        TEMP_JOB_COUNT=${#TEMP_SAMPLE_ARRAY[@]}
        echo "Submitting $TEMP_JOB_COUNT jobs for samples $TEMP_ARRAY_START to $(($TEMP_ARRAY_START + ${#TEMP_SAMPLE_ARRAY[@]} - 1))" >> $PIPELINE_STATUS
        TEMP_SAMPLES_STRING=$( IFS=$':'; echo "${TEMP_SAMPLE_ARRAY[*]}" )
        echo "temple string is: ${TEMP_SAMPLES_STRING}"
        echo "dependencies are: ${DEPENDENCIES[*]}" 

        echo "***STARTING VARIANT CALLING NOW***"
        DEPENDENCIES+=( $(sbatch --verbose --array=1-${TEMP_JOB_COUNT} --parsable -e ${STD_ERR_OUT_DIR}/%A_mmq1_sentieon_variant_call_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_mmq1_sentieon_variant_call_scan2_%x.out $SCRIPT_DIR/scan2_germline_call.sh --results-dir $SCRATCH_DIR --normal-path $NORMAL_BAM_PATH --ref $REF_FASTA --dbsnp $DBSNP_VCF --scan2-results $SCAN2_RESULTS --regions-bed $TARGETS_BED --sample_string $BAM_SAMPLE_STRING --mmq 1 --pipeline_dir $PIPELINE_DIR --bam_args echo ${BAM_ARGS}) )

        DEPENDENCIES+=( $(sbatch --verbose --array=1-${TEMP_JOB_COUNT} --parsable -e ${STD_ERR_OUT_DIR}/%A_mmq60_sentieon_variant_call_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_mmq60_sentieon_variant_call_scan2_%x.out $SCRIPT_DIR/scan2_germline_call.sh --results-dir $SCRATCH_DIR --normal-path $NORMAL_BAM_PATH --ref $REF_FASTA --dbsnp $DBSNP_VCF --scan2-results $SCAN2_RESULTS --regions-bed $TARGETS_BED --sample_string $BAM_SAMPLE_STRING --mmq 60 --pipeline_dir $PIPELINE_DIR --bam_args echo ${BAM_ARGS}) )
    fi
    echo dependencies are ${DEPENDENCIES}
    if [ ! -z $DEPENDENCIES ]; then
        echo OPTIONS ARE ${OPTIONS}
            sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_stepJ_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_stepJ_%x.out --time=5-00:00:00 --wrap "sh $SCRIPT_DIR/3_scan2.sh --stepJ ${OPTIONS}"
    else
        echo OPTIONS ARE ${OPTIONS}
        sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_stepJ_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_stepJ_%x.out --time=5-00:00:00 --wrap "sh $SCRIPT_DIR/3_scan2.sh --stepJ ${OPTIONS}"

    fi

fi

if [ $STEP -eq 15 ]; then
    FILE=$SCAN2_RESULTS/gatk/hc_raw.mmq60.vcf

    if [ ! -f "$FILE" ]; then
        DEPENDENCIES+=( $(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_mmq1_joint_gt_%x.err -o ${STD_ERR_OUT_DIR}/%A_mmq1_joint_gt_%x.out $SCRIPT_DIR/scan2_joint_genotyping.sh $SCRATCH_DIR $REFERENCE_DIR $REF_FASTA $PROJECT 1 $SCAN2_RESULTS) )
        DEPENDENCIES+=( $(sbatch --parsable -e ${STD_ERR_OUT_DIR}/%A_mmq60_joint_gt_%x.err -o ${STD_ERR_OUT_DIR}/%A_mmq60_joint_gt_%x.out $SCRIPT_DIR/scan2_joint_genotyping.sh $SCRATCH_DIR $REFERENCE_DIR $REF_FASTA $PROJECT 60 $SCAN2_RESULTS) )
    fi
    if [ ! -z $DEPENDENCIES ]; then
                sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_step1_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_step1_%x.out --time=5-00:00:00 --wrap "sh $SCRIPT_DIR/3_scan2.sh --step1 ${OPTIONS}"
        else
                sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_step1_MAKE_PANEL_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_step1_MAKE_PANEL_%x.out --time=5-00:00:00 --job-name="step1" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step1 ${OPTIONS}"

        fi


fi

echo SKIP PANEL is $SKIP_PANEL

if [ $STEP -eq 1 ]; then

    if [ $SKIP_PANEL -eq 0 ]; then	
        #no clue why we lost the hc_raw.mmq60.vcf and i hate that it randomly gets deleted so copy it into a backup here
        cp $GATK_VCF $SCRATCH_DIR/$SCAN2_RESULTS/gatk/BACKUP_hc_raw.mmq60.vcf

        #Pretty sure need to make panel first as they do in demo

        #making the metadata.csv

        #Bam names shouldn't have the germline name in it, but it doesn't break things if germline is erroneously labeled a single cell, it's just inefficient
        BAM_NAMES=$(find $SCRATCH_DIR -maxdepth 1 -name "*.realigned_deduped_sorted.bam" -exec basename {} \;)

        cd $SCAN2_RESULTS

        rm metadata.csv
        rm temp.csv
        rm cross.csv

        echo "donor,sample,amp" >> temp.csv

        for i in ${BAM_NAMES}; do
            echo "d1,${i%.realigned_deduped_sorted.bam},SC" >> temp.csv
        done

        grep -vwE "$NORMAL_SAMPLE_NAME" temp.csv > metadata.csv

        echo "d1,${NORMAL_SAMPLE_NAME%realigned_deduped_sorted.bam},bulk" >> metadata.csv


        #get cross samples for panel, note that they need the correct naming convention or things will be wonky
        #will need to change this to not have specific name after testing, dep on what dr. gawad wants can just change this to use 1 cross sample and 1 bulk 
        CROSS_BAM_NAMES=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "*.bam" -not -name "*bulk*" -exec basename {} \;)

        for i in ${CROSS_BAM_NAMES}; do
            echo "d2,${i%.bqsr.marked.bam},SC" >> cross.csv
        done

        grep -vwE "bulk" cross.csv >> metadata.csv

        bulk=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "bulk*.bam" -exec basename {} \;)

        echo "d2,${bulk%.bqsr.marked.bam},bulk" >> metadata.csv


        #cross sample panel will be off if bulk is not lower case in bam names
        #CROSS_SAMPLE_NAMES=$(find $CROSS_SAMPLE_BAMS -maxdepth 1 -name "*.bam" ! -name "*bulk*" -exec basename {} \;)
        #CROSS_SAMPLE_BULK=
        #for i in ${CROSS_SAMPLE_NAMES}; do
        #        echo "d2,${i%.bam},SC" >> temp.csv
        #done
        #
        #grep -vwE "bulk" temp.csv > metadata.csv
        #
        #echo "d2,${NORMAL_SAMPLE_NAME%realigned_deduped_sorted.bam},bulk" >> metadata.csv


        #need an automated way to do this


        echo "### Running makepanel SAMPLE: $SAMPLE_NAME ### - START: $(date)" >> $SCAN2_STATUS

        scan2 config \
            --analysis makepanel \
            --ref $REF_FASTA \
            --verbose \
            --genome 'hg38' \
            --dbsnp $DBSNP_VCF \
            --bulk-bam $NORMAL_BAM_PATH \
            --eagle-refpanel "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/eagle_1000g_panel" \
            --eagle-genmap "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/genetic_map_hg38_withX.txt.gz" \
            --phaser "eagle" \
            --gatk "gatk3_joint" \
            --makepanel-metadata metadata.csv \
            --regions-file $REGIONS_BED \
            $SCAN2_ARGS

        scan2 validate
    #--regions-file $INTERVAL_LIST \
    #uncomment after testing mustig rescue
    # --mem={resources.mem}   <---- put this back into the sbatch args if stuff breaks
    DEPENDENCIES=( $(sbatch --time=7-00:00:00 -p cgawad scan2 run --joblimit 95 --snakemake-args " --keep-going --max-status-checks-per-second 0.1" --cluster 'sbatch -p cgawad -c {threads} --mem=200G -t 7-00:00:00 -o %logdir/slurm-%A.log') )
        echo dependencies are ${DEPENDENCIES[-1]}
        DEPENDENCIES="${DEPENDENCIES[-1]}"
        echo dependencies are ${DEPENDENCIES}
        echo "options about to be passed in to step2 is ${OPTIONS[@]}"



        sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_step2_CALL_MUTS_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_step2_CALL_MUTS_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --job-name="step2" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step2 ${OPTIONS}"
    else
        sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_step2_CALL_MUTS_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_step2_CALL_MUTS_%x.out --time=5-00:00:00 --job-name="step2" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step2 ${OPTIONS}"
    fi


fi

#--eagle-refpanel "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/eagle_1000g_panel" \
#--eagle-genmap "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/genetic_map_hg38_withX.txt.gz" \
#--phaser "eagle" \

#--snakemake-args '--jobs 96' --cluster 'sbatch -p cgawad -c 1 --mem=8G  -t 5-00:00:00 -o %logdir/slurm-%A.log'

#--regions-file $REGIONS_BED \
#--regions 22:10000000-10999999,22:11000000-11999999 \
#########UNCOMMENT END #####


#TODO: Making the cross sample panel is EXTREMELY time consuming, we should construct 1 cross sample panel for use in as many things as possible and then add option to specify cross sample panel, which will just copy the specified reference panel into the $CROSS_SAMPLE_PANEL directory below so that scan2 can use it, this option should skip makepanel altogether but still do sentieon variant calling, just with nothing inserted for the cross_sample directory

CROSS_SAMPLE_PANEL=$SCRATCH_DIR/$SCAN2_RESULTS/panel/panel.tab.gz
GATK_VCF=$SCRATCH_DIR/$SCAN2_RESULTS/gatk/hc_raw.mmq60.vcf



#Pretty sure if want to use gatk-vcf on a sentieon output will need to use "bcftools annotate" to add in header info
#included in Scan2 output vcf but not in sentieon output vcf              
#Try the following commands # do not replace TAG if already present




if [ $STEP -eq 2 ]; then

echo "### Running call_mutations SAMPLE: $SAMPLE_NAME Time: $(date) ###" >> $SCAN2_STATUS
    source /home/groups/cgawad/miniconda3/etc/profile.d/conda.sh

    conda deactivate

    conda activate scan2 
    cd $SCAN2_RESULTS

#changed some core numbers (besides abmodel-n-cores) to hopefully make scan2 run smoother and also use all cores on cluster if posisble, get
#rid of digest_depth_ncores and genotype_n_cores if this breaks stuff
    if [ $SKIP_PANEL -eq 0 ]; then
        scan2 config \
        --analysis call_mutations \
        --eagle-refpanel "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/eagle_1000g_panel" \
        --eagle-genmap "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/genetic_map_hg38_withX.txt.gz" \
        --verbose \
        --genome 'hg38' \
        --phaser "eagle" \
        --gatk "gatk3_joint" \
        --ref $REF_FASTA \
        --abmodel-n-cores 10 \
        --digest_depth_n_cores 14 \
        --genotype_n_cores 14 \
        --dbsnp $DBSNP_VCF \
        --bulk-bam $NORMAL_BAM_PATH \
        --gatk-vcf $GATK_VCF \
        --cross-sample-panel $CROSS_SAMPLE_PANEL \
        --regions-file $REGIONS_BED \
        $SCAN2_BAM_ARGS 

        scan2 validate
    else
        echo "running call mutations without panel"
        echo $REF_FASTA is the ref fasta
        echo REGIONS BED IS $REGIONS_BED
        echo GATK VCF IS $GATK_VCF
        echo NORMAL BAM IS $NORMAL_BAM_PATH
    
        
        scan2 config \
             --eagle-refpanel "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/eagle_1000g_panel" \
             --eagle-genmap "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/genetic_map_hg38_withX.txt.gz" \
             --verbose \
             --genome 'hg38' \
             --phaser "eagle" \
             --gatk "gatk3_joint" \
             --ref $REF_FASTA \
             --abmodel-n-cores 10 \
             --dbsnp $DBSNP_VCF \
             --bulk-bam $NORMAL_BAM_PATH \
             --gatk-vcf $GATK_VCF \
             --regions-file $REGIONS_BED \
             $SCAN2_BAM_ARGS

# its complaining about these options and im going insane --digest_depth_n_cores 14 \--genotype_n_cores 14 \
    

                scan2 validate	
    fi
#--regions-file $INTERVAL_LIST \
#uncomment this after testing mutrescue
#--mem={resources.mem} <--- put this back in cluster sbatch args if stuff breaks
#Dr. Luquette recommends maximum possible job limit, but i vaguely remember job limits higher than 95 causing some issues of potential hanging/just taking a really long time to compute and queue up jobs, might be worth trying changing --joblimit to 1000 if want to speed things up
#i think 1000 job limit is better, the cluster has a job limit of 1000 anyways
    DEPENDENCIES=( $(sbatch --time=7-00:00:00 -p cgawad scan2 run --joblimit 1000 --snakemake-args " --keep-going --max-status-checks-per-second 0.1" --cluster 'sbatch -p cgawad -c {threads} --mem=200G -t 7-00:00:00 -o %logdir/slurm-%A.log') )
#
#
     echo "Scan2 configured"

    echo options about to be passed in to step3 is ${OPTIONS[*]}

    echo -e "sbatch --dependency=afterany:$( echo "${DEPENDENCIES}" ) -J $PROJECT \
             $SCRIPT_DIR/3_scan2.sh --step3 ${OPTIONS[@]}
    fi"

    DEPENDENCIES="${DEPENDENCIES[-1]}"
    #PLEASE UNCOMMENT THIS LATER EVERYTHING IS BROKEN AND I HAVE TO CHECK IF ITS JUST THE CONFIG THATS MESSING UP
    ##sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_scan2_step3_RESCUE_%x.err -o $STD_ERR_OUT_DIR/%A_scan2_step3_RESCUE_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --job-name="step3" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step3 ${OPTIONS}"

    ###adding a simple if statement to keep attempting to run step2 (call mutations) if a .rda file is not found, this doesn't check for
    ###each sample so still could error even without this but hopefully will solve our silent failure problem
     

### THESE THREE ARGUMENTS MAY NEED TO BE ADDED BACK AFTER TESTING ###
#--cross-sample-panel $CROSS_SAMPLE_PANEL
#--sc-bam $SC_BAM

#echo "Scan2 validated"
#--regions-file $REGIONS_BED \
#--gatk-vcf $GATK_VCF
#--regions 22:10000000-10999999,22:11000000-11999999 \
#
echo "Scan2 ran"
echo "### Running Scan2 ### - END: $(date)" >> $SCAN2_STATUS
#

fi

echo "### Analyzing Scan2 mutational rates and true positives ### - START: $(date)"

#echo "Waiting for callmutations to finish"

#until [ -f $checkpoint ]; do
#	checkpoint="$SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/*.realigned_deduped_sorted.bam/scan2_object.rda"
#	read -t 5
#done
#echo "callmutations finished"

if [ $STEP -eq 3 ]; then

    BAM_NAMES=$(find $SCRATCH_DIR -maxdepth 1 -name "*.realigned_deduped_sorted.bam" -exec basename {} \;)

    SCAN2_RESCUE_ARGS=""
    for dir in $SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/*/; do
        SAMPLE_DIR=${dir%*/}
        echo "dir is ${SAMPLE_DIR}"
        
        RDA="${SAMPLE_DIR}/scan2_object.rda"
        echo "rda is ${RDA}"
        SAMPLE_NAME=$(basename $SAMPLE_DIR)
        if [ echo ${SAMPLE_NAME} | grep -q ${NORMAL_SAMPLE_NAME} ]; then
            echo "this is the normal sample scan2 object; skipping"	
        else
            #RDA="$SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/${SAMPLE%.realigned_deduped_sorted.bam}/scan2_object.rda"
            TEMP=${RDA/#/--scan2-object }
            SCAN2_RESCUE_ARGS="${SCAN2_RESCUE_ARGS} ${TEMP} ${RDA}"
        fi
    done

    echo $SCAN2_RESCUE_ARGS

    cd $SCAN2_RESULTS
    echo CONFIGURING MUTSIG RESCUE
    scan2 config \
        --verbose \
        --analysis rescue \
        --rescue-target-fdr 0.01 \
        ${SCAN2_RESCUE_ARGS}

    scan2 validate

#--mem={resources.mem} <--- put this back in cluster sbatch args if stuff breaks
    DEPENDENCIES+=( $(sbatch --time=5-00:00:00 -p cgawad scan2 rescue --joblimit 50 --snakemake-args " --keep-going --max-status-checks-per-second 0.1" --cluster 'sbatch -p cgawad -c {threads} --mem={resources.mem} -t 7-00:00:00 -o %logdir/slurm-%A.log') )
    DEPENDENCIES="${DEPENDENCIES[-1]}"
    
    echo options about to be passed in to step4 is ${OPTIONS[*]}
    
    echo -e "sbatch --dependency=afterany:$( echo "${DEPENDENCIES}" ) -J $PROJECT \
             $SCRIPT_DIR/3_scan2.sh --step4 ${OPTIONS[@]}
    fi"


     
    sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_post_scan2_%x.err -o $STD_ERR_OUT_DIR/%A_post_scan2_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --job-name="step4" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step4 ${OPTIONS}"
    


fi

results="${SCRATCH_DIR}/${SCAN2_RESULTS}/results"
mkdir -p $results
MERGED_TSV="${SCRATCH_DIR}/all_cells_merged.tsv"
MERGED_VCF="${SCRATCH_DIR}/all_cells_merged.vcf"



if [ $STEP -eq 4 ];then


    cd $SCRATCH_DIR/$SCAN2_RESULTS
    results="${SCRATCH_DIR}/${SCAN2_RESULTS}/results"
    mkdir -p $results
    MERGED_TSV="${SCRATCH_DIR}/all_cells_merged.tsv"
    count=0
    MERGED_VCF="${SCRATCH_DIR}/all_cells_merged.vcf"
    for dir in $SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/*/; do
    #tsv_extract saves the dataframes in the R objects as TSVs
            SAMPLE_DIR=${dir%*/}
        SAMPLE_PATH=${dir%/}
        echo sample dir is $SAMPLE_DIR	
                RDA="${SAMPLE_DIR}/scan2_object.rda"
        echo sample path is $SAMPLE_PATH		
        cd $SAMPLE_DIR
        echo "Running Scan2_tsv_extract.R now"
                Rscript ${SCRIPT_DIR}/Scan2_tsv_extract.R $RDA $SAMPLE_PATH
        
        #get the mutburdens from the R objects
                TSV=${SAMPLE_PATH}_scan2.tsv
        burden=${SAMPLE_PATH}_mutburden.tsv
        mv $burden $results

        #change header lines to correct formatting for VCF
        sed '0,/chr/{s/chr/CHROM/}' $TSV > temp.tsv
        mv temp.tsv $TSV	
        sed -i '0,/#CHROM/{s/#CHROM/CHROM/}' $TSV
        sed -i "s/pos/POS/" $TSV
        sed -i "s/dbsnp/ID/" $TSV
        sed -i "s/refnt/REF/" $TSV
        sed -i "s/altnt/ALT/" $TSV
        sed -i "s/mq/QUAL/" $TSV

        #need to add empty columns for FORMAT, INFO and FILTER (the remaining req columns for VCFs)
        awk 'BEGIN{ FS=OFS="\t" } {$6 = $6 FS (NR==1? "FORMAT" : "GT:AD:DP:GQ:PL") }1' $TSV > tmp && mv tmp $TSV

        awk 'BEGIN{ FS=OFS="\t" } {$6 = $6 FS (NR==1? "INFO" : ";") }1' $TSV > tmp && mv tmp $TSV

        awk 'BEGIN{ FS=OFS="\t" } {$6 = $6 FS (NR==1? "FILTER" : ".") }1' $TSV > tmp && mv tmp $TSV

        #sed -i '1s/^/<added text> /' $TSV
                #Run SigProfiler for single cells
        ml purge
        DEPENDENCIES+=( $(sbatch -c 2 --mem=32G -p cgawad --time=24:00:00 -e $STD_ERR_OUT_DIR/%A_${SAMPLE_NAME}_sigprofile_%x.err -o $STD_ERR_OUT_DIR/%A_${SAMPLE_NAME}_sigprofile_%x.out ${SCRIPT_DIR}/Scan2_SigProfiler.sh --project "${PROJECT}.tranche_${TRANCHE}" \
                        --tsv $TSV \
                        --script_dir ${SCRIPT_DIR} --results_dir ${SCRATCH_DIR} --project ${SAMPLE_NAME}) )
        #add tsv with sample name in columns to merged tsv (may want to only run annovar on this
        #think there's a problem with inserting sample into these columns, change back to 6 if this doesn't work
        awk -vsample="$SAMPLE_NAME" 'BEGIN{ FS=OFS="\t" } {$9 = $9 FS (NR==1? "SAMPLE" : sample) }1' $TSV > tmp
        if [ $count -eq 0 ]; then
            head -n 1 tmp >| $MERGED_TSV 
        fi
        sed '1d' tmp >> $MERGED_TSV
        rm tmp
        #now try to convert to vcf
        #first insert a hashtag in front of the column names
        sed '0,/CHROM/{s/CHROM/#CHROM/}' $TSV > temp.tsv
        #mv temp.tsv $TSV
        VCF="${TSV%.tsv}.vcf"
        #get a header from the original vcf
        grep '##' $GATK_VCF > temp
        grep -E "" temp.tsv >> temp
        mv temp $VCF	
        
        #sed '0,/CHROM/{s/CHROM/#CHROM/}' $MERGED_TSV > temp.tsv
                #mv temp.tsv $MERGED_TSV
                MERGED_VCF="${MERGED_TSV%.tsv}.vcf"
                


        #Now that we have VCF, attempt to make a merged version
        #try annotating lol
        ml java/1.8.0_131 perl/5.26.0 biology gatk/4.1.4.1 bedtools samtools/1.8 vcftools/0.1.15
        ANNOTATED_VCF="${VCF%.vcf}_annotated.vcf"
        ANNOTATED_TXT="${SAMPLE_NAME}_scan2_annotated.vcf.hg38_multianno.txt"
        echo annotated txt: $ANNOTATED_TXT
        echo vcf: $VCF
        echo annovar_dir: $ANNOVAR_DIR
        echo genomv ver: $GENOME_VERSION
        DEPENDENCIES+=( $(sbatch -c 4 -p cgawad --time=24:00:00 --mem=64G -o $STD_ERR_OUT_DIR/%A_annovar_${SAMPLE_NAME}_%x.out -e $STD_ERR_OUT_DIR/%A_annovar_${SAMPLE_NAME}_%x.err --job-name=${SAMPLE_NAME}_annovar --wrap="perl ${ANNOVAR_DIR}/table_annovar.pl $VCF -vcfinput -operation g,f,f,f,f,f,f \
                ${ANNOVAR_DIR}/humandb -buildver $GENOME_VERSION \
                -out $ANNOTATED_VCF -nastring . -remove -otherinfo \
                -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome") )

        mv $ANNOTATED_TXT $results
        echo count is $count
        count=$((count + 1))

        done

    sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_post_scan2_%x.err -o $STD_ERR_OUT_DIR/%A_post_scan2_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --job-name="step5" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step5 ${OPTIONS}"
fi


if [ $STEP -eq 5 ];then
     cd $SCRATCH_DIR/$SCAN2_RESULTS
        results="${SCRATCH_DIR}/${SCAN2_RESULTS}/results"
        mkdir -p $results
        MERGED_TSV="${SCRATCH_DIR}/01_all_cells_merged.tsv"
        count=0
        MERGED_VCF="${SCRATCH_DIR}/all_cells_merged.vcf"
    ml biology bcftools/1.8 samtools/1.8
    #changed this loop to loop over directories instead, this may break post scan2 but it was inconsistent before anyways
    for dir in $SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/*/; do
        SAMPLE_DIR=${dir%*/}
        SAMPLE_NAME=$(basename $SAMPLE_DIR)
        RDA="${SAMPLE_DIR}/scan2_object.rda"
        #SAMPLE_PATH="${SAMPLE_DIR}/${SAMPLE_NAME}"
        SAMPLE_PATH=${dir%/}
        ANNOTATED_TXT="${SAMPLE_DIR}/${SAMPLE_NAME}_scan2_annotated.vcf.hg38_multianno.txt"
        #want to either grep the lines from the annotated tsv OR merge the vcf files w/e we did in the other script
        TSV=${SAMPLE_PATH}_scan2.tsv	
        VCF="${TSV%.tsv}.vcf"
        ANNOTATED_VCF="${SAMPLE_DIR}/${SAMPLE_NAME}_scan2_annotated.vcf.hg38_multianno.vcf"
        if [ $count -eq 0 ]; then
            #this method of making the TSV may or may not work if contigs change from having diff ref file
            sed -n '1p' $ANNOTATED_TXT | sed -e "s/$/	Sample_Name/" > $MERGED_TSV
            tail -n +2 $ANNOTATED_TXT | sed -e "s/$/	${SAMPLE_NAME}/" >> $MERGED_TSV
        else
            tail -n +2 $ANNOTATED_TXT | sed -e "s/$/	${SAMPLE_NAME}/" >> $MERGED_TSV
        fi
            count=$((count + 1))
        echo merging annotated files, count is ${count}	
#		bcftools index $ANNOTATED_VCF
#        	bgzip -f $ANNOTATED_VCF
#        	tabix "${ANNOTATED_VCF}.gz"
#		bcftools index $ANNOTATED_VCF
        rsync -a ${ANNOTATED_TXT} $results/
            #grep the lines into a merged tsv file now; vcf merge is not working	
    done
    cd $results
#	MERGED_VCF=all_cells_merged_annotated.vcf
#	MERGED_TSV=all_cells_merged_annotated.tsv
#	bcftools merge --force-samples -o "$MERGED_VCF" \
#        	*_scan2_annotated.vcf.hg38_multianno.vcf.gz
#	grep "^[^##;]" $MERGED_VCF > $MERGED_TSV
#        sed '0,/#/{s/#//}' $MERGED_TSV > $MERGED_TSV

    cd $SCRATCH_DIR/$SCAN2_RESULTS/results
    
    #get the candidates, i think this should pull out clonal and non-clonal correctly 
    ## find sites with >1 sample called
    awk '$105 == "0/1" || $105 == "1/1"' $MERGED_TSV | cut -f1-5 | sort | uniq -c | awk '$1>1' | cut -c9- | sort > multiple_cells
     
    ## pull out calls with 1 sample called
    grep -vf multiple_cells $MERGED_TSV > 01_non_clonal_candidates.tsv

    ## find sites with >1 sample called
    awk '$105 == "0/1" || $105 == "1/1"' $MERGED_TSV | cut -f1-5 | sort | uniq -c | awk '$1>1' | cut -c9- | sort > multiple_cells

    ## pull out calls with >1 sample called
    grep -f multiple_cells $MERGED_TSV > 01_clonal_candidates.tsv
    
    pdfunite ./*SigProfiler_Results/SBS96/Suggested_Solution/COSMIC*/*pdf $SCRATCH_DIR/01_somatic_signatures.pdf
    mv 01_somatic_signatures.pdf ..
    
    files=( *mutburden.tsv )
    mutburdenfile="${files[${#files[@]}-1]}"
    sed -n '1p' $mutburdenfile | sed -e "s/^/Sample_Name	/" > all_mutburden.tsv 
    #grep -m1 "" $mutburdenfile > all_mutburden.tsv
    ls *mutburden.tsv | parallel 'sed -n "3p" {} | sed "s/^/{}\t/" ' >> all_mutburden.tsv
    head -n1 *mutburden.tsv | sort | uniq > head
    cat head all_mutburden.tsv > $results/01_all_mutburden.tsv

    cd $SCRATCH_DIR

    echo "### Analyzing Scan2 mutational rates and true positives ### - END: $(date)"
    
    echo "### Running deconstructSigs with Rscript ##: $(date)"
    ## load the conda env with deconstructsigs
    source /home/groups/cgawad/miniconda3/etc/profile.d/conda.sh

    conda deactivate

    conda activate scan2_sigs #<- use a conda env that is copied from update_scan2 and add the packages needed for deconstructsigs
    SIGS_OUTPUTS=$results/scan2_deconstructSigsOutputs
    mkdir -p $SIGS_OUTPUTS
    Rscript deconstructSigs.R $MERGED_TSV $SIGS_OUTPUTS 
    
    ## use pdfunite now to merge the graphs
    
    pdfunite $SIGS_OUTPUTS/mutsig_plot_bar* $results/01_individual_bar_signatures.pdf
    pdfunite $SIGS_OUTPUTS/mutsig_plot_stacked* $results/01_individual_stacked_signatures.pdf
    cp $SIGS_OUTPUTS/01_combined_stacked_mutsig_plot.pdf $results/01_combined_stacked_mutsig_plot.pdf
    
    sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_post_scan2_%x.err -o $STD_ERR_OUT_DIR/%A_post_scan2_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --job-name="step6" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step6 ${OPTIONS}"


fi


if [ $STEP -eq 6 ];then

    #doing same thing as above, but including rescued mutations
    cd $SCRATCH_DIR/$SCAN2_RESULTS
    results="${SCRATCH_DIR}/${SCAN2_RESULTS}/results"
    mkdir -p $results
    MERGED_TSV="${SCRATCH_DIR}/rescued_all_cells_merged.tsv"
    count=0
    MERGED_VCF="${SCRATCH_DIR}/rescued_all_cells_merged.vcf"
    for dir in $SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/*/; do
        #tsv_extract saves the dataframes in the R objects as TSVs
        SAMPLE_DIR=${dir%*/}
        SAMPLE_NAME=$(basename ${SAMPLE_DIR})
                RDA="${SAMPLE_DIR}/scan2_object.rda"
                SAMPLE_PATH=${dir%/}
        
        cd $SAMPLE_DIR

        #change header lines to correct formatting for VCF
        sed '0,/chr/{s/chr/CHROM/}' $TSV > temp.tsv
        mv temp.tsv $TSV	
        sed -i '0,/#CHROM/{s/#CHROM/CHROM/}' $TSV
        sed -i "s/pos/POS/" $TSV
        sed -i "s/dbsnp/ID/" $TSV
        sed -i "s/refnt/REF/" $TSV
        sed -i "s/altnt/ALT/" $TSV
        sed -i "s/mq/QUAL/" $TSV

        #need to add empty columns for FORMAT, INFO and FILTER (the remaining req columns for VCFs)
        awk 'BEGIN{ FS=OFS="\t" } {$6 = $6 FS (NR==1? "FORMAT" : "GT:AD:DP:GQ:PL") }1' $TSV > tmp && mv tmp $TSV

        awk 'BEGIN{ FS=OFS="\t" } {$6 = $6 FS (NR==1? "INFO" : ";") }1' $TSV > tmp && mv tmp $TSV

        awk 'BEGIN{ FS=OFS="\t" } {$6 = $6 FS (NR==1? "FILTER" : ".") }1' $TSV > tmp && mv tmp $TSV

        #sed -i '1s/^/<added text> /' $TSV
                #Run SigProfiler for single cells
        ml purge
        DEPENDENCIES+=( $(sbatch -c 2 --mem=32G -p cgawad --time=24:00:00 -e $STD_ERR_OUT_DIR/%A_${SAMPLE_NAME}_sigprofile_%x.err -o $STD_ERR_OUT_DIR/%A_${SAMPLE_NAME}_sigprofile_%x.out ${SCRIPT_DIR}/Scan2_SigProfiler.sh --project "${PROJECT}.tranche_${TRANCHE}" \
                        --tsv $TSV \
                        --script_dir ${SCRIPT_DIR} --results_dir ${SCRATCH_DIR} --project ${SAMPLE_NAME}) )
        #add tsv with sample name in columns to merged tsv (may want to only run annovar on this
        #think there's a problem with inserting sample into these columns, change back to 6 if this doesn't work
        awk -vsample="$SAMPLE_NAME" 'BEGIN{ FS=OFS="\t" } {$9 = $9 FS (NR==1? "SAMPLE" : sample) }1' $TSV > tmp
        if [ $count -eq 0 ]; then
            head -n 1 tmp >| $MERGED_TSV 
        fi
        sed '1d' tmp >> $MERGED_TSV
        rm tmp
        #now try to convert to vcf
        #first insert a hashtag in front of the column names
        sed '0,/CHROM/{s/CHROM/#CHROM/}' $TSV > temp.tsv
        #mv temp.tsv $TSV
        VCF="${TSV%.tsv}.vcf"
        #get a header from the original vcf
        grep '##' $GATK_VCF > temp
        grep -E "" temp.tsv >> temp
        mv temp $VCF	
        
        #sed '0,/CHROM/{s/CHROM/#CHROM/}' $MERGED_TSV > temp.tsv
                #mv temp.tsv $MERGED_TSV
                MERGED_VCF="${MERGED_TSV%.tsv}.vcf"
                


        #Now that we have VCF, attempt to make a merged version
        #try annotating lol
        ml java/1.8.0_131 perl/5.26.0 biology gatk/4.1.4.1 bedtools samtools/1.8 vcftools/0.1.15
        ANNOTATED_VCF="${VCF%.vcf}_annotated.vcf"
        ANNOTATED_TXT="${SAMPLE_NAME}_rescued_scan2_annotated.vcf.hg38_multianno.txt"
        echo annotated txt: $ANNOTATED_TXT
        echo vcf: $VCF
        echo annovar_dir: $ANNOVAR_DIR
        echo genomv ver: $GENOME_VERSION
        DEPENDENCIES+=( $(sbatch -c 4 -p cgawad --time=24:00:00 --mem=64G -o $STD_ERR_OUT_DIR/%A_annovar_${SAMPLE_NAME}_%x.out -e $STD_ERR_OUT_DIR/%A_annovar_${SAMPLE_NAME}_%x.err --job-name=${SAMPLE_NAME}_annovar --wrap="perl ${ANNOVAR_DIR}/table_annovar.pl $VCF -vcfinput -operation g,f,f,f,f,f,f \
                ${ANNOVAR_DIR}/humandb -buildver $GENOME_VERSION \
                -out $ANNOTATED_VCF -nastring . -remove -otherinfo \
                -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome") )

        mv $ANNOTATED_TXT $results
        echo count is $count
        count=$((count + 1))

        done
    


    sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_post_scan2_%x.err -o $STD_ERR_OUT_DIR/%A_post_scan2_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --job-name="step7" --wrap "sh $SCRIPT_DIR/3_scan2.sh --step7 ${OPTIONS}"
fi


if [ $STEP -eq 7 ];then
     cd $SCRATCH_DIR/$SCAN2_RESULTS
        results="${SCRATCH_DIR}/${SCAN2_RESULTS}/results"
        mkdir -p $results
        MERGED_TSV="${SCRATCH_DIR}/01_rescued_all_cells_merged.tsv"
        count=0
        MERGED_VCF="${SCRATCH_DIR}/rescued_all_cells_merged.vcf"
    ml biology bcftools/1.8 samtools/1.8
    for dir in $SCRATCH_DIR/$SCAN2_RESULTS/call_mutations/*/; do
        #tsv_extract saves the dataframes in the R objects as TSVs
                SAMPLE_DIR=${dir%*/}
                SAMPLE_NAME=$(basename ${SAMPLE_DIR})
                RDA="${SAMPLE_DIR}/scan2_object.rda"
                SAMPLE_PATH=${dir%/}

        ANNOTATED_TXT="${SAMPLE_DIR}/${SAMPLE_NAME}_rescued_scan2_annotated.vcf.hg38_multianno.txt"
        #want to either grep the lines from the annotated tsv OR merge the vcf files w/e we did in the other script
        TSV=${SAMPLE_PATH}_scan2.tsv	
        VCF="${TSV%.tsv}.vcf"
        ANNOTATED_VCF="${SAMPLE_DIR}/${SAMPLE_NAME}_rescued_scan2_annotated.vcf.hg38_multianno.vcf"
        if [ $count -eq 0 ]; then
            #this method of making the TSV may or may not work if contigs change from having diff ref file
            sed -n '1p' $ANNOTATED_TXT | sed -e "s/$/	Sample_Name/" > $MERGED_TSV
            tail -n +2 $ANNOTATED_TXT | sed -e "s/$/	${SAMPLE_NAME}/" >> $MERGED_TSV
        else
            tail -n +2 $ANNOTATED_TXT | sed -e "s/$/	${SAMPLE_NAME}/" >> $MERGED_TSV
        fi
            count=$((count + 1))
        echo merging annotated files, count is ${count}	
#		bcftools index $ANNOTATED_VCF
#        	bgzip -f $ANNOTATED_VCF
#        	tabix "${ANNOTATED_VCF}.gz"
#		bcftools index $ANNOTATED_VCF
        rsync -a ${ANNOTATED_TXT} $results/
            #grep the lines into a merged tsv file now; vcf merge is not working	
    done
    cd $results
#	MERGED_VCF=all_cells_merged_annotated.vcf
#	MERGED_TSV=all_cells_merged_annotated.tsv
#	bcftools merge --force-samples -o "$MERGED_VCF" \
#        	*_scan2_annotated.vcf.hg38_multianno.vcf.gz
#	grep "^[^##;]" $MERGED_VCF > $MERGED_TSV
#        sed '0,/#/{s/#//}' $MERGED_TSV > $MERGED_TSV

    cd $SCRATCH_DIR/$SCAN2_RESULTS/results
    
    #get the candidates, i think this should pull out clonal and non-clonal correctly 
    ## find sites with >1 sample called
    awk '$105 == "0/1" || $105 == "1/1"' $MERGED_TSV | cut -f1-5 | sort | uniq -c | awk '$1>1' | cut -c9- | sort > multiple_cells
     
    ## pull out calls with 1 sample called
    grep -vf multiple_cells $MERGED_TSV > 01_rescued_non_clonal_candidates.tsv

    ## find sites with >1 sample called
    awk '$105 == "0/1" || $105 == "1/1"' $MERGED_TSV | cut -f1-5 | sort | uniq -c | awk '$1>1' | cut -c9- | sort > multiple_cells

    ## pull out calls with >1 sample called
    grep -f multiple_cells $MERGED_TSV > 01_rescued_clonal_candidates.tsv
    
    pdfunite ./*SigProfiler_Results/SBS96/Suggested_Solution/COSMIC*/*pdf $SCRATCH_DIR/01_somatic_signatures.pdf
    mv 01_somatic_signatures.pdf ..

    echo "end of script"
    #for some reason copying over is not workin
    if [[ $EMAIL -eq 1 ]]; then
            # Email the user when the job is done if --email flag was set in submit_all
            echo "Scan2 job for ${PROJECT} has finished, with job name: ${SLURM_JOB_NAME}, start time: ${SLURM_JOB_START_TIME}, end time: ${SLURM_JOB_END_TIME}. Please see ${PROJECT} folders std_err_out folder for more details. " | mailx -s "Scan2 job for ${PROJECT}:${SLURM_JOB_ID} has finished" "${USER}@stanford.edu"
    fi

fi
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"