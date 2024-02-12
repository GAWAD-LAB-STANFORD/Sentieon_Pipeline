## load libraries
library(dplyr)
library(ggplot2)
library(tidyverse)
library(MetBrewer)
library(optparse)
library(pheatmap)

## Arguments
#
option_list = list(
  make_option(c("--project"), type="character", default=NULL,
              help="REQUIRED", metavar="character"),
  make_option(c("--directory"), type="character", default=NULL,
              help="REQUIRED", metavar="character"),
  make_option(c("--snv_filename"), type="character", default=NULL,
              help="REQUIRED", metavar="character"),
  make_option(c("--indel_filename"), type="character", default=NULL,
              help="REQUIRED", metavar="character"),
  make_option(c("--exome"), action = "store_true", default = FALSE,
              help="optional [default = %default]")
); 

opt <- parse_args(OptionParser(option_list=option_list))

print(opt)

if (is.null(opt$project) || is.null(opt$directory) || is.null(opt$snv_filename) || is.null(opt$indel_filename)) {
  stop("You must specify all required options. Use --help to get help.")
}

directory <- opt$directory 
snvs <- opt$snv_filename 
indels <- opt$indel_filename 
exome <- opt$exome
project <- opt$project




# example command:
# Rscript args_post_pipeline_heatmap.R --project 'CARTPt04' --directory '/Users/shawnschulz/01_research_projects/01_cart_project/CART04' --snv_filename '01_cart_04_clonal_somatic_calls.tsv' --indel_filename '01_cartpt04_final_clonal_indel_calls.tsv' --exome 

## ggplot themes and variable declarations

ggplot_theme <- theme(axis.line.y = element_line(size=.1,color = "black"), axis.text.x = element_text(angle = 45, hjust = 1, size=10, lineheight=0.2,         color="black"),
                      panel.grid.major = element_line(color = "black"), legend.text=element_text(size=15), 
                      panel.background = element_rect(fill="white"), panel.grid.major.x = element_blank() )

##can uncomment these and comment arguments for testing
# directory <- '/scratch/users/sschulz/CARTPt04_Scan2/01_final_outputs'
# snvs <- '01_final_clonal_somatic_calls.tsv' 
# indels <- '01_final_clonal_indel_calls.tsv' 
# exome <- TRUE
# project <- 'CARTPt04'

### Function declarations ###

readTable <- function(directory, filename) {
    filepath = paste0(directory, '/', filename)
    df <-read.table(filepath, header=TRUE, sep="\t", fill = TRUE, na.strings = "NA")
    return(df)
}

addColumns <- function(df) {
  df <- separate(df, 'SAMPLE', into=c("SAMPLE_long", "SAMPLE_short"), sep="_S")
  print('parsed sample name')
  df <- separate(df, 'AD', into=c("AD_ref", "AD_alt"), sep=",")
  print('seperated AD')
  df$'genotype' = paste0(df$'Gene.refGene','_', df$'CHROM', '_', df$'POS','_', df$'Func.refGene')
  print('genotype column created')
  df$'VAF' <- as.numeric(df$'AD_alt')/(as.numeric(df$'AD_alt') + as.numeric(df$'AD_ref'))
  print('VAF column created')
  df <- df %>% filter(MQ > 59)
  print('filtered mq')
  if (exome){
    df <- df %>% subset(!(Func.refGene %in% c('intronic')))
  }
  print('removed intronic genes')
  return(df)
  }

makeMatrix <- function(df, name1, name2, values) {
  mat <- df[, c(name1, name2, values)]
  mat <- na.omit(mat)
  mat <- pivot_wider(mat, names_from = name2, values_from = values)
  return(mat)
}

mergeMatrix <- function(df1, df2){
    merged = merge(df1,df2, by.x='SAMPLE_long')
    merged[is.na(merged)] <- 0
    merged <- data.frame(merged[,-1], row.names = merged[,1])
    return(merged)
}

makeHeatmap <- function(mat){
  return(pheatmap(mat, legend_breaks = c(0.2, 0.4, 0.6, 0.8, 1), 
main = "", legend_labels = c("0.2", "0.4", "0.6", "0.8","1", "VAF\n"),
legend = TRUE))
}

savePDF <- function(fn, mat, directory){
    pdf(file=paste0(directory, '/', fn), height=12, width=15)
    
    print(paste0('we are making pdf at: ', directory, '/', fn))
    
    pheatmap(mat, legend_breaks = c(0.2, 0.4, 0.6, 0.8, 1), 
            main = "", legend_labels = c("0.2", "0.4", "0.6", "0.8", "VAF\n"),
            legend = TRUE)
    #pheatmap(mat)
    dev.off()
}


### Format the clonal SNV file ###


### Format the clonal indel file ###

create_is_mutated_column <- function(df) {
  df <- df %>%
      mutate(is_mutated = ifelse(df$DP.1 > 4 & df$AD_alt > 1, 1, 0))
        return(df)
        }



### Use pheatmap to graph VAFs of both togehter ###
## testing stuff ##
snv_df <- readTable(directory, snvs)
indel_df <- readTable(directory, indels)
snv_df_updated <- addColumns(snv_df)
indel_df_updated <- addColumns(indel_df)
snv_premat_df <- create_is_mutated_column(snv_df_updated)
write.table(snv_premat_df, file=paste0(directory,"/snv_premat_df.csv"), sep = ",", row.names=FALSE)
indel_premat_df <- create_is_mutated_column(indel_df_updated)
mat <- makeMatrix(snv_premat_df, 'SAMPLE_long', 'genotype', 'is_mutated')
mat2 <- makeMatrix(indel_premat_df, 'SAMPLE_long', 'genotype', 'is_mutated')
test_merged <- mergeMatrix(mat, mat2)
library(grid)

#savePDF(paste0('01_',project, '_vaf_heatmap.pdf'), test_merged, directory)


library(ComplexHeatmap)

library(grid)

library(dendextend)

library(RColorBrewer)

library(circlize)

col_fun = structure(c("#978f8f", "#b2182b"), names = c(0,1))

test_merged <- as.matrix(apply(test_merged, 1:2, as.numeric))

#enforce no rows with all 0's, these can appear in data because "germline" sample is included in data ("germline" should have no reads as somatic mutations). additionally its possible (although usually unlikely) that other non-germline cells do not have any reads for any after filtering

#we want to save the sample names of rows with all zeros so we can add them back in as empty rows into the heatmap after performing jaccard analysis. I think its fine to group these together at the top even if they are not reflected in the tree, probably preferable actaully to not show them as a part of the clustering


#remove the rows
test_merged <- test_merged[rowSums(test_merged[])>0,]
print(test_merged)

write.table(test_merged,file=paste0(directory,"/vaf_heatmap_matrix.csv"),sep=",")


library(vegan)
data.dist <- vegdist(test_merged, method = "jaccard")
row.clus <- hclust(data.dist, "ward.D")
data.dist.g <- vegdist(t(test_merged), method = "jaccard")
col.clus <- hclust(data.dist.g, "ward")

#width and height of the pdf is the width and height of the plot + some extra mm for wiggle room
pdf(file=paste0(directory, "/01_",project, "_vaf_heatmap.pdf"), height = nrow(test_merged)*0.04 * 3 + 5, width = ncol(test_merged)*0.04 * 6 + 10)

hm <- ComplexHeatmap::Heatmap(test_merged, col=col_fun, width = ncol(test_merged)*unit(6, "mm"), 
    height = nrow(test_merged)*unit(3, "mm"), name="Mutation Present", column_names_gp = grid::gpar(fontsize = 8),
      row_names_gp = grid::gpar(fontsize = 8),
        layer_fun = function(j, i, x, y, width, height, fill) {
              if (TRUE) {
                  grid.rect(x = x, y = y, width = width, height = height,
                                default.units = "native", just = "center",
                                              gp = gpar(lwd = 1, col = "white", fill = NA))

                                                }
                                                  },
                                                    cluster_rows=row.clus,
                                                      cluster_columns=col.clus
                                                        )

ComplexHeatmap::draw(hm,  heatmap_legend_side = "left")

dev.off()


