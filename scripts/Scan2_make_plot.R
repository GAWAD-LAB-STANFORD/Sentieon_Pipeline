#!/usr/bin/env Rscript

#insert argument parsing for rda_path here

library(scan2)
load(rda_path)
snvs <- results@gatk[pass == TRUE & muttype == 'snv']
