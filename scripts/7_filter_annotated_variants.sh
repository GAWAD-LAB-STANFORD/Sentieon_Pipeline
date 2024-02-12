#!/bin/bash

#SBATCH --job-name=7_filter_annotated_variants
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=200G

# i split up the files to test if splitting up the scripts would fix a problem where multianno tsv file was truncated,
#   but i just realized that it probably shouldn't solve the problem
# Will keep this for testing anyways because this breakdown of the scripts is a lot better,
#   if we can get things to work usuing this it will be preferable

PYTHON_LIBS="/home/groups/cgawad/python_libs/bin"
PYTHON_LIBS_SITE_PACKAGES="/home/groups/cgawad/python_libs/lib/python3.6/site-packages"
START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --project )                     shift
                                        PROJECT=$1
                                        ;;
        --results_dir )                 shift
                                        RESULTS_DIR=$1
                                        ;;
        --pipeline_dir )                shift
                                        PIPELINE_DIR=$1
                                        ;;
        --std_err_out_dir )             shift
                                        STD_ERR_OUT_DIR=$1
                                        ;;
        --exome )                       shift
                                        EXOME=$1
                                        ;;
        --python_libs )                 shift
                                        PYTHON_LIBS=$1
                                        ;;
        --python_libs_site_packages )   shift
                                        PYTHON_LIBS_SITE_PACKAGES=$1
                                        ;;
    esac
    shift
done

if [ -z $PROJECT ] || [ -z $RESULTS_DIR ] || [ -z $PIPELINE_DIR ] || [ -z $STD_ERR_OUT_DIR ] || \
    [ -z $EXOME ]; then
    echo "Variables not supplied correctly. Check script for intake parameters. All are required to be specified. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"
cd $RESULTS_DIR

echo "### Annotating SNPs and Indels ###: $(date)"
ml purge
ml gsl/2.3
ml java/1.8.0_131 perl/5.26.0 biology gatk/4.1.4.1 bedtools/2.27.1 samtools/1.8 vcftools/0.1.15
#export R_LIBS="/home/groups/cgawad/R_libs"
ml python/3.6.1 system ghostscript/9.53.2
ml math py-numpy/1.19.2_py36 py-pandas/1.0.3_py36
export PATH=${PYTHON_LIBS}:$PATH
export PYTHONPATH=${PYTHON_LIBS_SITE_PACKAGES}:$PYTHONPATH

echo DEBUG: 6_filter_annotated_variants.sh, printing modules on next line
module list

##### filter for final somatic calls

###functions###

make_unique_col_names(){
    #takes a *text file* with the header and replaces
    #all non-unique occurences of a word with
    #a unique version
    file=$1
    header=$( (head -n 1 $file) )
    
    
}

#i was lazy here and only implemented fixing the header having AF appear twice, in future can make this extensible by making a function which takes an input string for the column and iteratively changes all instances of that input string with a unique one with a number appended

snp_header=$( (head -n 1 ${PROJECT}_svc_merged_extract_snp.hg38_multianno.tsv ) )
updated_snp_header=$( (echo $snp_header | sed 's/AF/AF_first/' | sed "s/#CHROM/CHROM/" | sed 's/ /\t/g') )
sed -i "1s/.*/$updated_snp_header/" ${PROJECT}_svc_merged_extract_snp.hg38_multianno.tsv 

#try removing problematic lines using grep

grep -v ":${NORMAL_SAMPLE_NAME}" ${PROJECT}_svc_merged_extract_snp.hg38_multianno.tsv > ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv


### Pull out sites from somatic file with 10 reads and AF>0.4
VAF_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv AF) )
DP_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv AFDP) )

head -n 1 ${PROJECT}_svc_merged_extract_snp.hg38_multianno.tsv > fixed_header.txt
 

echo VAF col number is ${VAF_COL_NUM}

#old column numbers left here for reference
#awk '$126>0.4 && $127>9' *_svc_merged_extract_snp.hg38_multianno.tsv | cut -f1-5  | sort > candidates

awk -v VAF="$VAF_COL_NUM" -v DP="$DP_COL_NUM" '$VAF>0.4 && $DP>9' ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv | cut -f1-5  | sort > candidates



ulimit -a 

#trying to make this less memory intensive for >50G joint germline files
#while IFS= read -r line; do
#	#check if the candidate has already been scanned before performing grep
#    printf '%s\t' "Reading this line: $line" 
#	printf '%s\t' $line > line
#	if  grep -f line test_seen_candidates; then
#		echo Already scanned line
#	else
#		echo Appending new candidate
#		cat line >> test_seen_candidates
#	fi 
#done < candidates

uniq candidates > unique_candidates

fgrep -f unique_candidates ${PROJECT}_joint_germline_merged_extract_snp.hg38_multianno.tsv > 01_all_snv_variants.tsv 

##old way of greping from previous pipeline
#grep -f candidates *_joint_germline_merged_extract_snp.hg38_multianno.tsv > 01_all_snv_variants.tsv

head -n 1 ${PROJECT}_joint_germline_merged_extract_snp.hg38_multianno.tsv > 01_all_somatic_snvs_head.tsv
cat 01_all_somatic_snvs_head.tsv 01_all_snv_variants.tsv > 01_all_somatic_snvs.tsv


GT_COL_NUM=$( ($PIPELINE_DIR/colnum.sh 01_all_somatic_snvs.tsv GT) )
## find sites with >1 sample called
awk -v GT="$GT_COL_NUM" '$GT == "0/1" || $GT == "1/1"' 01_all_somatic_snvs.tsv | cut -f1-5 | sort | uniq -c | awk '$1>1' | cut -c9- | sort > multiple_cells

## pull out calls with >1 sample called
grep -f multiple_cells 01_all_snv_variants.tsv > candidates.tsv

## get the following column names and what number they are bc every time columns get inserted they shift
AD_COLNUM=$( ($PIPELINE_DIR/colnum.sh 01_all_somatic_snvs.tsv AD) )
DP_COLNUM=$( ($PIPELINE_DIR/colnum.sh 01_all_somatic_snvs.tsv DP) )

## THIS IS NOT A GOOD WAY OF DOING THINGS
# you really don't want to be selecting columns by the number instead of a header, i don't have 
# time to fix this right now but at some point in the future change all of these to use a 
# column name instead of column number 

#First number is supposed to be AD, second number is supposed to be DP
# the division equality (124) is a new column in the 124th slot with the VAF
# the next number (125) is a combination of the first 5 columnst o create a unique identifier
## calculate allele frequency for each call
awk '{gsub(",","\t",$122)}1' candidates.tsv | sed 's/ /\t/g' | awk '{gsub("0","0.000001",$123)}1' | sed 's/ /\t/g' | awk '$124=$123/($122+$123)' | sed 's/ /\t/g' | awk '$125 = $1"_"$2"_"$3"_"$4"_"$5' | sed 's/ /\t/g'  > all_variants_AF.tsv

# 126 is the GT column, the next awk statement counts the number of unique identifiers 
## calculate average allele frequency by location and base change
awk '$126 == "0/1" || $126 == "1/1"' all_variants_AF.tsv | sed 's/ /\t/g' | awk '{seen[$125]+=$124; count[$125]++} END{for (x in seen)print x, seen[x]/count[x]}' | sed 's/ /\t/g' > clonal_calls_pre.tsv

## keep calls with average AF > 0.4 in called cells
awk '$2 > 0.4' clonal_calls_pre.tsv | cut -f1 | sed 's/_/\t/g' > final_sites

## pull out those sites and keep GATK pass
grep -f final_sites *_joint_germline_merged_extract_snp.hg38_multianno.tsv | grep PASS > final_clonal_somatic_calls_pre.tsv

## add back header
head -n1 *_joint_germline_merged_extract_snp.hg38_multianno.tsv > header
cat header final_clonal_somatic_calls_pre.tsv >  01_final_clonal_somatic_snvs.tsv
cat 01_final_clonal_somatic_snvs.tsv > no_black_list_clonal_snvs.tsv

## remove mutations from blacklist
#looks like this black listing thing is completley broken 
input_file="01_final_clonal_somatic_snvs.tsv"
filter_file=$BLACK_LIST
while IFS= read -r value
do
  if [[ ! -z "$value" ]]; then
      awk -v filter_value="$value" '!(($49 ~ ("^" filter_value)))' "$input_file" > tmp_snvs.txt
        fi
        done < "$filter_file"
mv tmp_snvs.txt 01_black_listed_final_clonal_somatic_snvs.tsv

##### filter for final indel somatic calls
### Pull out sites from somatic file with 10 reads and AF>0.4

indel_header=$( (head -n 1 ${PROJECT}_svc_merged_extract_indel.hg38_multianno.tsv ) )
updated_indel_header=$( (echo $indel_header | sed 's/AF/AF_first/' | sed "s/#CHROM/CHROM/" | sed 's/ /\t/g') )
sed -i "1s/.*/$updated_indel_header/" ${PROJECT}_svc_merged_extract_indel.hg38_multianno.tsv 

grep -v ":${NORMAL_SAMPLE_NAME}" ${PROJECT}_svc_merged_extract_indel.hg38_multianno.tsv > ${PROJECT}_svc_merged_extract_indel.hg38_multianno.no_germline.tsv

INDEL_VAF_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_svc_merged_extract_indel.hg38_multianno.no_germline.tsv AF) ) 
INDEL_DP_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_svc_merged_extract_indel.hg38_multianno.no_germline.tsv AFDP) ) 

awk -v DP="$INDEL_DP_COL_NUM" -v VAF="$INDEL_VAF_COL_NUM" '$VAF>0.4 && $DP>9' ${PROJECT}_svc_merged_extract_indel.hg38_multianno.no_germline.tsv | cut -f1-5  | sort > indel_candidates

## pull Mutect calls out of GATK file

uniq indel_candidates > unique_indel_candidates
fgrep -f unique_indel_candidates ${PROJECT}_joint_germline_merged_extract_indel.hg38_multianno.tsv > all_indel_variants.tsv 

>01_all_somatic_indels.tsv
head -n 1 ${PROJECT}_joint_germline_merged_extract_indel.hg38_multianno.tsv > 01_all_somatic_indels.tsv
cat all_indel_variants.tsv >> 01_all_somatic_indels.tsv

## find sites with >1 sample called
awk '$120 == "0/1" || $120 == "1/1"' all_indel_variants.tsv | cut -f1-5 | sort | uniq -c | awk '$1>1' | cut -c9- | sort > multiple_indel_cells
## pull out calls with >1 sample called
##DP FOR INDELS IS col 112, but for SNPs its 117, 
grep -f multiple_indel_cells all_indel_variants.tsv > indel_candidates.tsv
## calculate allele frequency for each call, 
## SNPS: 117=AD, 118=DP, 119=GQ
##INDELS: 117=AD, 118=DP, 119=GQ

#old column numbers kept here for reference
## awk '{gsub(",","\t",$116)}1' candidates.tsv | sed 's/ /\t/g' | awk '{gsub("0","0.000001",$117)}1' | sed 's/ /\t/g' | awk '$118=$117/($116+$117)' | sed 's/ /\t/g' | awk '$123 = $1"_"$2"_"$3"_"$4"_"$5' | sed 's/ /\t/g'  > all_variants_AF.tsv 
awk '{gsub(",","\t",$117)}1' indel_candidates.tsv | sed 's/ /\t/g' | awk '{gsub("0","0.000001",$118)}1' | sed 's/ /\t/g' | awk '$119=$118/($117+$118)' | sed 's/ /\t/g' | awk '$124 = $1"_"$2"_"$3"_"$4"_"$5' | sed 's/ /\t/g'  > all_indels_AF.tsv

## calculate average allele frequency by location and base change
awk '$121 == "0/1" || $121 == "1/1"' all_indels_AF.tsv | sed 's/ /\t/g' | awk '{seen[$124]+=$119; count[$124]++} END{for (x in seen)print x, seen[x]/count[x]}' | sed 's/ /\t/g' > clonal_indel_calls_pre.tsv
## keep calls with average AF > 0.4 in called cells
awk '$2 > 0.4' clonal_indel_calls_pre.tsv | cut -f1 | sed 's/_/\t/g' > final_indel_sites
## pull out those sites and keep GATK pass
## There's no PASS in the file? did VQSR not get performed on it?
#grep -f final_indel_sites *_joint_germline_merged_extract_indel.hg38_multianno.tsv | grep PASS > final_clonal_indel_calls_pre.tsv
grep -f final_indel_sites ${PROJECT}_joint_germline_merged_extract_indel.hg38_multianno.tsv > final_clonal_indel_calls_pre.tsv
## add back header
head -n1 ${PROJECT}_joint_germline_merged_extract_indel.hg38_multianno.tsv > indel_header
cat indel_header final_clonal_indel_calls_pre.tsv >  01_final_clonal_indel_calls.tsv

cp 01_final_clonal_indel_calls.tsv no_black_list_clonal_indels.tsv

input_file="01_final_clonal_indel_calls.tsv"
filter_file=$BLACK_LIST
while IFS= read -r value
do
  if [[ ! -z "$value" ]]; then
      awk -v filter_value="$value" '!(($48 ~ ("^" filter_value)))' "$input_file" > tmp_indels.txt
        fi
        done < "$filter_file"

mv tmp_indels.txt 01_final_clonal_indel_calls.tsv

cat final_clonal_* > 01_final_clonal_snp_indel_calls.tsv

C_TSV_NAME="All_somatic_calls"

sbatch -c 2 --mem=32G -p cgawad --time=24:00:00 -e $STD_ERR_OUT_DIR/%A_${TSV_NAME}_sigprofile_%x.err -o $STD_ERR_OUT_DIR/%A_${TSV_NAME}_sigprofile_%x.out ${SCRIPT_DIR}/Scan2_SigProfiler.sh --tsv 01_final_clonal_somatic_snvs.tsv --script_dir ${SCRIPT_DIR} --results_dir ${RESULTS_DIR} --project ${C_TSV_NAME}


VAF_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv AF) )
DP_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv AFDP) )

awk -v VAF="$VAF_COL_NUM" -v DP="$DP_COL_NUM" '$VAF>0.4 && $DP>9' ${PROJECT}_svc_merged_extract_snp.hg38_multianno.no_germline.tsv | cut -f1-5  | sort > nc_candidates

uniq nc_candidates > unique_nc_candidates

fgrep -f unique_nc_candidates *_joint_germline_merged_extract_snp.hg38_multianno.tsv > all_nc_variants.tsv

NC_GT_COL_NUM=$( ($PIPELINE_DIR/colnum.sh all_nc_variants.tsv GT) )
## find sites with >1 sample called
## generate a non clonal calls file
awk '$125 == "0/1" || $125 == "1/1"' all_nc_variants.tsv | cut -f1-5 | sort | uniq -c | awk '$1==1' | cut -c9- | sort > one_cell

grep -f one_cell all_nc_variants.tsv > non_clonal_candidates.tsv

## calculate allele frequency for each call
awk '{gsub(",","\t",$122)}1' non_clonal_candidates.tsv | sed 's/ /\t/g' | awk '{gsub("0","0.000001",$123)}1' | sed 's/ /\t/g' | awk '$123=$123/($122+$123)' | sed 's/ /\t/g' | awk '$125 = $1"_"$2"_"$3"_"$4"_"$5' | sed 's/ /\t/g'  > nc_all_variants_AF.tsv

## calculate average allele frequency by location and base change
awk '$126 == "0/1" || $126 == "1/1"' nc_all_variants_AF.tsv | sed 's/ /\t/g' | awk '{seen[$125]+=$124; count[$125]++} END{for (x in seen)print x, seen[x]/count[x]}' | sed 's/ /\t/g' > non_clonal_calls_pre.tsv

## keep calls with average AF > 0.4 in called cells
awk '$2 > 0.4' non_clonal_calls_pre.tsv | cut -f1 | sed 's/_/\t/g' > nc_final_sites

## pull out those sites and keep GATK pass
grep -f nc_final_sites ${PROJECT}_joint_germline_merged_extract_snp.hg38_multianno.tsv | grep PASS > final_non_clonal_somatic_calls_pre.tsv

## add back header
head -n1 *_joint_germline_merged_extract_snp.hg38_multianno.tsv > header
cat header final_non_clonal_somatic_calls_pre.tsv >  01_final_non_clonal_somatic_snvs.tsv


NC_TSV_NAME="non_clonal_calls"

sbatch -c 2 --mem=32G -p cgawad --time=24:00:00 -e $STD_ERR_OUT_DIR/%A_${TSV_NAME}_sigprofile_%x.err -o $STD_ERR_OUT_DIR/%A_${TSV_NAME}_sigprofile_%x.out ${SCRIPT_DIR}/Scan2_SigProfiler.sh --tsv 01_final_non_clonal_somatic_snvs.tsv --script_dir ${SCRIPT_DIR} --results_dir ${RESULTS_DIR} --project ${NC_TSV_NAME}


## generate a file with all MUTECT calls but quality filtered such that user can look at and compare potential germline calls
##currently this awk doesn't work and produces an empty tsv 2/14/2023
#awk '$62 > 40' *_joint_germline_merged_extract_snp.hg38_multianno.tsv > temp_mq40.tsv
#awk '$33 > 0' temp_mq40.tsv > 01_all_mutect_germline_included.tsv


## this file is very big but creates a conveniently named germline file with all mutation calls for the user to look through, might have a
## header missmatch problem tho

cat indel_header > 01_all_germline_snp_indel.tsv 
cat *_joint_germline_merged_extract_*.hg38_multianno.tsv >> 01_all_germline_snp_indel.tsv

I_TSV_NAME="All_indel_calls"

sbatch -c 2 --mem=32G -p cgawad --time=24:00:00 -e $STD_ERR_OUT_DIR/%A_${TSV_NAME}_sigprofile_%x.err -o $STD_ERR_OUT_DIR/%A_${TSV_NAME}_sigprofile_%x.out ${SCRIPT_DIR}/Scan2_SigProfiler.sh --tsv 01_final_clonal_indel_calls.tsv --script_dir ${SCRIPT_DIR} --results_dir ${RESULTS_DIR} --project ${I_TSV_NAME}

grep athogenic *germline_merged_extract*.tsv > known_pathogenic.tsv
#head -n1 *snp*final.tsv > header2

head -n 1 *germline_merged_extract*.tsv > germline_header

cat germline_header known_pathogenic.tsv > 01_germline_known_pathogenic.tsv

#use alpha-missense annotation t

AM_PATHOGENICITY_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_joint_germline_merged_extract_snp.hg38_multianno.tsv am_pathogenicity) )

awk -v AM_PATH="$AM_PATH_COL_NUM" '$AM_PATH>0.5' ${PROJECT}_joint_germline_merged_extract_snp.hg38_multianno.tsv > 01_snp_germline_known_pathogenic.tsv

$AM_PATHOGENICITY_COL_NUM=$( ($PIPELINE_DIR/colnum.sh ${PROJECT}_joint_germline_merged_extract_indel.hg38_multianno.tsv am_pathogenicity) )

awk -v AM_PATH="$AM_PATH_COL_NUM" '$AM_PATH>0.5' ${PROJECT}_joint_germline_merged_extract_indel.hg38_multianno.tsv > 01_indel_germline_known_pathogenic.tsv

## the old way of doing it
#grep athogenic *germline_merged_extract_snp*.tsv > snp_known_pathogenic.tsv
#cat header snp_known_pathogenic.tsv > 01_snp_germline_known_pathogenic.tsv
#grep athogenic *germline_merged_extract_indel*.tsv > indel_known_pathogenic.tsv
#cat indel_header indel_known_pathogenic.tsv > 01_indel_germline_known_pathogenic.tsv

### run deconstructSigs for clonal and non-clonal snv calls, note if something errored in scan2 doing this u have to fix it here too

## load the conda env

source /home/groups/cgawad/miniconda3/etc/profile.d/conda.sh

conda deactivate

conda activate /home/groups/cgawad/miniconda3/envs/scan2_sigs 


echo after activating conda, the packages are:
conda list
echo python libs is ${PYTHON_LIBS}
echo python libs site packages is ${PYTHON_LIBS_SITE_PACKAGES}

SIGS_OUTPUTS=$RESULTS_DIR/deconstructSigsOutputs
mkdir -p $SIGS_OUTPUTS

echo making the directories
NON_CLONAL_DS=$SIGS_OUTPUTS/non_clonal_deconstructSigs
CLONAL_DS=$SIGS_OUTPUTS/clonal_deconstructSigs
mkdir -p $NON_CLONAL_DS 
mkdir -p $CLONAL_DS

Rscript --verbose $PIPELINE_DIR/deconstructSigs.R $CLONAL_DS/ $RESULTS_DIR/01_final_clonal_somatic_snvs.tsv > $STD_ERR_OUT_DIR/deconstructSigs_clonal.Rout 2>&1
Rscript --verbose $PIPELINE_DIR/deconstructSigs.R $NON_CLONAL_DS/ $RESULTS_DIR/01_final_non_clonal_somatic_snvs.tsv > $STD_ERR_OUT_DIR/deconstructSigs_nc.Rout 2>&1

## use pdfunite now to merge the graphs

echo pdf uniting
ml system poppler/0.47.0

#pdfunite $SIGS_OUTPUTS/mutsig_plot_bar* $RESULTS_DIR/01_individual_bar_signatures.pdf
pdfunite $CLONAL_DS/mutsig_plot_stacked* $RESULTS_DIR/01_clonal_individual_stacked_signatures.pdf
cp $CLONAL_DS/01_combined*_stacked_mutsig_plot.pdf $RESULTS_DIR/01_clonal_combined_stacked_mutsig_plot.pdf

pdfunite $NON_CLONAL_DS/mutsig_plot_stacked* $RESULTS_DIR/01_non_clonal_individual_stacked_signatures.pdf
cp $NON_CLONAL_DS/01_combined*_stacked_mutsig_plot.pdf $RESULTS_DIR/01_non_clonal_combined_stacked_mutsig_plot.pdf

##get the functional mutations 
grep -E "nonsyn|stop|splic" 01_final_clonal_somatic_snvs.tsv > functional_snvs

#get the header
head -n 1 header > 01_functional_clonal_somatic_snvs.tsv
cat functional_snvs >> 01_functional_clonal_somatic_snvs.tsv


grep -E "insert|delet|frameshift|exonic" 01_final_clonal_indel_calls.tsv > functional_indels
grep -v ncRNA functional_indels > functional_indels2

#get the header
head -n 1 indel_header > 01_functional_clonal_somatic_indels.tsv
cat functional_indels2 >> 01_functional_clonal_somatic_indels.tsv

if [[ $TARGETED -eq 0 ]]; then
Rscript --verbose $PIPELINE_DIR/post_pipeline_heatmap.R --project snv_indel --directory $RESULTS_DIR --snv_filename 01_final_clonal_somatic_snvs.tsv --indel_filename 01_final_clonal_indel_calls.tsv > $STD_ERR_OUT_DIR/post_pipeline_heatmaps.Rout 2>&1
fi

if [[ $TARGETED -eq 1 ]]; then
Rscript --verbose $PIPELINE_DIR/post_pipeline_heatmap.R --project snv_indel --directory $RESULTS_DIR --snv_filename 01_final_clonal_somatic_snvs.tsv --indel_filename 01_final_clonal_indel_calls.tsv --exome > $STD_ERR_OUT_DIR/post_pipeline_heatmaps.Rout 2>&1
fi

# this way of doing things is deprecated
mkdir -p 01_final_outputs
rsync -a --exclude '01_final_outputs' ${RESULTS_DIR}/01* 01_final_outputs/

#PLEASE JUST PUT IT IN THE FOLDER WHY DOES THE PDF RANDOMLY GET DELTED
rsync -a *vaf_heatmap.pdf 01_final_outputs/

if [[ $EMAIL -eq 1 ]]; then
                # Email the user when the job is started if --email flag was set in submit_all
        echo "Scan2 job for ${PROJECT} has ended, with job name: ${SLURM_JOB_NAME}, start time: ${SLURM_JOB_START_TIME}. Please see ${PROJECT} folders std_err_out folder for more details. " | mailx -s "Scan2 job for ${PROJECT}:${SLURM_JOB_ID} has ended" "${USER}@stanford.edu"
        fi


#######

rm temp_mq40.tsv
rm *bed
rm *.g.vcf.gz*
rm -rf *gdb
#rm -rf tmp*
#rm $RESULTS_DIR/*allsample*
rm *marked.bam*
rm *list
rm *chrM
rm *location
rm *allsample*gz*
rm *.deduped_sorted.bam
rm *.sorted.bam
rm *.deduped_sorted.bam.bai
rm *.sorted.bam.bai

echo "ANNOTATION DONE: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"