#!/usr/bin/env Rscript

## Note: this is a command-line script so that it can be called from bash
## scripts on the supercomputer cluster and run the indepent soil water
## reconstructions in parallel


## reconstruct across historical and porjected time series and landscapes:


library(parallel)
library(lubridate)
library(zoo)


OUT_DIR <- "../results/soil"

#no_cores <- 36 # detectCores()
no_cores <- detectCores()
print(sprintf("%d cores detected", no_cores))
CLUSTER <- makeCluster(no_cores-1, type="FORK")


gcms <- c("CCSM4.r6i1p1", "CNRM-CM5.r1i1p1", "CSIRO-Mk3-6-0.r2i1p1",
        "HadGEM2-CC.r1i1p1", "inmcm4.r1i1p1", "IPSL-CM5A-LR.r1i1p1",
        "MIROC5.r1i1p1", "MPI-ESM-LR.r1i1p1", "MRI-CGCM3.r1i1p1")
scenarios <- c("rcp45", "rcp85")
mtns <- c("CM", "DM", "GM")
timeps <- c("ref", "2020s", "2050s", "2080s")


source("./wx-data.R")
source("./load_grids.R")
soilmod <- readRDS("../results/soil/soilmod.RDS")



hist_wx_data <- dplyr::mutate(hist_wx_data, date = datet, yr = year(datet))
proj_wx_data <- dplyr::mutate(proj_wx_data, date = datet, yr = year(datet))

summarizeChunk <- function(topo_chunk, the_wx, smod = soilmod) {
  expand.grid.df <- function(...) Reduce(function(...) merge(..., by=NULL), list(...))
  df <- expand.grid.df(topo_chunk, the_wx)
  df$gswc <- predict(smod, newdata=df, na.action=na.pass)
  df <- df %>% dplyr::group_by(x,y) %>% dplyr::summarize(gswc = mean(gswc))
  return(df)
}


makeGSWCdf <- function(themtn, thegcm=NULL, thescenario=NULL, thetimep=NULL) {
  if (is.null(thegcm)) { # historical
    thewx <- dplyr::filter(hist_wx_data, mtn==themtn & yr > 1960 & yr < 2001)
  } else if (timep == "ref") {
    thewx <- dplyr::filter(proj_wx_data, mtn==themtn & gcm == thegcm &
                                           scenario == thescenario &
                                           yr > 1960 & yr < 2001)
  } else if (timep == "2020s") {
    thewx <- dplyr::filter(proj_wx_data, mtn==themtn & gcm == thegcm &
                                           scenario == thescenario &
                                           year(datet) >= 2010 & year(datet) < 2040)
  } else if (timep == "2050s") {
    thewx <- dplyr::filter(proj_wx_data, mtn==themtn & gcm == thegcm &
                                           scenario == thescenario &
                                           year(datet) >= 2040 & year(datet) < 2070)
  } else if (timep == "2080s") {
    thewx <- dplyr::filter(proj_wx_data, mtn==themtn & gcm == thegcm &
                                           scenario == thescenario &
                                           year(datet) >= 2070 & year(datet) < 2100)
  }

  thewx <- thewx %>% dplyr::mutate(rollp = rollsum(prcp, 30, align = "right", fill=NA)) %>%
    dplyr::select(date, rollp)


  thetopo <-   topodfs[[themtn]]
  # thetopo <- thetopo[1:500,]  # testing
  idx   <- splitIndices(nrow(thetopo), 200)
  topolist <- lapply(idx, function(ii) thetopo[ii,,drop=FALSE])
  ans   <- clusterApply(CLUSTER, topolist, summarizeChunk, the_wx=thewx)
  return(do.call(rbind, ans))
}



#### MAIN COMMAND LINE SCRIPT ###

# run from command line. Expects, mtn, gcm, scenario. If only one argument is
# passed, it will conduct the historical reconstruction for that mtn range.
args <- commandArgs(trailingOnly=TRUE)

# test data for running interactively:
# args <- "CM"

  # test if there is at least one argument: if not, return an error
print("arguments: ")
print(args)
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).\n", call.=FALSE)
}

tmtn <- args[1]
if (length(args)==1) {
  # historical
  print("Reconstructing historic soil water series")
  tgcm <- NULL
  tscenario <- NULL
  ttime <- NULL
} else {
  tgcm <- args[2]
  tscenario <- args[3]
  ttime <- args[4]
}

# now run the reconstruction
oname <-  paste(tmtn, tgcm, tscenario, ttime, sep="_")
print(oname)
res <- makeGSWCdf(tmtn, tgcm tscenario, ttime)

# save files snapshots
res <- res %>% as_tibble() %>% filter(complete.cases(.))

# historical
if(is.null(tgcm) ) {
  # full
  ofile <- file.path(OUT_DIR, paste(oname, "_19612000", ".RDS", sep=""))
  print(paste("Saving:", ofile))
  saveRDS(res, ofile)
} else {
  # projected summaries
  ofile <- file.path(OUT_DIR, paste(oname, ".RDS", sep=""))
  print(paste("Saving:", ofile))
  saveRDS(res, ofile)
}

stopCluster(CLUSTER)
