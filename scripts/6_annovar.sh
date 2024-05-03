#!/bin/bash

#SBATCH --job-name=6_annvoar
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad

TARGETED=0
PYTHON_LIBS="/home/groups/cgawad/python_libs/bin"
PYTHON_LIBS_SITE_PACKAGES="/home/groups/cgawad/python_libs/lib/python3.6/site-packages"
START_TIME=$(date +%s)
SCRIPT_COMMAND="$@"
while [ "$1" != "" ]; do
    case $1 in
        --scratch_dir )                 shift
                                        SCRATCH_DIR=$1
                                        ;;
        --tools_dir )                   shift
                                        TOOLS_DIR=$1
                                        ;;
        --annovar_genome_version )      shift
                                        ANNOVAR_GENOME_VERSION=$1
                                        ;;
        --annovar_dir )                 shift
                                        ANNOVAR_DIR=$1
                                        ;;
        --script_dir )                  shift
                                        SCRIPT_DIR=$1
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
        --somatic_germline )            shift
                                        SOMATIC_GERMLINE=$1
                                        ;;
        --project )                     shift
                                        PROJECT=$1
                                        ;;
    esac
    shift
done

if [ -z $SCRATCH_DIR ] || [ -z $TOOLS_DIR ] || [ -z $ANNOVAR_GENOME_VERSION ] || [ -z $ANNOVAR_DIR ] || \
    [ -z $SCRIPT_DIR ] || [ -z $REFERENCE_DIR ] || [ -z $REF_FASTA ] || [ -z $NORMAL_SAMPLE_NAME ] || \
    [ -z $TARGETED ] || [ -z $STD_ERR_OUT_DIR ] || [ -z $TRANCHE ] || [ -z $SOMATIC_GERMLINE ] || \
    [ -z $PROJECT ]; then
    echo "Variables not supplied correctly. Check script for required intake parameters. Exiting with code 1"
    exit 1
fi

echo -e "START: $(date)\nSentieon Pipeline\nScript command: $SCRIPT_COMMAND"
cd $SCRATCH_DIR

echo "### Annotating SNPs and Indels ###: $(date)"
ml gsl/2.3 java/1.8.0_131 perl/5.26.0 biology gatk/4.1.4.1 bedtools samtools/1.8 vcftools/0.1.15
# export R_LIBS="/home/groups/cgawad/R_libs"
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
MERGED_VCF="${SCRATCH_DIR}/${SAMPLE}"

#This is a text file containing blacklisted mutations, edit this text file not stuff here to add or remove from blacklist
#Note I used wildcard with the text in this file, so make sure to be specific with your genes or be ready for classes
#of genes to be removed from the resulting tsv file.
BLACK_LIST="${SCRIPT_DIR}/mutation_blacklist.txt"

INDEL_PREFIX=${SNP_PREFIX}"_indel"

#TODO-One of these steps may be labeling mutations as germline mutations in the somatic called file, may need to edit this if still getting 
#Pretty sure somatic mutations are being labeled as coming from normal sample, despite normal sample not having mutations in its file
#hopefully can just remove the rows labeled as normal sample and should be all good

if [ $TARGETED -eq 1 ]; then
    echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
    # the USER ERROR that is raised here is perplexing but doesn't seem to stop from generating an output vcf file 
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp7" VariantRecalibrator \
        -V ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz -O ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal \
        --tranches-file ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal.tranches \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
        --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
        -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA
        # --rscript-file ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal_plots.R
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp8" VariantRecalibrator \
        -V ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz -O ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal \
        --tranches-file ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal.tranches \
        --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
        --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA
        # --rscript-file ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal_plots.R
    echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
else
    echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp7" VariantRecalibrator \
        -V ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz -O ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal \
        --tranches-file ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal.tranches \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
        --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
        -an QD -an DP -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA
        # --rscript-file "${PROJECT}.${SOMATIC_GERMLINE}.snp.recal_plots.R"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp8" VariantRecalibrator \
        -V ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz -O ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal \
        --tranches-file ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal.tranches \
        --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
        --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        -an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 \
        -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
        -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
        -tranche 92.0 -tranche 91.0 -tranche 90.0 \
        --max-gaussians 4 -R $REF_FASTA \
        # --rscript-file "${PROJECT}.${SOMATIC_GERMLINE}.indel.recal_plots.R"
    echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
fi


echo "### Applying VQSR to SNPs and Indels ### - START: $(date)"
if [ -s ${PROJECT}.indel.recal.tranches ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx16G -Xms16G -Djava.io.tmpdir=`pwd`/tmp9" ApplyVQSR \
        -R $REF_FASTA -V ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz -O ${PROJECT}.${SOMATIC_GERMLINE}.indel_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal.tranches \
        --recal-file ${PROJECT}.${SOMATIC_GERMLINE}.indel.recal -mode INDEL
else
    echo "Not enough Indels to perform indel VQSR" >> $PIPELINE_STATUS
    cp ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz ${PROJECT}.${SOMATIC_GERMLINE}.indel_vqsr.vcf.gz
    tabix ${PROJECT}.${SOMATIC_GERMLINE}.indel_vqsr.vcf.gz
fi


if [ -s ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal.tranches ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx4G -Xms4G -Djava.io.tmpdir=`pwd`/tmp10" ApplyVQSR \
        -R $REF_FASTA -V ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz -O ${PROJECT}.${SOMATIC_GERMLINE}.snp_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal.tranches \
        --recal-file ${PROJECT}.${SOMATIC_GERMLINE}.snp.recal -mode SNP
else
    echo "Not enough SNPs to perform SNP VQSR" >> $PIPELINE_STATUS
    cp ${PROJECT}.${SOMATIC_GERMLINE}_merged.vcf.gz ${PROJECT}.${SOMATIC_GERMLINE}.snp_vqsr.vcf.gz
    tabix ${PROJECT}.${SOMATIC_GERMLINE}.snp_vqsr.vcf.gz
fi
echo "### Applying VQSR to SNPs and Indels ### - END: $(date)"


echo "### Extracting SNPs and Indels ### - START: $(date)"
SNP_EXTRACT=${PROJECT}.${SOMATIC_GERMLINE}_extract_snp
INDEL_EXTRACT=${PROJECT}.${SOMATIC_GERMLINE}_extract_indel
# entries get lost at this command for only porteus
# --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=2 -Xmx8G -Xms8G" <- removed this option from select variants in case this was causing the truncated file
gatk  SelectVariants \
    -R $REF_FASTA -V ${PROJECT}.${SOMATIC_GERMLINE}.snp_vqsr.vcf.gz \
    -O ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.vcf.gz -select-type SNP
gatk SelectVariants \
    -R $REF_FASTA -V ${PROJECT}.${SOMATIC_GERMLINE}.indel_vqsr.vcf.gz \
    -O ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.vcf.gz -select-type INDEL
# For some files, after SNP_EXTRACT the resulting file has lost all chromosomes besides 1st one, which seems to mean that it simply isnt scanning passed some variant for these files
echo "### Extracting SNPs and Indels ### - END: $(date)"


echo "### Annotating SNPs and Indels ### - START: $(date)"
perl ${ANNOVAR_DIR}/table_annovar.pl ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.vcf.gz -vcfinput -operation g,f,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20221231,cosmic91_coding,cosmic91_noncoding,gnomad211_exome,AlphaMissense_hg38
perl ${ANNOVAR_DIR}/table_annovar.pl ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.vcf.gz -vcfinput -operation g,f,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20221231,cosmic91_coding,cosmic91_noncoding,gnomad211_exome,AlphaMissense_hg38
bgzip ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.vcf
tabix ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
bgzip ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.vcf
tabix ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
echo "### Annotating SNPs and Indels ### - END: $(date)"


echo "### Convert annotated VCF to TSV ### - START: $(date)"
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv
# sed -i "s/#CHROM/CHROM/" ${PROJECT}.${SOMATIC_GERMLINE}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
# ${TOOLS_DIR}/vcflib/bin/vcf2tsv \
#     -g ${PROJECT}.${SOMATIC_GERMLINE}.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
#     ${PROJECT}.${SOMATIC_GERMLINE}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
# sed -i "s/#CHROM/CHROM/" ${PROJECT}.${SOMATIC_GERMLINE}.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Convert annotated VCF to TSV ### - END: $(date)"


# echo "### Recalculate VAF ### - START: $(date)"
# ml python/3.6.1
# ml math py-numpy/1.19.2_py36 py-pandas/1.0.3_py36
# ml py-pandas/1.0.3_py36
# ml java/1.8.0_131
# export PATH=${PYTHON_LIBS}:$PATH
# export PYTHONPATH=${PYTHON_LIBS_SITE_PACKAGES}:$PYTHONPATH
# This was a workaround to calculate the VAF we wanted in the old script, leaving it in for posterity but prob not exactly what you want now
# Now tho we'll want a way to calculate VAF probably right? currently this pipeline doesn't do that for you
# python3 ${SCRIPT_DIR}/split_add_VAF.py \
#     -i ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
#     -o ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
# python3 ${SCRIPT_DIR}/split_add_VAF.py \
#     -i ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
#     -o ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
# rm ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
# rm ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
# echo "### Recalculate VAF ### - END: $(date)"


echo "### Computing mutational signature with SigProfiler ### - START: $(date)"
SNP_EXTRACT=${PROJECT}.${SOMATIC_GERMLINE}_extract_snp
INDEL_EXTRACT=${PROJECT}.${SOMATIC_GERMLINE}_extract_indel
sed -i "s/#CHROM/CHROM/" ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv
sed -i "s/#CHROM/CHROM/" ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv

if [[ ${SAMPLE} != *"joint_germline"* ]]; then
    ml math py-numpy/1.19.2_py36
    ml py-pandas/1.0.3_py36
    python3 ${SCRIPT_DIR}/remove_control_rows.py \
        -d ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
        -p ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.no_germline.tsv \
        -n ${NORMAL_SAMPLE_NAME}
    python3 ${SCRIPT_DIR}/remove_control_rows.py \
        -d ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv \
        -p ${SCRATCH_DIR}/${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.no_germline.tsv \
        -n ${NORMAL_SAMPLE_NAME}
fi
srun -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
    ${SCRIPT_DIR}/SigProfiler.sh --project "all_non_germline_calls" \
    --tsv ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.no_germline.tsv \
    --script_dir ${SCRIPT_DIR} --results_dir ${SCRATCH_DIR} ${OPTIONS[@]}
echo "### Computing mutational signature with SigProfiler ### - END: $(date)"


if [ ! -f ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv ]; then
    echo "Final file ${PROJECT}.${SOMATIC_GERMLINE}_extract_snp.${ANNOVAR_GENOME_VERSION}_multianno.tsv not found. Exiting with code 1"
    exit 1
fi
rm ${PROJECT}.snp.recal ${PROJECT}.snp.recal.idx
rm ${PROJECT}.indel.recal ${PROJECT}.indel.recal.idx
rm ${PROJECT}.snp_vqsr.vcf.gz* ${PROJECT}.indel_vqsr.vcf.gz*
rm ${PROJECT}.${SOMATIC_GERMLINE}.avinput ${PROJECT}.${SOMATIC_GERMLINE}.avinput

##### filter for final somatic calls

### functions ###

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"