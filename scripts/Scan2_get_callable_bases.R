#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1)
    stop('usage: get_callable_bases.R out.tsv rda1 [ rda2 ... rdaN ]')


out.tsv <- args[1]
rdas <- args[-1]

if (file.exists(out.tsv))
    stop('output file ', out.tsv, ' already exists, please delete it first')


cat('loading', length(rdas), 'summary files\n')

load(rdas[1]) # just to get sample name
sample.id <- names(dimnames(dptab)[1])

# Sum over all chunked tables (overwrites dptab from above)
dptab <- Reduce('+', lapply(rdas, function(infile) {
    load(infile)
    dptab
}))

# counting starts from dp=0, so rows 1-6 correspond to DP=0-5
# rows are single cell
# columns are bulk
allsites <- sum(dptab)
just.sc <- sum(colSums(dptab[-(1:6),]))
just.bulk  <- sum(colSums(dptab[,-(1:11)]))
dptab <- dptab[-(1:6),]
dptab <- dptab[,-(1:11)]
#dp.tab <- dptab[,-(1:6)]
#dp.tab <- dptab[-(1:11),]

cat('SC DP >= 6:', just.sc, 'bases\n')
cat('BULK DP >= 11:', just.bulk, 'bases\n')
cat(sprintf("bases passing SC DP >= 6 and BULK DP >= 11: %.0f out of %.0f total bases (%.1f%%)\n",
    sum(dptab),round(allsites), 100*sum(dptab)/allsites))

writeLines(c(
    'sample\tcbp',
    paste0(sample.id, '\t', sum(dptab))), con=out.tsv)
