rm(list=ls())
#########https://github.com/raerose01/deconstructSigs#############
library(deconstructSigs) #<- bioconductor(?)

suppressPackageStartupMessages({
  library(tidyverse)
})
library(ggplot2)
library(reshape2)
library(dplyr)
library(sigminer) #<- bioconductor
library(maftools) #<- bioconductor 
library(NMF)
library(MetBrewer)
library(BSgenome.Hsapiens.UCSC.hg38) #<- bioconductor

args <- commandArgs(trailingOnly = TRUE)
results <- args[1] #<- i'm lazy add a slash to the end of this either while inputting or before
tsv <- args[2] #<- tsv should be absolute path and file name

setwd(results)
load(file = "/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/signatures.COSMIC_v3.3.1_SBS_GRCh38.rda") 
 ### <- make sure to put this in a good place in reference files
sigpro<-sig

base<-c("A","T","G","C")

fn = tsv

### get an input compatible with deconstruct sigs
df<-read.table(fn ,sep = "\t", header=TRUE)

##make sure only using rows for which mutation is actually there, im gonna use the VAF > 40% and DP > 10 filter but might want to 
#add additional filters to only
#include less noisy mutations in mutsig

df <- separate(data = df, col = AD, into = c("ref_allele_count", "alt_allele_count"), sep = "\\,")
df$alt_allele_count <- as.integer(df$alt_allele_count)
df$ref_allele_count <- as.integer(df$ref_allele_count)
vaf <- df$alt_allele_count / (df$ref_allele_count + df$alt_allele_count)
vaf[is.na(vaf)] <- 0
df$VAF <- vaf

##format for deconstructsigs

head(sample.mut.ref)
df.mut <- df[df$VAF > 0.4,]
df.mut <- df.mut[df.mut$DP.1 > 10,]
df.mut <- df.mut %>%
  select(SAMPLE, everything())
df.mut <- df.mut %>% subset( select = -c(ID))
df.mut <- df.mut %>% subset(select = 1:5)
df.mut

sigs.input <- mut.to.sigs.input(mut.ref = df.mut, 
                                sample.id = "SAMPLE", 
                                chr = "CHROM", 
                                pos = "POS", 
                                ref = "REF", 
                                alt = "ALT",
                                bsg = BSgenome.Hsapiens.UCSC.hg38)


# make histograms for each individually
# THIS IS NOT WORKING AT ALL
#for (sample in unique(df.mut$SAMPLE)){
#  print(sample)
#  temp <- whichSignatures(tumor.ref = sigs.input,
#                          signatures.ref = sigpro, 
#                          contexts.needed = TRUE,
#                          sample.id = sample)
#  pdf(file = paste0(results, "mutsig_plot_bar", "_", sample, ".pdf"),   # The directory you want to save the file in
#      width = 8, # The width of the plot in inches
#      height = 8) # The height of the plot in inches
#  
#  tryCatch(
#    {
#      
#      ## WHY DOES THIS NOT WORK??????
#      plotSignatures(temp, sub = sample)
#    },
#    error = function(e) {
#      # If an error occurs, print a message but continue to next iteration
#      cat(paste0("Error occurred while plotting signatures for sample ", sample, ":\n", conditionMessage(e), "\n"))
#    }
#  )
#  dev.off()
#  
#}
#
##make the stacked bar plots for each indivdually

for(sample in unique(df.mut$SAMPLE)) {
  temp <- whichSignatures(tumor.ref = sigs.input,
                          signatures.ref = sigpro, 
                          contexts.needed = TRUE,
                          sample.id = sample)
  df <- temp$weights
  #df<-df[, which(colSums(df) != 0)]
  df$Sample<-rownames(df)
  df_L<-gather(df, key='SigProf', value = 'Percentage',-Sample)
  df_L<-filter(df_L, !Percentage==0)
  if(all(df_L=0)){
    print(paste0("skipping", " ", sample))
    next
  }
  print(paste0("not skipping", " ", sample))
  pdf(file = paste0(results, "mutsig_plot_stacked", "_", sample, ".pdf"),   # The directory you want to save the file in
      width = 8, # The width of the plot in inches
      height = 8) # The height of the plot in inches
  
  
  print(ggplot(df_L, aes(fill =SigProf, y=Percentage, x=Sample),label =SigProf ) + 
    geom_bar(position="stack", stat="identity")+
    scale_fill_manual(values=met.brewer("Signac", 38))+
    geom_text(aes(label =SigProf),position = position_stack(vjust = 0.5), size = 3)+
    theme_minimal()+
    theme(panel.grid = element_line(linetype = 2))+
    theme(panel.grid.major.x = element_blank(),
          panel.grid.minor.x = element_blank())+
    labs(title="Signatures cosmic v3.3" ,x=" ", y = "Percentage")+
    theme(axis.text.x = element_text( vjust = 0.5,hjust=0.6))+
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))+
    theme(axis.text.x = element_text(face="bold",
                                     size=8),
          axis.text.y = element_text(face="bold", 
                                     size=10)))

  dev.off()
  
  
  
}

## make a merged stacked bar chart
df <- data.frame()

for (sample in unique(df.mut$SAMPLE)){
  temp <- whichSignatures(tumor.ref = sigs.input,
                  signatures.ref = sigpro, 
                  contexts.needed = TRUE,
                  sample.id = sample)
  
  df <- rbind(df, temp$weights)
  
}

df<-df[, which(colSums(df) != 0)]
df$Sample<-rownames(df)
df_L<-gather(df, key='SigProf', value = 'Percentage',-Sample)
df_L<-filter(df_L, !Percentage==0)

pdf(file = paste0(results, "01_combined_stacked_mutsig_plot.pdf"),   # The directory you want to save the file in
    width = 12, # The width of the plot in inches
    height = 12) # The height of the plot in inches


ggplot(df_L, aes(fill =SigProf, y=Percentage, x=Sample),label =SigProf ) + 
  geom_bar(position="stack", stat="identity")+
  scale_fill_manual(values=met.brewer("Signac", 38))+
  geom_text(aes(label =SigProf),position = position_stack(vjust = 0.5), size = 3)+
  theme_minimal()+
  theme(panel.grid = element_line(linetype = 2))+
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank())+
  labs(title="Signatures cosmic v3.3" ,x=" ", y = "Percentage")+
  theme(axis.text.x = element_text( vjust = 0.5,hjust=0.6))+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))+
  theme(axis.text.x = element_text(face="bold",
                                   size=8),
        axis.text.y = element_text(face="bold", 
                                   size=10))
dev.off()

