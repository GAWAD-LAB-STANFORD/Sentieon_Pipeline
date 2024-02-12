#!/bin/bash

#SBATCH --job-name=6_annvoar
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=180G

TARGETED=0
PYTHON_LIBS="/home/groups/cgawad/python_libs/bin"
PYTHON_LIBS_SITE_PACKAGES="/home/groups/cgawad/python_libs/lib/python3.6/site-packages"
START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --results_dir )                 shift
                                        RESULTS_DIR=$1
                                        ;;
        --tools_dir )                   shift
                                        TOOLS_DIR=$1
                                        ;;
        --annovar_genome_version )      shift
                                        ANNOVAR_GENOME_VERSION=$1
                                        ;;
        --annovar_dir )                 shift
                                        ANNOVAR_DIR=$1
                                        ;;;
        --pipeline_dir )                shift
                                        PIPELINE_DIR=$1
                                        ;;
        --reference_dir )               shift
                                        REFERENCE_DIR=$1
                                        ;;
        --ref_fasta )                   shift
                                        REF_FASTA=$1
                                        ;;
        --normal_sample_name )          shift
                                        NORMAL_SAMPLE_NAME=$1
                                        ;;
        --sample_string )               shift
                                        SAMPLE_ARRAY=( $(echo $1 | sed 's/:/ /g') )
                                        ;;
        --targeted )                    shift
                                        TARGETED=$1
                                        ;;
        --std_err_out_dir )             shift
                                        STD_ERR_OUT_DIR=$1
                                        ;;
        --tranche )                     shift
                                        TRANCHE=$1
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

if [ -z $RESULTS_DIR ] || [ -z $TOOLS_DIR ] || [ -z $ANNOVAR_GENOME_VERSION ] || [ -z $ANNOVAR_DIR ] || \
    [ -z $PIPELINE_DIR ] || [ -z $REFERENCE_DIR ] || [ -z $REF_FASTA ] || [ -z $NORMAL_SAMPLE_NAME ] || \
    [ -z $SAMPLE_ARRAY ] || [ -z $TARGETED ] || [ -z $STD_ERR_OUT_DIR ] || [ -z $TRANCHE ]; then
    echo "Variables not supplied correctly. Check script for intake parameters. All are required to be specified. Exiting with code 1"
    exit 1
fi

SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND\nSample: $SAMPLE"
cd $RESULTS_DIR

echo "### Annotating SNPs and Indels ###: $(date)"
ml purge
ml gsl/2.3
ml java/1.8.0_131 perl/5.26.0 biology gatk/4.1.4.1 bedtools samtools/1.8 vcftools/0.1.15
#export R_LIBS="/home/groups/cgawad/R_libs"
ml python/3.6.1 system ghostscript/9.53.2
ml math py-numpy/1.19.2_py36 py-pandas/1.0.3_py36
ml R/4.2
export PATH=${PYTHON_LIBS}:$PATH
export PYTHONPATH=${PYTHON_LIBS_SITE_PACKAGES}:$PYTHONPATH

HAPMAP_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/hapmap_3.3.hg38.vcf.gz"
OMNI_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/1000G_omni2.5.hg38.vcf.gz"
ONEKG_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/1000G_phase1.snps.high_confidence.hg38.vcf.gz"
DBSNP_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
MILLS_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
AXIOM_VCF="${REFERENCE_DIR}/GATK_Resource_Bundle_hg38/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz"
SNP_PREFIX=${SAMPLE%.vcf.gz}
VCF_FILE="${RESULTS_DIR}/${SAMPLE}"
SCRIPT_DIR="${PIPELINE_DIR}/scripts"

#This is a text file containing blacklisted mutations, edit this text file not stuff here to add or remove from blacklist
#Note I used wildcard with the text in this file, so make sure to be specific with your genes or be ready for classes
#of genes to be removed from the resulting tsv file.
BLACK_LIST="${PIPELINE_DIR}/mutation_blacklist.txt"

INDEL_PREFIX=${SNP_PREFIX}"_indel"

#TODO-One of these steps may be labeling mutations as germline mutations in the somatic called file, may need to edit this if still getting 
#Pretty sure somatic mutations are being labeled as coming from normal sample, despite normal sample not having mutations in its file
#hopefully can just remove the rows labeled as normal sample and should be all good

mkdir -p `pwd`/tmp7
mkdir -p `pwd`/tmp8
mkdir -p `pwd`/tmp9
mkdir -p `pwd`/tmp10

#if [ "$PANEL_BED" = "0" ]; then
    #SNP_PREFIX="${PROJECT}.merged.snp_vqsr.snp_only"
    #INDEL_PREFIX="${PROJECT}.merged.indel_vqsr.indel_only"
#fi

if [ $TARGETED -eq 1 ]; then
    echo "### Running VQSR on SNPs and Indels ### - START: $(date)"

    #the USER ERROR that is raised here is perplexing but doesn't seem to stop from generating an output vcf file 

    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp7" VariantRecalibrator \
        -V $VCF_FILE -O ${SNP_PREFIX}.merged.snp.recal \
        --tranches-file ${SNP_PREFIX}.merged.snp.recal.tranches \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
        --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
        -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA #--rscript-file "${SNP_PREFIX}.merged.snp.recal_plots.R"

    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp8" VariantRecalibrator \
        -V $VCF_FILE -O ${INDEL_PREFIX}.merged.indel.recal \
        --tranches-file ${INDEL_PREFIX}.merged.indel.recal.tranches \
        --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
        --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA \
        #--rscript-file "${SNP_PREFIX}.merged.indel.recal_plots.R"

    echo "### Running VQSR on SNPs and Indels ### - END: $(date)"

else
    echo "### Running VQSR on SNPs and Indels ### - START: $(date)"

    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp7" VariantRecalibrator \
        -V $VCF_FILE -O ${SNP_PREFIX}.merged.snp.recal \
        --tranches-file ${SNP_PREFIX}.merged.snp.recal.tranches \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
        --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
        -an QD -an DP -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
    -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA #--rscript-file "${SNP_PREFIX}.merged.snp.recal_plots.R"

    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp8" VariantRecalibrator \
        -V $VCF_FILE -O ${INDEL_PREFIX}.merged.indel.recal \
        --tranches-file ${INDEL_PREFIX}.merged.indel.recal.tranches \
        --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
        --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        -an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
    -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA \
        #--rscript-file "${SNP_PREFIX}.merged.indel.recal_plots.R"

    echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
fi

echo "### Applying VQSR to SNPs and Indels ### - START: $(date)"

#SNP_PREFIX="${PROJECT}.merged.snp_only"
#INDEL_PREFIX="${PROJECT}.merged.indel_only"


if [ -s ${PROJECT}.merged.indel.recal.tranches ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp9" ApplyVQSR \
        -R $REF_FASTA -V $VCF_FILE -O ${SNP_PREFIX}.merged.indel_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${SNP_PREFIX}.merged.indel.recal.tranches \
        --recal-file ${INDEL_PREFIX}.merged.indel.recal -mode INDEL
else
    echo "Not enough Indels to Perform VQSR" >> $PIPELINE_STATUS
    cp $VCF_FILE ${SNP_PREFIX}.merged.indel_vqsr.vcf.gz
    tabix ${SNP_PREFIX}.merged.indel_vqsr.vcf.gz
fi


if [ -s ${SNP_PREFIX}.merged.snp.recal.tranches ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx4G -Xms4G -Djava.io.tmpdir=`pwd`/tmp10" ApplyVQSR \
        -R $REF_FASTA -V $VCF_FILE -O ${SNP_PREFIX}.merged.snp_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${SNP_PREFIX}.merged.snp.recal.tranches \
        --recal-file ${SNP_PREFIX}.merged.snp.recal -mode SNP
else
    echo "Not enough data, skipping SNP VQSR" >> $PIPELINE_STATUS
    cp $VCF_FILE ${SNP_PREFIX}.merged.snp_vqsr.vcf.gz
        tabix ${SNP_PREFIX}.merged.snp_vqsr.vcf.gz
fi

echo "Indel VQSR Successfully Completed" >> $PIPELINE_STATUS
echo "### Applying VQSR to SNPs and Indels ### - END: $(date)"

echo "### Extracting SNPs and Indels ### - START: $(date)"
SNP_EXTRACT=${SNP_PREFIX}_extract_snp
INDEL_EXTRACT=${SNP_PREFIX}_extract_indel
    
#entries get lost at this command for only porteus
#--java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=2 -Xmx8G -Xms8G" <- removed this option from select variants in case this was causing the truncated file
gatk  SelectVariants \
    -R $REF_FASTA -V ${SNP_PREFIX}.merged.snp_vqsr.vcf.gz \
    -O "${SNP_EXTRACT}.vcf.gz" -select-type SNP

gatk SelectVariants \
    -R $REF_FASTA -V ${SNP_PREFIX}.merged.indel_vqsr.vcf.gz \
    -O "${INDEL_EXTRACT}.vcf.gz" -select-type INDEL
echo "### Extracting SNPs and Indels ### - END: $(date)"

echo "### Extracting SNPs and Indels ### - END: $(date)"
#For some files, after SNP_EXTRACT the resulting file has lost all chromosomes besides 1st one, which seems to mean that it simply isnt scannign passed some variant for these files

SNP_EXTRACT=${SNP_PREFIX}_extract_snp
INDEL_EXTRACT=${SNP_PREFIX}_extract_indel

perl ${ANNOVAR_DIR}/table_annovar.pl ${SNP_EXTRACT}.vcf.gz -vcfinput -operation g,f,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${SNP_EXTRACT} -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20221231,cosmic91_coding,cosmic91_noncoding,gnomad211_exome,AlphaMissense_hg38

perl ${ANNOVAR_DIR}/table_annovar.pl ${INDEL_EXTRACT}.vcf.gz -vcfinput -operation g,f,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${INDEL_EXTRACT} -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20221231,cosmic91_coding,cosmic91_noncoding,gnomad211_exome,AlphaMissense_hg38

bgzip ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.vcf

tabix ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz

bgzip ${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.vcf

tabix ${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
echo "### Annotating SNPs and Indels ###"

echo "### Convert annotated VCF to TSV ###"
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv

${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv


#sed -i "s/#CHROM/CHROM/" ${SNP_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
#${TOOLS_DIR}/vcflib/bin/vcf2tsv \
#    -g ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
#    ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
#sed -i "s/#CHROM/CHROM/" ${INDEL_PREFIX}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv

echo "### Convert annotated VCF to TSV ###"

echo "### Recalculate VAF ###"
#ml python/3.6.1
#ml math py-numpy/1.19.2_py36 py-pandas/1.0.3_py36
#ml py-pandas/1.0.3_py36
#ml java/1.8.0_131
export PATH=${PYTHON_LIBS}:$PATH
export PYTHONPATH=${PYTHON_LIBS_SITE_PACKAGES}:$PYTHONPATH

## this was a workaround to calculate the VAF we wanted in the old script, leaving it in for posterity but prob not exactly what you want now
## now tho we'll want a way to calculate VAF probably right? currently this pipeline doesn't do that for you
#python3 ${SCRIPT_DIR}/split_add_VAF.py \
#    -i ${RESULTS_DIR}/${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
#    -o ${RESULTS_DIR}/${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
#
#python3 ${SCRIPT_DIR}/split_add_VAF.py \
#    -i ${RESULTS_DIR}/${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
#    -o ${RESULTS_DIR}/${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
#
rm ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
rm ${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Recalculate VAF ###"

echo "### Computing mutational signature with SigProfiler ###"
OPTIONS=()
if [ "$GENOME_VERSION" = "b37" ]; then
    OPTIONS+=( "--b37" )
fi

#ml system ghostscript

#PROJECT="EEG_project"

#ml system ghostscript

#if [ -f 01_Ginko_CNV.pdf ]; then
#	mv 01_Ginko_CNV.pdf 01_${PROJECT}_Ginko_CNV
#fi

#gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=01_Combined_CNV_Plots.pdf -dBATCH *CN.pdf

#if [ -f 01_${PROJECT}_Ginko_CNV ]; then
#        mv 01_${PROJECT}_Ginko_CNV 01_${PROJECT}_Ginko_CNV.pdf
#fi

SNP_EXTRACT=${SNP_PREFIX}_extract_snp
    INDEL_EXTRACT=${SNP_PREFIX}_extract_indel

sed -i "s/#CHROM/CHROM/" ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv
sed -i "s/#CHROM/CHROM/" ${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv
#PROJECT="EEG_project"


if [[ ${SAMPLE} != *"joint_germline"* ]]; then
    ml math py-numpy/1.19.2_py36
    ml py-pandas/1.0.3_py36
    python3 ${SCRIPT_DIR}/remove_control_rows.py \
        -d ${RESULTS_DIR}/${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
        -p ${RESULTS_DIR}/${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.no_germline.tsv \
        -n ${NORMAL_SAMPLE_NAME}

    python3 ${SCRIPT_DIR}/remove_control_rows.py \
            -d ${RESULTS_DIR}/${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
            -p ${RESULTS_DIR}/${INDEL_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.no_germline.tsv \
            -n ${NORMAL_SAMPLE_NAME}
fi

srun -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
    ${SCRIPT_DIR}/SigProfiler.sh --project "all_non_germline_calls" \
    --tsv ${SNP_EXTRACT}.${ANNOVAR_GENOME_VERSION}_multianno.no_germline.tsv \
    --script_dir ${SCRIPT_DIR} --results_dir ${RESULTS_DIR} ${OPTIONS[@]}
# rm -rf $SCRATCH/$SLURM_JOB_ID


if [ "$PANEL_BED" = "0" ]; then
    rm ${PROJECT}.merged.snp.recal ${PROJECT}.merged.snp.recal.idx
    rm ${PROJECT}.merged.indel.recal ${PROJECT}.merged.indel.recal.idx
    rm ${PROJECT}.merged.snp_vqsr.vcf.gz* ${PROJECT}.merged.indel_vqsr.vcf.gz*
    rm ${SNP_PREFIX}.avinput ${INDEL_PREFIX}.avinput
else
    rm ${SNP_PREFIX}.avinput ${INDEL_PREFIX}.avinput
fi

##### filter for final somatic calls

###functions###

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"