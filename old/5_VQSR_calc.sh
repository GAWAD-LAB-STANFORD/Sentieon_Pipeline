#this is a temp file to be transferred over to 5_annovar.sh later
if [ "$PANEL_BED" = "0" ]; then
    SNP_PREFIX="${SAMPLE_PREFIX}.merged.snp_vqsr.snp_only"
    INDEL_PREFIX="${SAMPLE_PREFIX}.merged.indel_vqsr.indel_only"
fi

    if [ $TARGETED -eq 1 ]; then
        echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx8G -Xms8G -Djava.io.tmpdir=`pwd`/tmp7" VariantRecalibrator \
            -V ${SAMPLE_PREFIX}_svc_merged.vcf.gz -O ${SNP_PREFIX}.merged.snp.recal \
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
            --max-gaussians 4 -R $REF_FASTA --rscript-file ${PROJECT}.merged.snp.recal_plots.R

	 gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx8G -Xms8G -Djava.io.tmpdir=`pwd`/tmp8" VariantRecalibrator \
            -V ${SAMPLE_PREFIX}_svc_merged.vcf.gz -O ${PROJECT}.merged.indel.recal \
            --tranches-file ${PROJECT}.merged.indel.recal.tranches \
            --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
            --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
            -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
            -tranche 100.0 -tranche 99.95 -tranche 99.9 \
      	    -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
 	    -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
 	    -tranche 92.0 -tranche 91.0 -tranche 90.0 \
            --max-gaussians 4 -R $REF_FASTA \
            --rscript-file ${PROJECT}.merged.indel.recal_plots.R

     echo "### Running VQSR on SNPs and Indels ### - END: $(date)"

    else
        echo "### Running VQSR on SNPs and Indels ### - START: $(date)"

        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx8G -Xms8G -Djava.io.tmpdir=`pwd`/tmp7" VariantRecalibrator \
            -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.snp.recal \
            --tranches-file ${PROJECT}.merged.snp.recal.tranches \
            --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
            --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
            --resource:1000G,known=false,training=true,truth=true,prior=10.0 $ONEKG_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=7.0 $DBSNP_VCF \
            -an QD -an DP -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
	    -tranche 100.0 -tranche 99.95 -tranche 99.9 \
            -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
            -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
            -tranche 92.0 -tranche 91.0 -tranche 90.0 \
            --max-gaussians 4 -R $REF_FASTA --rscript-file ${PROJECT}.merged.snp.recal_plots.R

        gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx8G -Xms8G -Djava.io.tmpdir=`pwd`/tmp8" VariantRecalibrator \
            -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.indel.recal \
            --tranches-file ${PROJECT}.merged.indel.recal.tranches \
            --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
            --resource:axiomPoly,known=false,training=true,truth=false,prior=10 $AXIOM_VCF \
            --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
            -an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
	    -tranche 100.0 -tranche 99.95 -tranche 99.9 \
            -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
            -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
            -tranche 92.0 -tranche 91.0 -tranche 90.0 \
            --max-gaussians 4 -R $REF_FASTA \
            --rscript-file ${PROJECT}.merged.indel.recal_plots.R

        echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
    fi

    echo "### Applying VQSR to SNPs and Indels ### - START: $(date)"

SNP_PREFIX="${PROJECT}.merged.snp_only"
INDEL_PREFIX="${PROJECT}.merged.indel_only"


if [ -s ${PROJECT}.merged.indel.recal.tranches ]; then

      gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx4G -Xms4G -Djava.io.tmpdir=`pwd`/tmp9" ApplyVQSR \
        -R $REF_FASTA -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.indel_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.merged.indel.recal.tranches \
        --recal-file ${PROJECT}.merged.indel.recal -mode INDEL

else

 echo "Not enough Indels to Perform VQSR" >> $PIPELINE_STATUS
        cp  ${PROJECT}.merged.vcf.gz ${PROJECT}.merged.indel_vqsr.vcf.gz
        tabix ${PROJECT}.merged.indel_vqsr.vcf.gz

fi


if [ -s ${PROJECT}.merged.snp.recal.tranches ]; then


 gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx4G -Xms4G -Djava.io.tmpdir=`pwd`/tmp10" ApplyVQSR \
        -R $REF_FASTA -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.merged.snp_vqsr.vcf.gz \
        --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.merged.snp.recal.tranches \
        --recal-file ${PROJECT}.merged.snp.recal -mode SNP

else

    echo "Not enough data, skipping SNP VQSR" >> $PIPELINE_STATUS
	cp ${PROJECT}.merged.vcf.gz ${PROJECT}.merged.snp_vqsr.vcf.gz
        tabix ${PROJECT}.merged.snp_vqsr.vcf.gz

fi


	echo "Indel VQSR Successfully Completed" >> $PIPELINE_STATUS
        echo "### Applying VQSR to SNPs and Indels ### - END: $(date)"


    echo "### Extracting SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=2 -Xmx8G -Xms8G" SelectVariants \
        -R $REF_FASTA -V ${PROJECT}.merged.snp_vqsr.vcf.gz \
        -O ${SNP_PREFIX}.vcf.gz -select-type SNP

    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=2 -Xmx8G -Xms8G" SelectVariants \
        -R $REF_FASTA -V ${PROJECT}.merged.indel_vqsr.vcf.gz \
        -O ${INDEL_PREFIX}.vcf.gz -select-type INDEL
    echo "### Extracting SNPs and Indels ### - END: $(date)"

    echo "### Extracting SNPs and Indels ### - END: $(date)"

