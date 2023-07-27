.libPaths("/home/groups/cgawad/miniconda3/envs/update_scan2/lib/R/library")

suppressPackageStartupMessages({
  library(scan2)
})

args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
output_file < args[2]

load(input_file)
snvs <- df(gt)
filtered <- snvs[snvs$static.filter & snvs$lysis.fdr <= 0.01 & snvs$mda.fdr <= 0.01,]
colnames(filtered)[1] <- "CHROM"
colnames(filtered)[2] <- "POS"
colnames(filtered)[4] <- "REF"
colnames(filtered)[5] <- "ALT"
write.table(filtered, output_file, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
