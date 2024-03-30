# Guide to Sentieon Pipeline

- [Purpose](#purpose)
- [How To Run](#how-to-run)
- [What It Does Exactly](#what-it-does-exactly)
- [Resources](#resources)

## Purpose
- This pipeline is built to call variants (CNVs, Indels, SNPs) and perform other analyses on Whole Genome, Whole Exome, or Gene Panels from paired fastq.gz files or BCL files

## How To Run
- All scripts are controlled by the master script, submit_all.sh
- To make job submission easier, use the submit_all.sh script to submit the master script
    - For help, use the *-h* or *--help* option like:

    ```bash
    sh submit_all.sh --help
    ```

- You can use ~ if your file or folder is in your home directory, but otherwise use absolute paths

- You can include '/' at the end of a directory path but you don't need to, either is fine:
    - /home/groups/cgawad/results/
    - /home/groups/cgawad/results

### submit_all.sh
- **Run this script in order to run the entire pipeline**
- Required arguments: -p/--project >arg<, and either -f/--fastq_dir >arg< or -r/--results_dir >arg<
    - Specify where your fastq.gz files are located (or will be put after if you opt for the auto-demultiplexing) using *-f* or *--fastq_dir* and/or specify where to output the results with *-r* or *--results_dir*
        - If you do not specify a fastq directory, the program will assume the fastq.gz files are in the results directory you specified, and will end the program if no fastq.gz files are found
        - If you do not specify a results directory, the program will make a new folder with the current date in the name within the fastq directory 
    - Specify the project name as a prefix for all final and summarized files with *-p* or *--project*

- Optional arguments: -s/--scratch_dir >arg<, --err_out_dir >arg<, --skip_scratch, -b/--run_dir >arg<, --sample_sheet >arg<, --skip_variant_call, --only_variant_call, --R1_suffix >arg<, --R2_suffix >arg<, --element, --skip_trimming, --rna, --bam_suffix >arg<, --normal_sample_name >arg<, --scan2, --cross_dir >arg<, --skip_panel >arg<, --exome, --targeted, --exome_bed_version >arg<, --panel_bed >arg<, --panel_interval_list >arg<, --manta, --ginkgo_mb_sizes >arg<, --slurm >arg<
    - If you want to specify a directory to perform all intermediate steps in, specify with *-s* or *--scratch_dir*
    - If you want to specify a directory to output the standard error and out print statements of all jobs to, specify with *--err_out_dir*
    - If you want to skip having the pipeline run intermediate steps in scratch, add *--skip_scratch*
    - If you want the script to demultiplex your BCL files into fastq.gz files, specify the run folder with *-b* or *--run_dir*. The program will look for a sample sheet called SampleSheet.csv in the first level within the run_dir or you can specify a different sample sheet with *--sample_sheet*. The program will make the fastq directory if it does not exist and tell you the sizes of undeteremined vs fully demultiplexed reads
    - If you only need to do a quality control (QC) run (only the first half of the pipeline), add *--skip_variant_call*
    - If you want to just call variants on already existing BAM files (only the second half of the pipeline), add *--only_variant_call*
    - If your read 1 and read 2 fastq.gz files differentiate themselves by some pattern other than _L001_R1_001.fastq.gz and _L001_R2_001.fastq.gz or _R1_001.fastq.gz and _R2_001.fastq.gz or _R1.fastq.gz and _R2.fastq.gz, specify with *--R1_suffix* and *--R2_suffix*
    - If you want to demultiplex Element type BCL files, add *--element*
    - If you don't want trimmomatic to run, add *--skip_trimming*
    - If you want to process RNA instead of DNA data, add *--rna* and the program will align the sequences using STAR instead of BWA
    - If your BAMs do not end in ".recalibrated_realigned_deduped_sorted.bam" then specify their suffix with *--bam_suffix*
    - If you want the pipeline to perform germline variant calling and/or Scan2, specify *--normal_sample_name*
    - If you want the pipeline to run Scan2, add *--scan2* **(CAUTION: still experimental with bugs)**
    - If you have a cross sample directory for Scan2, specify with *--cross_dir*
        - If you want Scan2 to skip a specific panel, specify with *--skip_panel*
        - If you want to run Scan2, you must specify a normal sample name with *--normal_sample_name* as above
    - If your data is whole exome sequencing instead of the default assumption of whole genome sequencing, add *--exome*
    - If your data is whole exome sequencing or gene panel sequencing instead of default assumption of whole genome sequencing, add *--targeted*
    - If you want to use another version of the whole exome targets BED file instead of the default version 1, specify with *--exome_bed_version*
    - If you want to further restrict the analysis to a smaller subset of genes than whole exome sequencing, you need to provide a bed file and interval list file using *--panel_bed* and *--panel_interval_list*
    - If you want the pipeline to run Manta, add *--manta*
    - If you want to specify multiple Ginkgo CNV runs in addition to the default 5M read run, specify millions of reads (aka megabases) separated by commas and don't include the M or spaces. All Ginkgo CNV runs will only be run for WGS.
        - Example for 10 and 20 million reads:
        ```
        ... --ginkgo_mb_sizes 10,20
        ```
    - Besides the already implemented job name and standard error and output print statements, you can specify additional slurm commands for the **very first** pipeline submission job following the use of the *--slurm* option. It will not be passed along to future jobs within the pipeline run. If you use this option, **make sure it is the last one you use**
        - A useful example would be setting a future time to run the pipeline and asking for email notifications like so:

        ```
        ... --slurm --begin=now+12hours --mail-type=ALL 
        ```

- Get some example submissions by using *-h* or *--help* options like:

    ```bash
    sh submit_all.sh --help
    ```
    
- Defaults:
    - If no fastq_dir specified, uses results_dir
    - If no results_dir specified, makes new directory in fastq_dir
    - scratch_dir: /scratch/groups/cgawad/date_project_Scratch
    - sample_sheet: SampleSheet.csv
    - R1_suffix: _L001_R1_001.fastq.gz or _R1_001.fastq.gz or _R1.fastq.gz
    - R2_suffix: _L001_R2_001.fastq.gz or _R2_001.fastq.gz or _R2.fastq.gz
    - Will not assume element BCL/fastq data
    - Will run trimmomatic
    - WGS assumed
    - Will not run Scan2
    - Will skip Scan2 panel
    - Will run Ginkgo on 5M read downsampled BAMs for WGS
    - Other Ginkgo runs will only be run for WGS
    - Will not run manta
    - Exome BED version: 1

## Resources

### Creating input files: BED interval and targets interval list
- If targets.bed file (aka BED interval file) is indexed based on
    another reference genome
    - Use UCSC genome LifeOver tool to change indexing
        - https://genome.ucsc.edu/cgi-bin/hgLiftOver
    - Common errors that occur without matching genome indexing include:
        - differing chromosome lengths during creation of .interval_list file
        - unusually high number of uncovered targets after bedtools coverage analysis
        - .sai file creating errors in indexing when run with mismatching genome or .interval_list during bedtoolscoverage analysis
- If .fai/.genome file does not exist
    - Create .fai/.genome file from .fasta reference genome

    ```bash
    samtools faidx ref_genome.fasta
    ```

    - Separate out first two columns to new file

    ```bash
    awk -v OFS='\t' {'print $1,$2'} ref_genome.fasta.fai > ref_genome.genome
    ```

    - Source: https://www.biostars.org/p/70795/
- If .dict file does not exist
    - Create .dict with Picard from .fasta reference genome

    ```bash
    java -jar picard.jar CreateSequenceDictionary R=ref_genome.fasta O=ref_genome.dict
    ```
- If .interval_list file (aka Targets Interval file) does not exist
    - Sort targets.bed file (aka BED Interval file) if needed

    ```bash
    sort -V -k1,1 -k2,2 targets.bed > targets_sorted.bed
    ```

    - Create .interval_list with Picard from .dict file

    ```bash
    java -jar picard.jar BedToIntervalList I=targets.bed O=targets.interval_list SD=ref_genome.dict SORT=true
    ```

    - Notice: the Picard syntax may be changing in the near future