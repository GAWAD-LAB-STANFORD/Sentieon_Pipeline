suppressPackageStartupMessages({
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
input_filename <- args[1]
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

# Data frame manipulation functions ------------------------------------------------------
parse_long_sample_name <- function(df) {
  if (str_count(df$sample, "_")[1] == 6) {
    df <- df %>%
      separate(sample, sep = "_", c("project", "cell_type", "tissue_origin", "sequencing_type", "TBID", "sample", "sample_number")) %>%
      mutate(sample_number = str_remove(sample_number, "S")) 
  }
  return(df)
}
summarize_stats <- function(data) {
  medians <- data %>% group_by(sample) %>% summarize(sample_median_breadth = median(breadth)) %>% ungroup()
  data <- left_join(data, medians, by = "sample")
  medians <- data %>% group_by(sample) %>% summarize(sample_median_depth = median(depth)) %>% ungroup()
  data <- left_join(data, medians, by = "sample")
  return(data)
}
ggplot_theme <- theme(axis.line.y = element_line(size=.1,color = "black"), axis.line.x = element_line(size=.1,color = "black"),
                      axis.text.x = element_text(angle = 45, hjust = 1, size=10, lineheight=0.2, color="black"),
                      panel.grid.major = element_line(color = "black"), panel.background = element_rect(fill="white"),
                      panel.grid.major.x = element_line(size=.1,color = "black"), panel.grid.major.y = element_line(size=.1,color = "black"), 
                      plot.title = element_text(size=15), legend.position = "none",)

# Coverage plotting functions ------------------------------------------------------
coverage_scatter <- function(data, prefix, suffix) {
  plot1 <- ggplot(data, aes(depth, breadth, color = chr)) + ggtitle("Coverage Scatter") +
    geom_point() + facet_wrap(~ sample) + ggplot_theme +
    scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
    geom_text(label = data$chr, size = 2.5, hjust = 0, vjust = 2)
  ggsave(sprintf("%sfig_coverage_scatter%s.pdf", prefix, suffix), plot = plot1, width = 11, height = 8.5)
}
coverage_depth_density <- function(data, prefix, suffix) {
  plot1 <- ggplot(data, aes(depth)) + ggtitle("Depth of Coverage - medians labeled") + 
    geom_density(aes(depth, group = sample, fill = sample), adjust = 2, alpha = 0.5) + ggplot_theme +
    facet_wrap(~ sample) + geom_vline(aes(xintercept = sample_median_depth, color = sample), linetype = "dashed") +
    scale_x_continuous(expand = c(0, 0)) + geom_text(aes(x = -Inf, y = -Inf, label = sprintf("%s",sample_median_depth)), hjust = -0.1, vjust = -1) 
  ggsave(sprintf("%sfig_coverage_depth_density%s.pdf", prefix, suffix), plot = plot1, width = 11, height = 8.5)
}
coverage_breadth_density <- function(data, prefix, suffix) {
  plot1 <- ggplot(data, aes(breadth)) + ggtitle("Breadth of Coverage - medians labeled") + 
    geom_density(aes(breadth, group = sample, fill = sample), adjust = 2, alpha = 0.5) + ggplot_theme +
    facet_wrap(~ sample) + geom_vline(aes(xintercept=sample_median_breadth, color=sample), linetype="dashed") +
    scale_x_continuous(expand = c(0, 0), limits = c(0, 1), breaks = c(0.25, 0.5, 0.75, 1.0)) +
    geom_text(aes(x = -Inf, y = -Inf, label = sprintf("%s",sample_median_breadth)), hjust = -0.1, vjust = -1)
  ggsave(sprintf("%sfig_coverage_breadth_density%s.pdf", prefix, suffix), plot = plot1, width = 11, height = 8.5)
}

# Main ------------------------------------------------------
if (file.exists(input_filename)) {
  df <- read.table(input_filename, sep = "\t", header = TRUE, stringsAsFactors = FALSE, fill = TRUE)
  df <- df %>%
    gather(key = "variable", value = "value", -chr, -start, -end, -bed_length) %>%
    mutate(sample = ifelse(str_detect(variable, "_depth"), gsub("_depth", "", variable), gsub("_breadth", "", variable))) %>%
    mutate(variable = ifelse(str_detect(variable, "_depth"), "depth", "breadth")) %>%
    pivot_wider(names_from = variable, values_from = value) %>%
    unnest(c(depth, breadth))
  df <- na.omit(df)
  df <- parse_long_sample_name(df)
  df$depth <- as.numeric(as.character(df$depth))
  df$breadth <- as.numeric(as.character(df$breadth))
  df <- summarize_stats(df)
  coverage_depth_density(df, prefix, suffix)
  coverage_breadth_density(df, prefix, suffix)
  coverage_scatter(df, prefix, suffix)
  cat(end_message)
} else {
  cat(sprintf("%s does not exist\n", input_filename))
}