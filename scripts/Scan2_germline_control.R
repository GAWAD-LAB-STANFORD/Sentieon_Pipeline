#!/usr/bin/env Rscript

# 'object' is the 'gt' object from somatic_genotypes.rda
compute.germline.fdr.priors <- function(object) {
    check.slots(object, c('gatk', 'static.filter'))
    # minimized objects have training.data deleted, but training.site is
    # annotated in the gatk data frame.
    if (!('training.site' %in% colnames(object@gatk)))
        check.slots(object, 'training.data')

    # in legacy mode, all candidate sites passing a small set of pre-genotyping
    # crtieria were used.
    cand <- object@gatk[
        object@gatk$balt == 0 &
        object@gatk[,11] == '0/0' &
        object@gatk$dbsnp == '.' &
        object@gatk$scalt >= object@static.filter.params$min.sc.alt &
        object@gatk$dp >= object@static.filter.params$min.sc.dp &
        object@gatk$bulk.dp >= object@static.filter.params$min.bulk.dp &
        (is.na(object@gatk.lowmq$balt) | object@gatk.lowmq$balt == 0),]
    hsnps=object@gatk[
        object@gatk$training.site &
        object@gatk$scalt >= object@static.filter.params$min.sc.alt,]

    cat(nrow(cand), 'somatic candidates\n')
    cat(nrow(hsnps), 'hsnps\n')
    fdr.priors <-
        estimate.germline.fdr.priors(candidates=cand, hsnps=hsnps, random.seed=0)
    rownames(fdr.priors) <- rownames(hsnps)

    join.cols <- c('chr','pos','refnt','altnt')
    germline.fdr.priors <- plyr::join(object@gatk[,join.cols],
        cbind(hsnps[,join.cols], fdr.priors))[,-(1:4)]
}


estimate.germline.fdr.priors <- function(candidates, hsnps, bins=20, random.seed=0)
{
    # fcontrol -> estimate.somatic.burden relies on simulations to
    # estimate the artifact:mutation ratio.
    cat(sprintf("estimating bounds on number of true mutations in hSNP set (seed=%d).
.\n",
        random.seed))
    set.seed(random.seed)

    # split candidates by depth; collapse all depths beyond the 80th
    # percentile into one bin
    #hsnps$af <- hsnps$hap1/ hsnps$dp
    max.dp <- as.integer(quantile(hsnps$dp, prob=0.8))
    fcs <- lapply(0:max.dp, function(dp)
        fcontrol(germ.df=hsnps[hsnps$dp == dp,],
                som.df=candidates[candidates$dp == dp,],
                bins=bins)
    )
    fc.max <- fcontrol(germ.df=hsnps[hsnps$dp > max.dp,],
                som.df=candidates[candidates$dp > max.dp,],
                bins=bins)
    fcs <- c(fcs, list(fc.max))

    cat(sprintf("        profiled hSNP and candidate VAFs at depths %d .. %d\n",
        0, max.dp))

    burden <- as.integer(
        c(sum(sapply(fcs, function(fc) fc$est.somatic.burden[1])),  # min est
          sum(sapply(fcs, function(fc) fc$est.somatic.burden[2])))  # max est
    )

    cat(sprintf("        estimated callable mutation burden range (%d, %d)\n",
        burden[1], burden[2]))
    cat("          -> using MAXIMUM burden\n")

    cat("        estimating true (N_T) and artifact (N_A) counts in candidate set..\n")
    popbin <- ceiling(hsnps$af * bins)
    popbin[hsnps$dp == 0 | popbin == 0] <- 1

    # make a table keyed by (dp, popbin)
    cat('making tables\n')
    nt.tab <- matrix(0.1, nrow=max.dp+2, ncol=bins)
    na.tab <- matrix(0.1, nrow=max.dp+2, ncol=bins)
str(nt.tab)
    for (dp in 1:(max.dp+1)) {
        idx = min(dp, max.dp+1) + 1
        if (!is.null(fcs[[idx]]$pops)) {
#str(fcs[[idx]]$pops$max[,1])
            nt.tab[idx,] <- fcs[[idx]]$pops$max[,1]
            na.tab[idx,] <- fcs[[idx]]$pops$max[,2]
        }
    }
str(nt.tab)
    cat('accessing tables\n')
print(summary( pmin(hsnps$dp, max.dp+1)+1 ))
print(summary( popbin ))
    nt <- nt.tab[cbind(pmin(hsnps$dp, max.dp+1)+1, popbin)]
    na <- na.tab[cbind(pmin(hsnps$dp, max.dp+1)+1, popbin)]

    data.frame(nt=nt, na=na)
}


compute.hsnp.fdr <- function(object, fdr.priors) {
    # First map the resampled training data to the main gatk slot
    resampled.sites <- object@resampled.training.data$training.data
# testing only
#resampled.sites <- resampled.sites[unique(c(1:10,sample(nrow(resampled.sites), 1000, replace=F))),]

    cat('mapping', nrow(resampled.sites),
        'resampled training sites to gatk slot\n')
    join.cols <- c('chr','pos','refnt','altnt')
    cand <- plyr::join(object@gatk[,join.cols],
        cbind(resampled.sites[,join.cols], TRUE))[,-(1:4)]
    cand[is.na(cand)] <- FALSE
    print(table(cand))

    cat('Got', sum(cand, na.rm=T), 'hSNP candidates for FDR\n')
    fdrs <- compute.fdr.legacy(
        altreads=object@gatk$scalt[cand],
        dp=object@gatk$dp[cand],
        gp.mu=object@ab.estimates$gp.mu[cand],
        gp.sd=object@ab.estimates$gp.sd[cand],
        nt=fdr.priors$nt[cand],
        na=fdr.priors$na[cand])

    fdrs <- plyr::join(object@gatk[,join.cols],
        cbind(object@gatk[cand,join.cols], fdrs))[,-(1:4)]

    fdrs
}


hsnp.static.filter <- function(object) {
    f <- object@static.filters
    # same as somatic mutations except allow for bulk reads and presence in dbsnp.
    # relevant tests: lowmq.test, max.bulk.alt.test, dbsnp.test
    f$cigar.id.test & f$cigar.hs.test & f$dp.test & f$abc.test &
        f$min.sc.alt.test
}


args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 3)
    stop('usage: germline_control.R somatic_genotypes.rda somatic_output.csv germline_output.csv')

in.rda <- args[1]
som.out.csv <- args[2]
germ.out.csv <- args[3]

if (file.exists(som.out.csv))
    stop('output file ', som.out.csv, ' already exists, please delete it first')
if (file.exists(germ.out.csv))
    stop('output file ', germ.out.csv, ' already exists, please delete it first')

.libPaths("/home/groups/cgawad/miniconda3/envs/update_scan2/lib/R/library")


suppressMessages(library(scan2))
suppressMessages(library(data.table))


cat('loading input file', in.rda, '\n')
load(in.rda)

somatic <- df(gt)
somatic$pass <- somatic$static.filter & somatic$mda.fdr <= 0.01 & somatic$lysis.fdr <= 0.01

somatic <- somatic[!is.na(somatic$pass) & somatic$pass,]
somatic$sample <- gt@single.cell
fwrite(somatic, file=som.out.csv)

cat('computing FDR priors for resampled hSNPs\n')
fdr.priors <- compute.germline.fdr.priors(gt)

cat('computing FDR parameters for resampled hSNPs\n')
fdrs <- compute.hsnp.fdr(gt, fdr.priors=fdr.priors)

hpass <- hsnp.static.filter(gt) & fdrs$lysis.fdr <= 0.01 & fdrs$mda.fdr <= 0.01
hpass[is.na(hpass)] <- FALSE

tab <- df(gt)
tab$pass <- hpass
# Just subset the full GATK table to get only resampled hSNPs
#tab$resampled.hsnp <- plyr::join(tab,
rs <- plyr::join(tab[,c('chr','pos','refnt','altnt')],
    cbind(gt@resampled.training.data$training.data[,c('chr', 'pos', 'refnt', 'altnt')], TRUE))[,-(1:4)]
rs[is.na(rs)] <- FALSE
tab <- tab[rs,]
tab$sample <- gt@single.cell

fwrite(tab, file=germ.out.csv)
