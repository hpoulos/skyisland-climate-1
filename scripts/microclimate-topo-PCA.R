# microclimate-topo-PCA.R

# load iButton data and topgraphic data and run PCAs

# Holden et al 2001 PCA approach to summarize time series first. Use PCA to
# reduce spatial variation into a few PCA axes.

# depends upon iButton.R (for sensor reading functions) and load-sensor-data.R
# (to load summaries into workspace intelligently)

# loads alltemps, temp.daily.sum and temp.monthly.sum
source("./load-sensor-data.R")
# Read in raster::Stack objects for each mtn range
source("./load_grids.R")
# sensor locations
sensors <- read.csv("../microclimate/sensors.csv", stringsAsFactors=FALSE)

# projection string for sensor data. This should match the ascii grids
PROJ_STRING <- "+proj=longlat +ellps=WGS84 +datum=WGS84"

library(ggplot2)
library(tidyr)
#library(pcaMethods) # see http://www.bioconductor.org/packages/release/bioc/html/pcaMethods.html
library(dplyr)

extractVals1Mtn <- function(themtn, topostacks) {
    sensors.mtn <- sensors %>% filter(mtn==themtn) %>% dplyr::select(sensor, mtn, lon, lat)
    coords.sp <- sp::SpatialPoints(dplyr::select(sensors.mtn, lon, lat),
                                   proj4string=sp::CRS(PROJ_STRING) )
    return(cbind(sensors.mtn, raster::extract(topostacks[[themtn]], coords.sp)))
}

# TODO do for all mtn ranges once data is available
sensors.DM.topo <- extractVals1Mtn("DM", topostacks)
sensors.CM.topo <- extractVals1Mtn("CM", topostacks)
sensors.GM.topo <- extractVals1Mtn("GM", topostacks)

sensors.topo <- bind_rows(sensors.DM.topo, sensors.CM.topo, sensors.GM.topo)

# helper functions
jan2feb <- function(m){
  return(m=="01" | m =="02")
}

jan2march <- function(m){
  return(m=="01" | m =="02" | m == "03")
}

dec2jan <- function(m){
  return(m=="12" | m =="1")
}


lengthNotNA <- plyr::colwise(function(x) { sum( ! is.na(x))})

# function to run PCA on iButton sensor (temperature) data
runPCA <- function(wdata, minlength=1100, nPC = 3) {
   # Throw out sensors with less than minlength values. 1000 works for full
   # data set. But this should be adjusted to keep missing data at <= 10% for
   # ppca method. TODO
   df <- wdata[, lengthNotNA(wdata) >= minlength]
   # Throw out rows in which all elements are NA:
   df <- df[rowSums(is.na(df[,-1])) != ncol(df[,-1]),]
   ## Run PCA
  df.PCA <- pca(df[,-1], nPcs=nPC, method="ppca", center=FALSE, maxIterations=4000)
   # merge scores back with dates to run time series analysis:
   scores <- cbind(data.frame(datet=df$datet), as.data.frame(scores(df.PCA)))
   loadings <- as.data.frame(loadings(df.PCA))
   loadings$sensor <- rownames(loadings)
   loadings <- merge(sensors.topo, loadings, by = c("sensor"))
   return(list(scores = scores, loadings = loadings))
}


getTempPCA <- function(df) {
    # first step is to get data in a wide format with once columns per sensor
    df.cast <- df %>% gather(variable, value, -datet, -sensor) %>%
        tidyr::spread(sensor, value)
    tmin <- df.cast %>% filter(variable=="tmin") %>% dplyr::select(-variable)
    tmax <- df.cast %>% filter(variable=="tmax") %>% dplyr::select(-variable)
    tmin.PCA <- runPCA(tmin)
    tmax.PCA <- runPCA(tmax)
    return(list(tmin=tmin.PCA, tmax=tmax.PCA))
}

###############################################################################
## Main script starts here
###############################################################################

# output location for plots:
plot_output <- "../results/plots/"
data_output <- "../results/tempdata/"

# run one PCA
loadPCAData.mtn <- function(themtn, dailysum) {
    return(getTempPCA(subset(dailysum, mtn==themtn)[, 1:4]))
}


# Load the PCA scores and loadings into the workspace. To save running time,
# this checks to see if the csv files already exist and if they do, simply
# reads these rather than rerunning the PCAs. Unless force=TRUE, in which case
# the PCAs are rerun.
loadPCAData <- function(force=FALSE) {

    DM.PCA.file <- file.path(data_output, "DM-PCA.rds")
    CM.PCA.file <- file.path(data_output, "CM-PCA.rds")
    GM.PCA.file <- file.path(data_output, "GM-PCA.rds")

    # get daily temperature sum with mtn id column for splitting:
    dailysum <- temp.daily.sum %>% merge(dplyr::select(sensors, sensor, mtn))

    # note grid timestamps are read from .asc files in load_grids.R
    DM.PCA <- get_data(DM.PCA.file, GRID_TIMESTAMP_DM, loadPCAData.mtn,
                       themtn = "DM", dailysum = dailysum)
    CM.PCA <- get_data(CM.PCA.file, GRID_TIMESTAMP_CM, loadPCAData.mtn,
                       themtn = "CM", dailysum = dailysum)
    GM.PCA <- get_data(GM.PCA.file, GRID_TIMESTAMP_GM, loadPCAData.mtn,
                       themtn = "GM", dailysum = dailysum)

    return(list("DM" = DM.PCA, "CM" = CM.PCA, "GM" = GM.PCA))
}

# load it
PCAs <- loadPCAData()
