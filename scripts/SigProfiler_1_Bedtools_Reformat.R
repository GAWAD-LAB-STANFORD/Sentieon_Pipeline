suppressPackageStartupMessages({
  library(tidyverse)
  options(scipen=999)
})

args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
before_file <- args[2]
after_file <- args[3]

df <- read.delim(input_file)

df <- distinct_all(df, .keep_all = TRUE)

before <- df %>%
  mutate(chr = CHROM, start = POS - 2, end = POS - 1) %>%
  select(chr, start, end)
after <- df %>%
  mutate(chr = CHROM, start = POS, end = POS + 1) %>%
  select(chr, start, end)

write.table(before, before_file, sep ="\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(after, after_file, sep ="\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
