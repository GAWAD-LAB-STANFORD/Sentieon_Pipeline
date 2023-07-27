suppressPackageStartupMessages({
  library(BSgenome.Hsapiens.UCSC.hg38)
  library(karyoploteR)
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
control_filename <- args[1]
experimental_filename <- args[2]
project <- args[3]


# Arguments, theme, data input, and preprocessing ------------------------------------------------------
experimental_df <- read_tsv(experimental_filename) %>%
  dplyr::rename(experimental_frequency = frequency)
control_df <- read_tsv(control_filename) %>%
  dplyr::rename(control_frequency = frequency)


# Analysis ------------------------------------------------------
matched_df <- left_join(control_df, experimental_df, by = c("chr", "start")) %>% 
  drop_na() %>% 
  mutate(end = start + 1) %>% 
  select(chr, start, end, control_frequency, experimental_frequency) %>%
  filter(experimental_frequency >= 0.8)
matched_gr <- toGRanges(as.data.frame(matched_df))
rm(experimental_df, control_df, matched_df)


# Plot function results ------------------------------------------------------
### Allele frequency for Experimental and Control
pdf(sprintf("%s.fig_chromosomal_allele_frequency.pdf", project), width = 10, height = 20)
kp <- plotKaryotype(plot.type=1, genome = "hg38")
kpDataBackground(kp, data.panel = 1)
kpAbline(kp, data.panel = 1, h = c(0.25, 0.5, 0.75, 1), col="gray50")
kpAxis(kp, data.panel = 1, side = 1, numticks = 1, tick.pos = c(1), labels = c(1), cex = 0.75)
kpPoints(kp, data.panel = 1, data = matched_gr, y = matched_gr$experimental_frequency, col = "red")
kpPoints(kp, data.panel = 1, data = matched_gr, y = matched_gr$control_frequency, col = "darkgreen")
kpLines(kp, data.panel = 1, data = matched_gr, y = matched_gr$experimental_frequency, col = "red")
kpLines(kp, data.panel = 1, data = matched_gr, y = matched_gr$control_frequency, col = "darkgreen")
kpAddBaseNumbers(kp, tick.dist = 10000000, tick.len = 10, tick.col = "black", cex = 0.5, minor.tick.dist = 1000000, minor.tick.len = 5, minor.tick.col = "gray")
kpAddMainTitle(kp, "Experimental AF (red) >= 0.8 that match Control AF (green)")
dev.off()
cat("Done plotting allele frequency\n")