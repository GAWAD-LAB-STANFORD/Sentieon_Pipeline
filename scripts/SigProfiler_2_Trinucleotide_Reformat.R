suppressPackageStartupMessages({
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
before_file <- args[2]
after_file <- args[3]
output_file <- args[4]
mutation_types_file <- args[5]

df <- read.delim(input_file)
before <- read.delim(before_file, header = FALSE) %>%
  rename(CHROM = V1, start = V2, end = V3, Ref = V4) %>%
  mutate(Preceeding_base = Ref, POS = start + 2) %>%
  select(-Ref, -start, -end)
after <- read.delim(after_file, header = FALSE) %>%
  rename(CHROM = V1, start = V2, end = V3, Ref = V4) %>%
  mutate(Succeeding_base = Ref, POS = start) %>%
  select(-Ref, -start, -end)

trint <- left_join(df, before, by = c("CHROM", "POS"))
trint <- left_join(trint, after, by = c("CHROM", "POS"))

wild <- trint %>%
  mutate(`Mutation.Types` = sprintf("%s[%s>%s]%s", Preceeding_base, REF, ALT, Succeeding_base)) %>%
  select(`Mutation.Types`) %>%
  group_by(`Mutation.Types`) %>%
  summarize(Count = n()) %>%
  ungroup()

mut_types <- read.delim(mutation_types_file)
no_wild <- left_join(mut_types, wild, by = c("Mutation.Types"))
no_wild[is.na(no_wild)] <- 0

write_tsv(no_wild, output_file)