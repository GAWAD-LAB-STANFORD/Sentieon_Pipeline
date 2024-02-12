library(scan2)

args <- commandArgs(trailingOnly = TRUE)
rda <- args[1]
sample_path <- args[2]

load(rda)

tsv <- results@gatk[pass == TRUE]

#print(paste(c('this is the tsv: ', tsv), sep=""))

write.table(tsv, file=paste(sample_path,'_scan2.tsv',sep=""), row.names=FALSE, quote=FALSE, sep='\t')

burden <- results@mutburden

print("writing table now")
write.table(burden, file=paste(sample_path, '_mutburden.tsv', sep=""), row.names=FALSE, quote=FALSE, sep='\t')

rescue <- results@gatk[(pass == TRUE | rescue == TRUE)]

write.table(rescue, file=paste0(sample_path, '_rescued_scan2.tsv'), row.names=FALSE, quote=FALSE, sep='\t')
