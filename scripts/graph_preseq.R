suppressPackageStartupMessages({
  library(tidyverse)
  library(gridExtra)
  library(directlabels)
})

args <- commandArgs(trailingOnly = TRUE)
merged_preseq_filename <- args[1]
prefix <- args[2]
suffix <- args[3]

# Format prefix and suffix ------------------------------------------------------
if (is.na(prefix)) {
  prefix <- ""
} else {
  prefix <- sprintf("%s.", prefix)
}
if (is.na(suffix)) {
  end_message <- "Graphed coverage\n"
  suffix <- ""
} else {
  end_message <- sprintf("Graphed %s coverage\n", suffix)
  suffix <- sprintf("_%s", suffix)
}


# Variables ------------------------------------------------------
merged_preseq_df <- read.delim(merged_preseq_filename)
samples <- unique(merged_preseq_df$SAMPLE)
plot_height <- (length(samples)/10)+7.5
plot_width <- (length(samples)/30)+15
legend_columns <- ceiling(length(samples)/60)

ggplot_theme <- theme(axis.line.y = element_line(size=.1,color = "black"), axis.line.x = element_line(size=.1,color = "black"),
                      axis.text.x = element_text(angle = 45, hjust = 1, size=10, lineheight=0.2, color="black"),
                      panel.grid.major = element_line(color = "black"), panel.background = element_rect(fill="white"),
                      panel.grid.major.x = element_blank(), panel.grid.major.y = element_blank(), 
                      plot.title = element_text(size=15), legend.text=element_text(size=8))
# options(scipen=999)


# Plotting ------------------------------------------------------
plot1 <- ggplot(merged_preseq_df, aes(x=TOTAL_BASES, y=EXPECTED_COVERED_BASES, color = SAMPLE)) + 
  geom_line() + labs(title = "PreSeq Future Coverage") + ggplot_theme + theme(legend.position="none") +
  geom_dl(aes(label = SAMPLE),  method = list("last.points", cex = 0.8, hjust=1.2, vjust=1.2))
ggsave(sprintf("%sfig_preseq_future_coverage_direct_labels%s.pdf", prefix, suffix), plot1, width = plot_width, height = plot_height)

plot1 <- ggplot(merged_preseq_df, aes(x=TOTAL_BASES, y=EXPECTED_COVERED_BASES, color = SAMPLE)) + 
  geom_line() + labs(title = "PreSeq Future Coverage") + ggplot_theme + 
  guides(color = guide_legend(ncol = legend_columns))
legend <- cowplot::get_legend(plot1)
plot1 <- plot1 + theme(legend.position="none")
pdf(sprintf("%sfig_preseq_future_coverage%s.pdf", prefix, suffix), width = plot_width, height = plot_height)
grid.arrange(plot1, legend, layout_matrix = matrix(c(1, 1, 2), nrow = 1))
dev.off()
cat("Graphed preseq future coverage\n")
