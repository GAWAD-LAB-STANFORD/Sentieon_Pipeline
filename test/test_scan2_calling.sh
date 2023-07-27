#!/bin/bash
#
#SBATCH --job-name=scan2_variant_calling
#SBATCH --time=4-00:00:00
#SBATCH --cores=10
#SBATCH --mem=32G
#SBATCH --partition=cgawad

ml biology bwa samtools java
module load biology sentieon/202112.01
export SENTIEON_INSTALL_DIR=/share/software/user/restricted/sentieon/202112.01/ #your Sentieon package location
export SENTIEON_LICENSE=license4.stanford.edu:5443 #your license file location

#The `bamlist` and `regionflag` parameters will also need to be updated. The GATK uses the uppercase `-I` argument for input BAM files while Sentieon uses a lowercase `-i`.  For input BED files, the GATK uses the `-L` argument while Sentieon uses the `--interval` argument.

#SC_BAMS=$(find $RESULTS_DIR -maxdepth 1 -name "${SAMPLE_PREFIX}*.realigned_deduped_sorted.bam" ! -name "${NORMAL_BAM_PATH}")
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
RESULTS_DIR=$SCRATCH/test_scan2/
INPUT_BAM=$SCRATCH/test_scan2/ANEU01_Bulk_EndovascularLegion_WES_Capt09_S25.realigned_deduped_sorted.bam 
INPUT_BED=/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n22chr.bed
DBSNP=/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.dbsnp138.vcf 
OUTPUT_VCF=$SCRATCH/test_scan2/test_scan2_temp.vcf
SELECT_VARIANTS=$RESULTS_DIR/test_scan2_input.vcf

sentieon driver \
  -i $INPUT_BAM \
  --interval $INPUT_BED \
  --algo Haplotyper \
  --trim_soft_clip \
  --dbsnp $DBSNP \
  --min_base_qual 10 \
  --min_map_qual 60 \
  $OUTPUT_VCF

ml gsl/2.3
ml java/1.8.0_131
ml R/4.0.2 java biology samtools bedtools gatk bcftools

SelectVariants --output $SELECT_VARIANTS --selectExpressions vc.getGenotype(\"ANEU01_Bulk_WB_WES_Capt09_S26\").isCalled() --exclude-non-variants true --restrict-alleles-to BIALLELIC --variant $OUTPUT_VCF --reference /oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38.fasta --invertSelect false --exclude-filtered false --preserve-alleles false --remove-unused-alternates false --keep-original-ac false --keep-original-dp false --mendelian-violation false --invert-mendelian-violation false --mendelian-violation-qual-threshold 0.0 --select-random-fraction 0.0 --remove-fraction-genotypes 0.0 --fully-decode false --max-indel-size 2147483647 --min-indel-size 0 --max-filtered-genotypes 2147483647 --min-filtered-genotypes 0 --max-fraction-filtered-genotypes 1.0 --min-fraction-filtered-genotypes 0.0 --max-nocall-number 2147483647 --max-nocall-fraction 1.0 --set-filtered-gt-to-nocall false --allow-nonoverlapping-command-line-samples false --suppress-reference-path false --genomicsdb-max-alternate-alleles 50 --call-genotypes false --genomicsdb-use-bcf-codec false --genomicsdb-shared-posixfs-optimizations false --genomicsdb-use-gcs-hdfs-connector false --interval-set-rule UNION --interval-padding 0 --interval-exclusion-padding 0 --interval-merging-rule ALL --read-validation-stringency SILENT --seconds-between-progress-updates 10.0 --disable-sequence-dictionary-validation false --create-output-bam-index true --create-output-bam-md5 false --create-output-variant-index true --create-output-variant-md5 false --max-variants-per-shard 0 --lenient false --add-output-sam-program-record true --add-output-vcf-command-line true --cloud-prefetch-buffer 40 --cloud-index-prefetch-buffer -1 --disable-bam-index-caching false --sites-only-vcf-output false --help false --version false --showHidden false --verbosity INFO --QUIET false --use-jdk-deflater false --use-jdk-inflater false --gcs-max-retries 20 --gcs-project-for-requester-pays  --disable-tool-default-read-filters false


