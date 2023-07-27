suppressPackageStartupMessages({
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
project <- args[2]

ggplot_theme <- theme(axis.line.y = element_line(size=.1,color = "black"), axis.line.x = element_line(size=.1,color = "black"),
                      axis.text.x = element_text(angle = 45, hjust = 1, size=10, lineheight=0.2, color="black"),
                      panel.grid.major = element_line(color = "black"), panel.background = element_rect(fill="white"),
                      panel.grid.major.x = element_line(size=.1, color="grey"), panel.grid.major.y = element_blank(), 
                      plot.title = element_text(size=15), legend.text=element_text(size=8))

# Variant class clean up ------------------------------------------------------------------
df <- read.delim(input_file) %>%
  mutate(variant = sprintf("%s>%s", ref, alt), variant_class = "Other") %>%
  mutate(variant_class = ifelse(variant == "A>C", "T>G|A>C", variant_class),
         variant_class = ifelse(variant == "T>G", "T>G|A>C", variant_class),
         variant_class = ifelse(variant == "A>G", "T>C|A>G", variant_class),
         variant_class = ifelse(variant == "T>C", "T>C|A>G", variant_class),
         variant_class = ifelse(variant == "A>T", "T>A|A>T", variant_class),
         variant_class = ifelse(variant == "T>A", "T>A|A>T", variant_class),
         variant_class = ifelse(variant == "C>A", "C>A|G>T", variant_class),
         variant_class = ifelse(variant == "G>T", "C>A|G>T", variant_class),
         variant_class = ifelse(variant == "C>G", "C>G|G>C", variant_class),
         variant_class = ifelse(variant == "G>C", "C>G|G>C", variant_class),
         variant_class = ifelse(variant == "C>T", "C>T|G>A", variant_class),
         variant_class = ifelse(variant == "G>A", "C>T|G>A", variant_class))


# Variant class plots per sample ------------------------------------------------------------------
per_sample_df <- df %>%
  mutate(total = sum(count)) %>%
  group_by(variant_class) %>%
  mutate(variant_class_total = sum(count)) %>%
  ungroup() %>%
  select(variant_class, total, variant_class_total, sample) %>%
  distinct_all() %>%
  group_by(variant_class) %>%
  mutate(variant_class_proportion = sum(variant_class_total)/total) %>%
  ungroup()

fig <- ggplot(per_sample_df, aes(x = sample, y = variant_class_proportion, fill = variant_class)) +
  geom_bar(stat = "identity") +
  ggplot_theme + theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(size=.1, color="grey")) +
  labs(x = "Sample", y = "Proportion of Variants", legend = "Variant Class") +
  geom_text(aes(label = variant_class), size = 3, color = "white", position = position_stack(vjust = 0.5))
ggsave(sprintf("%s.fig_variant_class_per_sample_stacked_barplot_innerlabels.pdf", project), fig, width = 11, height = 8)

fig <- ggplot(per_sample_df, aes(x = sample, y = variant_class_proportion, fill = variant_class)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  ggplot_theme + theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(size=.1, color="grey")) +
  labs(x = "Sample", y = "Proportion of Variants", legend = "Variant Class") +
  scale_y_continuous(limits = c(0, 1)) +
  geom_text(aes(label = variant_class), vjust = 1.6, color = "white", position = position_dodge(0.9), size=3)
ggsave(sprintf("%s.fig_variant_class_per_sample_sidebyside_barplot_innerlabels.pdf", project), fig, width = 20, height = 8)


# Variant class plots merged ------------------------------------------------------------------
merged_df <- df %>%
  mutate(project = project, total = sum(count)) %>%
  group_by(variant_class) %>%
  mutate(variant_class_total = sum(count)) %>%
  ungroup() %>%
  select(variant_class, total, variant_class_total, project) %>%
  distinct_all() %>%
  group_by(variant_class) %>%
  mutate(variant_class_proportion = sum(variant_class_total)/total) %>%
  ungroup()

fig <- ggplot(merged_df, aes(x = project, y = variant_class_proportion, fill = variant_class)) +
  geom_bar(stat = "identity") +
  ggplot_theme + theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(size=.1, color="grey")) +
  labs(x = "Project", y = "Proportion of Variants", legend = "Variant Class") +
  geom_text(aes(label = variant_class), size = 3, color = "white", position = position_stack(vjust = 0.5))
ggsave(sprintf("%s.fig_variant_class_merged_stacked_barplot_innerlabels.pdf", project), fig, width = 11, height = 8)

fig <- ggplot(merged_df, aes(x = project, y = variant_class_proportion, fill = variant_class)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  ggplot_theme + theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(size=.1, color="grey")) +
  labs(x = "Project", y = "Proportion of Variants", legend = "Variant Class") +
  scale_y_continuous(limits = c(0, 1)) +
  geom_text(aes(label = variant_class), vjust = 1.6, color = "white", position = position_dodge(0.9), size=3)
ggsave(sprintf("%s.fig_variant_class_merged_sidebyside_barplot_innerlabels.pdf", project), fig, width = 20, height = 8)