#!/bin/bash
#
#SBATCH --job-name=Scan2
#SBATCH --time=7-00:00:00
#SBATCH --partition=cgawad
#SBATCH --cpus-per-task=1 


START_TIME=$(date +%s)
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/"
#BAM_REGEX=".*.bam"
#BAM_SUFFIX=".bam"

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
#R SCRIPTS ASSOCIATED WITH SCAN2 WILL SUPER DUPER BREAK IF YOU DONT PUT .libPaths("/home/groups/cgawad/miniconda3/envs/update_scan2/lib/R/library")
#IN THEM, THIS IS ASSOCIATED WITH SOME PROBLEM WITH THE CONDA ENVIRONMENTS THAT I AM NOT SURE ABOUT, THIS WORKAROUND SHOULD FIX ERRORS AND THE SCRIPTS
#IN update_scan2 CONDA ENVIRONMENT ALREADY HAVE THIS LINE ADDED IN

#Default CROSS_SAMPLE_BAM folder
CROSS_SAMPLE_BAM="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/IG11_Methyl_Genome_Seq/211002_Methyl_WGS_Patent/Partial_Pipeline/Kindred"

GENOME_VERSION="hg38"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf"
SHAPEIT_DIR="${REFERENCE_DIR}"
#REGIONS_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_100_windows.txt"
REGIONS_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_n22chr.bed"
GOLD_STANDARD="/oak/stanford/groups/cgawad/Reference_Files/T1200_hg38_BAMs/T1200-1.bam"
#NORMAL_BAM_PATH="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/ANEU01_Bulk_WB_WES_Capt09_S26.realigned_deduped_sorted.bam"
SC_BAM="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/ANEU01_Bulk_EndovascularControl_WES_Capt09_S24.realigned_deduped_sorted.bam"
PANEL_OF_NORMAL="${REFERENCE_DIR}/1000g_pon.hg38.vcf.gz"
STEP=1
while [ "$1" != "" ]; do
    case $1 in
        --project )         shift
                            PROJECT=$1
                            ;;
        --results_dir )     shift
                            RESULTS_DIR=$1
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
	--std_err_out ) shift
			    STD_ERR_OUT_DIR=$1
			    ;;
	--step0 )           STEP=0
			    ;;
	--step1 )	    STEP=1
			    ;;
	--step2 ) 	    STEP=2	
			    ;;
	--step3 )	    STEP=3
			    ;;
	--step4 ) 	    STEP=4
			    ;;
    esac
    shift
done


#OPTIONS=()
#OPTIONS+=( "--project=$PROJECT" ) 
#OPTIONS+=( "--results_dir=$RESULTS_DIR" )
#OPTIONS+=( "--genome_ver=$GENOME_VERSION" )
#OPTIONS+=( "--script_dir=$SCRIPT_DIR" )
#OPTIONS+=( "--normal_path=$NORMAL_BAM_PATH" )
#OPTIONS+=( "--std_err_out=$STD_ERR_OUT" )
#OPTIONS+=( "--final_dir=$FINAL_DIR" )
#OPTIONS+=( "--sample_string=$SAMPLE_STRING" )
#OPTIONS+=( "--normal_name=$NORMAL_SAMPLE_NAME" )
#OPTIONS+=( "--cross_dir=$CROSS_SAMPLE_DIR" )
#if [ -n $SAMPLE_PREFIX ]; then
#    OPTIONS+=( "--sample_prefix=$SAMPLE_PREFIX" )
#fi
#echo OPTIONS ARE ${OPTIONS[*]}

OPTIONS="--project $PROJECT"
OPTIONS="${OPTIONS} --results_dir ${RESULTS_DIR}"
OPTIONS="${OPTIONS} --genome_ver $GENOME_VERSION"
OPTIONS="${OPTIONS} --script_dir $SCRIPT_DIR"
OPTIONS="${OPTIONS} --normal_path $NORMAL_BAM_PATH"
OPTIONS="${OPTIONS} --std_err_out $STD_ERR_OUT_DIR"
OPTIONS="${OPTIONS} --sample_string $SAMPLE_STRING"
OPTIONS="${OPTIONS} --normal_name $NORMAL_SAMPLE_NAME"
OPTIONS="${OPTIONS} --cross_dir $CROSS_SAMPLE_DIR"

SAMPLE_ARRAY=( $(echo ${SAMPLE_STRING} | sed 's/:/ /g') ) 
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE_NAME=${SAMPLE%.realigned_deduped_sorted.bam}

SCAN2_STATUS=${STD_ERR_OUT_DIR}/${PROJECT}_SCAN2_status.txt

CROSS_SAMPLE_PANEL=$RESULTS_DIR/$SCAN2_RESULTS/panel/panel.tab.gz
GATK_VCF=$RESULTS_DIR/$SCAN2_RESULTS/gatk/hc_raw.mmq60.vcf

ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

ml gsl/2.3
ml R/4.0.2 java perl biology gatk bedtools samtools
export R_LIBS="/home/groups/cgawad/R_libs"

ml biology gatk

echo "normal_sample is ${NORMAL_SAMPLE_NAME}"
echo "resutls_dir is ${RESULTS_DIR}"
echo "cross_dir is ${CROSS_SAMPLE_DIR}"

echo "ref fasta is ${REF_FASTA}"
echo "sampe is ${SAMPLE}"



cd $RESULTS_DIR


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

conda activate update_scan2


SCAN2_RESULTS="Scan2_Results_${PROJECT}_1_cell"

#if [ -n $(ls /oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/Scan2_Results_) ]; then
#fi

#if [ -d Scan2_Results_${SAMPLE} ]; then
#    echo "Folder exists, will validate and re-run any ended Scan2 processes with current configuration"
#    cd Scan2_Results_${SAMPLE}
#else

cd ${RESULTS_DIR}

NORMAL_BAM_PATH="${RESULTS_DIR}/${NORMAL_SAMPLE_NAME}.realigned_deduped_sorted.bam"

echo "normal sample is ${NORMAL_BAM_PATH}"

SC_BAMS=$(find $RESULTS_DIR -maxdepth 1 -name "TB_04_1678_1*.realigned_deduped_sorted.bam" ! -name "${NORMAL_BAM_PATH}")

echo "sc-bams is ${SC_BAMS}"

SCAN2_BAM_ARGS=""

for i in ${SC_BAMS[@]}; do
        echo "arg is ${i}"
        TEMP=${i/#/--sc-bam }
        SCAN2_BAM_ARGS="${SCAN2_BAM_ARGS} ${TEMP}"
done

echo $SCAN2_BAM_ARGS

#need to call variants from another donor to do proper indel calling
CROSS_BAMS=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "E8-1_S1*.bam" ! -name "*bulk*")

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

PIPELINE_DIR=/oak/stanford/groups/cgawad/Scripts/Sentieon_Pipeline_Under_Constr


echo "### Running Scan2 SAMPLE: $PROJECT  ### - START: $(date)" >> $SCAN2_STATUS


echo "### Running Sentieon SAMPLE: $PROJECT  ### - START: $(date)" >> $SCAN2_STATUS
#bash is being bash and idk why doing sentieon call as a seperate step doesn't work, may reimplement in the future
#
#if [ $STEP -eq 0 ]; then
#
#    if [ ! "$(ls -A "${SCAN2_RESULTS}")" ]; then	     
#	    echo "Folder does not exist. Will create folder and configure for Scan2 running"
#	    cd $RESULTS_DIR
#
#	    rm -R $SCAN2_RESULTS 
#
#	    scan2 -d "${SCAN2_RESULTS}" init
#    fi
#    DEPENDENCIES=( $(sbatch -e ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_%x.out $PIPELINE_DIR/1_cell_scan2_sentieon.sh --results-dir $RESULTS_DIR --sample-prefix $SAMPLE_PREFIX --normal-path $NORMAL_BAM_PATH --ref $REF_FASTA --dbsnp $DBSNP_VCF --scan2-results $SCAN2_RESULTS --regions-bed $REGIONS_BED --cross_dir $CROSS_SAMPLE_DIR --bam_args echo ${BAM_ARGS}) )
#
#	echo dependencies are ${DEPENDENCIES[-1]}
#	DEPENDENCIES="${DEPENDENCIES[-1]}"
#	echo dependencies are ${DEPENDENCIES}
#	echo "options about to be passed in to step1 is ${OPTIONS[@]}"
#
#	sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_step_1_%x.err -o $STD_ERR_OUT_DIR/%A_step_1_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --wrap "sh $PIPELINE_DIR/1_cell_scan2_submit.sh --step1 ${OPTIONS}"
#
#
#fi

if [ $STEP -eq 0 ]; then
	if [ ! "$(ls -A "${SCAN2_RESULTS}")" ]; then
		ml biology bwa samtools java
		module load biology sentieon/202112.01
		export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
		export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location



		ml system jemalloc/5.3.0
		export LD_PRELOAD=/share/software/user/open/jemalloc/5.3.0/lib/libjemalloc.so
		MALLOC_CONF=metadata_thp:auto,background_thread:true,dirty_decay_ms:30000,muzzy_decay_ms:30000
                    echo "Folder does not exist. Will create folder and configure for Scan2 running"
                    cd $RESULTS_DIR

                    rm -R $SCAN2_RESULTS

                    scan2 -d "${SCAN2_RESULTS}" init

               # DEPENDENCIES+=sbatch -e ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_%x.out $PIPELINE_DIR/1_cell_scan2_sentieon_mmq1.sh --results-dir $RESULTS_DIR --sample-prefix $SAMPLE_PREFIX --normal-path $NORMAL_BAM_PATH --ref $REF_FASTA --dbsnp $DBSNP_VCF --scan2-results $SCAN2_RESULTS --regions-bed $REGIONS_BED --cross_dir $CROSS_SAMPLE_DIR --bam_args echo ${BAM_ARGS}

		DEPENDENCIES+=sbatch -e ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_mmq1_%x.err -o ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_mmq1_%x.out --time=7-00:00:00 --partition=cgawad --nodes=1 --cpus-per-task=24 --mem=64G --wrap "export bwt_max_mem=128G \ export LD_PRELOAD=/share/software/user/open/jemalloc/5.3.0/lib/libjemalloc.so \ sentieon driver \ --interval $REGIONS_BED \ -r $REF_FASTA \ ${BAM_ARGS} \ --algo Haplotyper --trim_soft_clip --dbsnp $DBSNP_VCF --min_map_qual 1 "${RESULTS_DIR}/${SCAN2_RESULTS}/gatk/hc_raw.mmq1.vcf"" 
        	DEPENDENCIES+=sbatch -e ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_mmq60_%x.err -o ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_mmq60_%x.out --time=7-00:00:00 --partition=cgawad --nodes=1 --cpus-per-task=24 --mem=64G --wrap "export bwt_max_mem=128G \
         export LD_PRELOAD=/share/software/user/open/jemalloc/5.3.0/lib/libjemalloc.so \
	sentieon driver \
        --interval $REGIONS_BED \
        -r $REF_FASTA \
         ${BAM_ARGS} \
        --algo Haplotyper --trim_soft_clip --dbsnp $DBSNP_VCF --min_map_qual 60 "${RESULTS_DIR}/${SCAN2_RESULTS}/gatk/hc_raw.mmq60.vcf""
	fi
	if [ ! -z $( IFS=$':'; echo "${DEPENDENCIES[*]}" ) ]; then
	sbatch --dependency=afterany:$( IFS=$':'; echo "${DEPENDENCIES[*]}" ) --partition=cgawad -e $STD_ERR_OUT_DIR/%A_make_panel_%x.err -o $STD_ERR_OUT_DIR/%A_make_panel_%x.out --time=5-00:00:00 --wrap "sh $PIPELINE_DIR/1_cell_scan2_submit.sh --step1 ${OPTIONS}"
	fi
fi


if [ $STEP -eq 1 ]; then
	
	if [ ! "$(ls -A "${SCAN2_RESULTS}")" ]; then
		    echo "Folder does not exist. Will create folder and configure for Scan2 running"
		    cd $RESULTS_DIR

		    rm -R $SCAN2_RESULTS

		    scan2 -d "${SCAN2_RESULTS}" init
	
		sbatch --wait -e ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_sentieon_scan2_%x.out $PIPELINE_DIR/1_cell_scan2_sentieon.sh --results-dir $RESULTS_DIR --sample-prefix $SAMPLE_PREFIX --normal-path $NORMAL_BAM_PATH --ref $REF_FASTA --dbsnp $DBSNP_VCF --scan2-results $SCAN2_RESULTS --regions-bed $REGIONS_BED --cross_dir $CROSS_SAMPLE_DIR --bam_args echo ${BAM_ARGS}
	fi
	
	scan2 -d "${SCAN2_RESULTS}" init
	
	#Pretty sure need to make panel first as they do in demo

	#making the metadata.csv

	BAM_NAMES=$(find $RESULTS_DIR -maxdepth 1 -name "TB_04_1678_1*.realigned_deduped_sorted.bam" ! -name "${NORMAL_SAMPLE_NAME}*" -exec basename {} \;)

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
	CROSS_BAM_NAMES=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "E8-1_S1*.bam" ! -name "*bulk*" -exec basename {} \;)

	for i in ${CROSS_BAM_NAMES}; do
		echo "d2,${i%.bqsr.marked.bam},SC" >> cross.csv
	done

	grep -vwE "bulk" cross.csv >> metadata.csv

	bulk=$(find $CROSS_SAMPLE_DIR -maxdepth 1 -name "bulk*.bam" ! -exec basename {} \;)

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

	#sbatch --wait --cpus-per-task=4 --mem=32G -p cgawad -e ${STD_ERR_OUT_DIR}/%A_make_panel_scan2_%x.err -o ${STD_ERR_OUT_DIR}/%A_make_panel_scan2_%x.out $PIPELINE_DIR/scan2_sentieon.sh --results-dir $RESULTS_DIR --normal-path $NORMAL_BAM_PATH --ref $REF_FASTA --dbsnp $DBSNP_VCF --scan2-results $SCAN2_RESULTS --scan2-bam-args $SCAN2_BAM_ARGS --scan2-results $SCAN2_RESULTS

	    scan2 config \
		--analysis makepanel \
		--ref $REF_FASTA \
		--verbose \
		--genome 'hg38' \
		--dbsnp $DBSNP_VCF \
		--bulk-bam $NORMAL_BAM_PATH \
		--regions-file $REGIONS_BED \
		--eagle-refpanel "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/eagle_1000g_panel" \
		--eagle-genmap "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/genetic_map_hg38_withX.txt.gz" \
		--phaser "eagle" \
		--gatk "gatk3_joint" \
		--makepanel-metadata metadata.csv \
		$SCAN2_ARGS

	scan2 validate

#uncomment after testing mustig rescue
DEPENDENCIES=( $(sbatch --time=5-00:00:00 -p cgawad scan2 run --joblimit 95 --snakemake-args " --keep-going --max-status-checks-per-second 0.1" --cluster 'sbatch -p cgawad -c {threads} --mem={resources.mem}  -t 7-00:00:00 -o %logdir/slurm-%A.log') )
	echo dependencies are ${DEPENDENCIES[-1]}
	DEPENDENCIES="${DEPENDENCIES[-1]}"
	echo dependencies are ${DEPENDENCIES}
	echo "options about to be passed in to step2 is ${OPTIONS[@]}"



	sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_make_panel_%x.err -o $STD_ERR_OUT_DIR/%A_make_panel_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --wrap "sh $PIPELINE_DIR/1_cell_scan2_submit.sh --step2 ${OPTIONS}"

fi

#--eagle-refpanel "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/eagle_1000g_panel" \
#--eagle-genmap "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/genetic_map_hg38_withX.txt.gz" \
#--phaser "eagle" \

#--snakemake-args '--jobs 96' --cluster 'sbatch -p cgawad -c 1 --mem=8G  -t 5-00:00:00 -o %logdir/slurm-%A.log'

#--regions-file $REGIONS_BED \
#--regions 22:10000000-10999999,22:11000000-11999999 \
#########UNCOMMENT END #####


#TODO: Making the cross sample panel is EXTREMELY time consuming, we should construct 1 cross sample panel for use in as many things as possible and then add option to specify cross sample panel, which will just copy the specified reference panel into the $CROSS_SAMPLE_PANEL directory below so that scan2 can use it, this option should skip makepanel altogether but still do sentieon variant calling, just with nothing inserted for the cross_sample directory

CROSS_SAMPLE_PANEL=$RESULTS_DIR/$SCAN2_RESULTS/panel/panel.tab.gz
GATK_VCF=$RESULTS_DIR/$SCAN2_RESULTS/gatk/hc_raw.mmq60.vcf



#Pretty sure if want to use gatk-vcf on a sentieon output will need to use "bcftools annotate" to add in header info
#included in Scan2 output vcf but not in sentieon output vcf              
#Try the following commands # do not replace TAG if already present




if [ $STEP -eq 2 ]; then

echo "### Running call_mutations SAMPLE: $SAMPLE_NAME Time: $(date) ###" >> $SCAN2_STATUS

    cd $SCAN2_RESULTS


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
	--regions-file $REGIONS_BED \
	--gatk-vcf $GATK_VCF \
	--cross-sample-panel $CROSS_SAMPLE_PANEL \
	$SCAN2_BAM_ARGS 

	scan2 validate

#uncomment this after testing mutrescue

	DEPENDENCIES=( $(sbatch --time=5-00:00:00 -p cgawad scan2 run --joblimit 95 --snakemake-args " --keep-going --max-status-checks-per-second 0.1" --cluster 'sbatch -p cgawad -c {threads} --mem={resources.mem} -t 7-00:00:00 -o %logdir/slurm-%A.log') )
#
#
     echo "Scan2 configured"
		
	echo options about to be passed in to step3 is ${OPTIONS[*]}
	
	echo -e "sbatch --dependency=afterany:$( echo "${DEPENDENCIES}" ) -J $PROJECT \
			 $PIPELINE_DIR/1_cell_scan2_submit.sh --step3 ${OPTIONS[@]}
	fi"

	DEPENDENCIES="${DEPENDENCIES[-1]}"

	sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_mutsig_rescue_%x.err -o $STD_ERR_OUT_DIR/%A_mutsig_rescue_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --wrap "sh $PIPELINE_DIR/1_cell_scan2_submit.sh --step3 ${OPTIONS}"

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
#	checkpoint="$RESULTS_DIR/$SCAN2_RESULTS/call_mutations/*.realigned_deduped_sorted.bam/scan2_object.rda"
#	read -t 5 
#done
#echo "callmutations finished"

if [ $STEP -eq 3 ];then

	BAM_NAMES=$(find $RESULTS_DIR -maxdepth 1 -name "TB_04_1678_1*.realigned_deduped_sorted.bam" ! -name "${NORMAL_SAMPLE_NAME}*" -exec basename {} \;)

	SCAN2_RESCUE_ARGS=""

	for i in ${BAM_NAMES}; do
		echo "arg is ${i}"
		SAMPLE=$i
		if [ ${SAMPLE%.realigned_deduped_sorted.bam} != ${NORMAL_SAMPLE_NAME} ]; then
			RDA="$RESULTS_DIR/$SCAN2_RESULTS/call_mutations/${SAMPLE%.realigned_deduped_sorted.bam}/scan2_object.rda"
			TEMP=${i/#/--scan2-object }
			SCAN2_RESCUE_ARGS="${SCAN2_RESCUE_ARGS} ${TEMP} ${RDA}"
		fi
	done

	echo $SCAN2_RESCUE_ARGS

	cd $SCAN2_RESULTS
	scan2 config \
		--verbose \
		--analysis rescue \
		--rescue-target-fdr 0.01 \
		${SCAN2_RESCUE_ARGS}

	scan2 validate

	DEPENDENCIES+=( $(sbatch --time=5-00:00:00 -p cgawad scan2 rescue --joblimit 20 --snakemake-args " --keep-going --max-status-checks-per-second 0.1" --cluster 'sbatch -p cgawad -c {threads} --mem={resources.mem}  -t 7-00:00:00 -o %logdir/slurm-%A.log') )
	DEPENDENCIES="${DEPENDENCIES[-1]}"
	
	echo options about to be passed in to step4 is ${OPTIONS[*]}
	
	echo -e "sbatch --dependency=afterany:$( echo "${DEPENDENCIES}" ) -J $PROJECT \
			 $PIPELINE_DIR/1_cell_scan2_submit.sh --step4 ${OPTIONS[@]}
	fi"


     
	sbatch --partition=cgawad -e $STD_ERR_OUT_DIR/%A_post_scan2_%x.err -o $STD_ERR_OUT_DIR/%A_post_scan2_%x.out --time=5-00:00:00 --dependency=afterany:$( echo "${DEPENDENCIES}" ) --wrap "sh $PIPELINE_DIR/1_cell_scan2_submit.sh --step4 ${OPTIONS}"
	


fi

if [ $STEP -eq 4 ];then

	cd $RESULTS_DIR/$SCAN2_RESULTS
	for i in ${BAM_NAMES}; do
        #need to make an R script that pulls results csvs from these files and saves them as .tsv
                SAMPLE_NAME=${i%.realigned_deduped_sorted.bam}
                RDA="$RESULTS_DIR/$SCAN2_RESULTS/call_mutations/${SAMPLE_NAME}/scan2_object.rda"
                SAMPLE_PATH="$RESULTS_DIR/$SCAN2_RESULTS/call_mutations/${SAMPLE_NAME}/${SAMPLE_NAME}"
		echo "Running Scan2_tsv_extract.R now"
                Rscript ${SCRIPT_DIR}/Scan2_tsv_extract.R $RDA $SAMPLE_PATH

                TSV=${SAMPLE_PATH}_scan2.tsv

                sed -i "s/#CHROM/CHROM/" $TSV

                srun -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
                        ${SCRIPT_DIR}/SigProfiler.sh --project "${PROJECT}.tranche_${TRANCHE}" \
                        --tsv $TSV \
                        --script_dir ${SCRIPT_DIR} --results_dir ${RESULTS_DIR} --project ${PROJECT}

        done

	#uncomment after testing mutsig rescue
#	for i in ${BAM_NAMES}; do
#		SAMPLE=$i
#		RDA="$RESULTS_DIR/$SCAN2_RESULTS/call_mutations/${SAMPLE%.realigned_deduped_sorted.bam}/scan2_object.rda"
#		echo ${RDA}
#		if [ ! -f $RDA ]; then
#		echo "RDA file does not exist. Exiting with code 1"
#		exit 1
#		fi
#		Rscript ${SCRIPT_DIR}/Scan2_germline_control.R $RDA somatic_${SAMPLE}.csv germline_${SAMPLE}.csv
#		echo "True positive germline and somatic variants obtained"
#		REGIONS="${SAMPLE_DIR}/callable_regions/${SAMPLE}/summary.chunk*.bulk_intersect.rda"
#		Rscript ${SCRIPT_DIR}/Scan2_get_callable_bases.R callable_${SAMPLE}.csv $REGIONS
#		echo "Callable bases obtained"
#		Rscript ${SCRIPT_DIR}/Scan2_mutburden.R somatic_${SAMPLE}.csv germline_${SAMPLE}.csv callable_${SAMPLE}.csv burden_${SAMPLE}.csv
#		echo "Mutation burden analyzed"
#		head -n 1 germline_${SAMPLE}.csv | sed "s/chr/CHROM/" | sed "s/pos/POS/" | sed "s/refnt/REF/" | sed "s/altnt/ALT/" | tr ',' '\t' > ${RESULTS_DIR}/germline_${SAMPLE}.tsv
#		tail -n +2 germline_${SAMPLE}.csv | tr ',' '\t' >> ${RESULTS_DIR}/germline_${SAMPLE}.tsv
#		echo "Germline true positives formatted for SigProfiler script"
#		head -n 1 somatic_${SAMPLE}.csv | sed "s/chr/CHROM/" | sed "s/pos/POS/" | sed "s/refnt/REF/" | sed "s/altnt/ALT/" | tr ',' '\t' > ${RESULTS_DIR}/somatic_${SAMPLE}.tsv
#		tail -n +2 somatic_${SAMPLE}.csv | tr ',' '\t' >> ${RESULTS_DIR}/somatic_${SAMPLE}.tsv
#		echo "Somatic true positives formatted for SigProfiler script"
#		# cd $RESULTS_DIR
#		# rm -r Scan2_Results_${SAMPLE}
#
#	done
	#
		echo "### Analyzing Scan2 mutational rates and true positives ### - END: $(date)"

	# echo "### Computing mutational signature with SigProfiler ### - START: $(date)"
	# srun ${SCRIPT_DIR}/SigProfiler.sh --project $PROJECT \
	#     --script_dir $SCRIPT_DIR --results_dir $RESULTS_DIR \
	#     --tsv germline_${SAMPLE}.tsv \
	#     ${OPTIONS[@]}
	# echo "Germline true positives mutational signatures done"
	# srun ${SCRIPT_DIR}/SigProfiler.sh --project $PROJECT \
	#     --script_dir $SCRIPT_DIR --results_dir $RESULTS_DIR \
	#     --tsv somatic_${SAMPLE}.tsv \
	#     ${OPTIONS[@]}
	# echo "Somatic true positives mutational signatures done"
	# echo "### Computing mutational signature with SigProfiler ### - END: $(date)"

	rm -rf $SCRATCH/$PROJECT/tmp*
	echo results directory is $RESULTS_DIR
	echo final directory is $FINAL_DIR
	 
	rsync -a $SCRATCH/$PROJECT $FINAL_DIR/
	 
	 

	echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
fi
#### OLD CODE ####

####METHOD TO GET MULTIPLE SC-BAMS TO INPUT INTO SCAN2

#cd ${RESULTS_DIR}
#
#SC_BAMS=$(find $RESULTS_DIR -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" ! -name "${NORMAL_BAM_PATH})
#
#echo "sc-bams is ${SC_BAMS}"
#
#SCAN2_BAM_ARGS=""
#
#for i in ${SC_BAMS[@]}; do
#        echo "arg is ${i}"
#        TEMP=${i/#/--sc-bam }
#        SCAN2_BAM_ARGS="${SCAN2_BAM_ARGS} ${TEMP}"
#done
#
####METHOD ENDS#####


#    scan2 config \
#	--gatk "gatk3_joint"
#        --dbsnp $DBSNP_VCF \
#        --shapeit-refpanel $SHAPEIT_DIR \
#	--ref $REF_FASTA \
#        --verbose \
#        --dbsnp $DBSNP_VCF \
#        --abmodel-chunks=4 \
#        --abmodel-samples-per-chunk=5000 \
#        --abmodel-steps=4 \
#        --callable-regions True \
#        --score-all-sites \
#        --regions-file $REGIONS_BED \
#        --bulk-bam $NORMAL_BAM_PATH \
# 	--sc-bam $SC_BAM
#    echo "Scan2 configured"


#	--gatk "gatk3_joint" \


#GATK_VCF="${RESULTS_DIR}/ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25_mmq60_variant.vcf"
#SSCAN2_REF_VCF="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/Scan2_Reference/Scan2_Results_/gatk/hc_raw.mmq60.vcf"
#
##need to bgzip the vcf files first, also should make a scan2_ref_vcf for all regions not just chr 22
##may or may not need to uncompress files after annotating
#
#bgzip $GATK_VCF
#tabix ${GATK_VCF}.gz
#bgzip $SCAN2_REF_VCF
#tabix ${SCAN2_REF_VCF}.gz
#
#GATK_VCF="${RESULTS_DIR}/ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25_mmq60_variant.vcf.gz"
#SCAN2_REF_VCF="/oak/stanford/groups/cgawad/Nonmalignant_Tissue/Seizure_EEG_Probes/220628_EEG_Probe_Deep_Exome/2022-06-30_EEG_project_Results/Scan2_Reference/Scan2_Results_/gatk/hc_raw.mmq60.vcf.gz"
#
#bcftools annotate -a "${SCAN2_REF_VCF}" -c ID,QUAL,+TAG "${GATK_VCF}"
##
## overwrite existing TAG annotations
#bcftools annotate -a "${SCAN2_REF_VCF}" -c ID,QUAL,TAG "${GATK_VCF}"
#
#Carry over all INFO and FORMAT annotations except FORMAT/GT
#
#bcftools annotate -a "${SCAN2_REF_VCF}" -c INFO,^FORMAT/GT "${GATK_VCF}"
#

###bcftools annotate didn't work, but I forget if i used a panel file ran through scan2 with all regions,

#gunzip $GATK_VCF
#gunzip $SCAN2_REF_VCF


#OLD_GATK_VCF="${RESULTS_DIR}/ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25_mmq60_variant.vcf"

#echo "For re-running this job:"
#echo "sbatch --dependency=afterany:${SLURM_JOB_ID} \
#    -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
#    --array=1-${JOB_COUNT} ${SCRIPT_DIR}/Scan2.sh \
#    --script_dir $SCRIPT_DIR --bam_dir $BAM_DIR \
#    --bam_suffix $BAM_SUFFIX --bam_regex $BAM_REGEX \
#    --project $PROJECT --bulk $BULK --genome_version $GENOME_VERSION  \
#    --std_err_out $STD_ERR_OUT_DIR --results_dir $RESULTS_DIR"
