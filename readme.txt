This is a WIP directory for the sentieon pipeline, all scripts with "test" prefixes will likely be replaced by equivalent code in submit_all.sh when I figure out how to get it to run through the main script. Other scripts have descriptions in them of what they are meant to accomplish, some may or may not need to be removed later.

The important files that are called on by submit_all.sh are labelled with the prefixes 1-6, you can skip steps by calling --step# to go to the step you care about, i.e. if you wanted to just run annotations on a file you could call --step5 to run annotations on files. Note that the scripts are designed to be used with the pipeline, run straight through, so if you want to skip steps you need to know how to lable files for the pipeline to work appropriately.
A sample_prefix, a unique prefix for the sample you are working with, is now required for each call to submit_all.sh. If you need to run for multiple samples, run submit_all.sh from step 0 for the first sample you are working with, then for subsequent runs use --step3 with your command, since you do not need to make germline calls or bam files again. 

Currently, in order to do somatic variant calling, you need to supply --fastq_dir, --normal_sample_name (the name of the normal control sample to compare suspected mutated samples with), --sample_prefix (an identifier for the sample you are using, doesn't matter that much if all the fastq files in the directory are from the same sample but still necessary to supply). For Scan2 to run properly also require supplying --cross_dir, a directory with only bam files with a bulk sample with the prefix "bulk" and non-bulk single cell bams. Scan2 will not run properly without this option. If you do not supply --normal_sample_name, somatic variant calling will be skipped but a germline variant call will still be done, which will attempt joint genotyping as well. If you don't specify --sample-prefix, all samples will be run together as if they were from one patient.

Important Options:
-By setting "--exome" can set to use exome regions, which should allow the pipeline to run much faster

SHORTCUTS:
-By setting "--skip_bam 1", you can skip bam_construciton, performing the entire pipeline from germline variant calling
-By setting "step#" where # is the step you want to go to, you can start the script from the appropriate step. Note that ginkgo and summarize metrics currently have prefix 2 even though they are run in --step3
-By setting "--only_bam 'yes'", you can make the pipeline run bam construction for samples with the assigned sample_prefix, note that if you do not set only_bam, bam files will be constructed and germline calls done for every sample in the fastq_dir, but variant calling and annotations will not be performed, if you do this be careful to not rerun bam construction on subsequent runs for subsequent samples

Step1: Bam construction | 1_sentieon_bam_construction
Inputs: fastq directory with fastq files with correct R1 and R2_suffixes
Outputs: Deduped realigned recaliberated Bam files with the suffix: .recalibrated_realigned_deduped_sorted.bam, germline call files with the suffix .g.vcf

Step1: Germline variant calling | (Currently done in 1_sentieon_bam_construction, will likely change this later!)
Inputs: Deduped realigned recaliberated bam files
Outputs: .g.vcf files from germline calling, need to be joint genotyped

Step1: QC Metrics from bamtools | 1_sentieon_bam_construction
Inputs: Deduped realigned recalibrated bam files
Outputs: Various metric reports

Step2: Scan2 mutburden and mutsig | 2_scan2.sh
Inputs: deduped realigned recalibrated bam files
Outputs: annotated vcfs containing mutational signature for high specificity variant calling, .tsv's containing mutburden info, candidates tsv. Found in Scan2_Results_[Project Name]/results/

Step3: Summarise QC metrics | 2_summarize_metrics.sh
Inputs: Outputs from QC metrics
Outputs: QC Metrics summaries (pdfs etc.), merged metrics tsv's
Options: --targeted option can be flagged if working with targeted exome sequencing rather than WGS

Step3: Ginkgo | 2_gingko_cnv.sh
Inputs: Deduped realigned recalibrated bam file (deduped realigned files will do)
Outputs: Reports on copy number variation

Step3: Somatic variant calling | 3_somatic_variant_calling.sh
Inputs: Deduped realigned recaliberated bam files, the sample prefix
Outputs: _variant.vcf files from somatic calling

Step4: Merging variant called files | 4_vcf_concat.sh and 4_joint_genotyping.sh
Inputs: either all files with sample prefix and _variant.vcf as a suffix, or all files with sample prefix and .g.vcf suffix for joint genotyping
Outputs: Merged vcf file

Step5: Annotating | 5_annovar.sh
Inputs: Merged vcf files, labeled with *merged* somewhere in the name
Outputs: Various, most important is _multianno.tsv which will have your info about variants
NOTE: Currently annotations include rows labeled as coming from normal sample in column "SAMPLE", pretty sure these rows are copied erroneously and the calls are indeed somatic variant calls for the experimental sample.

Step6: Manta structual variant calling | 6_manta_sv.sh
Inputs: deduped realigned recalibrated bam files
Outputs: Folder with pdf figures of SV calling

Sentieon instructions
Sentieon loading and license
Refer to email with subject "FW: [SRCC #57081] SCAN2 performance"
Sentieon instruction manual
https://support.sentieon.com/manual/introduction/intro/
Sentieon HPC cluster parallelization instructions
https://github.com/Sentieon/Sentieon-cwl
Github running instructions
https://github.com/Sentieon/sentieon-dnascope-ml
Test data location
Miniseq WGS run
/oak/stanford/groups/cgawad/Cancer_Studies/SC_MRD_Immunogenotyping/210921_MRD_BALL_4084Bulk_CNV/
Nova-seq WGS run
/oak/stanford/groups/cgawad/Cancer_Studies/SC_MRD_Immunogenotyping/2021-03-15_CellReport_WGS/
