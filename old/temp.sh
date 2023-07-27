#!/bin/bash
#
#SBATCH --job-name=temp
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

for chr in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y; do
        curl https://storage.googleapis.com/gcp-public-data--gnomad/release/3.1/vcf/genomes/gnomad.genomes.v3.1.sites.chr$chr.vcf.bgz \
           | bcftools annotate -x ^INFO/AF,INFO/AC  - | bcftools norm -m +any -Oz -o tmp_OUTPUT.chr$chr.vcf.gz
        file_list="$file_list tmp_OUTPUT.chr$chr.vcf.gz"
done
bcftools concat -Oz -o OUTPUT.vcf.gz $file_list && bcftools index -t OUTPUT.vcf.gz
rm $file_list
