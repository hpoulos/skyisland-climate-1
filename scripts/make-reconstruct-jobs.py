#!/usr/bin/env python
import subprocess

gcms = ["CCSM4.r6i1p1", "CNRM-CM5.r1i1p1", "CSIRO-Mk3-6-0.r2i1p1",
        "HadGEM2-CC.r1i1p1", "inmcm4.r1i1p1", "IPSL-CM5A-LR.r1i1p1",
        "MIROC5.r1i1p1", "MPI-ESM-LR.r1i1p1", "MRI-CGCM3.r1i1p1"]
scenarios = ["rcp45", "rcp85"]
mtns = ["CM", "DM", "GM"]
timeps = ["ref", "2020s", "2050s", "2080s"]

qsub_lines ="""#!/bin/bash

## Run the full landscape historical temperature reconstruction

# load modules
module load intel
module load R
# module load gdal # not yet working, link errors. Not needed

# necessary for R to use BLAS libraries on quanah:
export MKL_NUM_THREADS=36
export OPM_NUM_THREADS=36

#$ -V
#$ -N {0}
#$ -o ../results/$JOB_NAME.o$JOB_ID
#$ -e ../results/$JOB_NAME.e$JOB_ID
#$ -cwd
#$ -S /bin/bash
#$ -P quanah
#$ -pe fill 36
#$ -q omni

R --slave --args  {1} {2} {3} {4} < ~/projects/skyisland-climate/scripts/reconstruct-climate.R
"""


# historical
for mtn in mtns :
    job = mtn + "_hist"
    fname = "qs_" + mtn + "_hist"
    f = open(fname, "w")
    f.write(qsub_lines.format(job, mtn, "", "", ""))
    f.close()
#    subprocess.Popen("qsub " + fname)

# projected
for mtn in mtns:
    for gcm in gcms:
        for sc in scenarios:
            for tp in timeps :
                job = "_".join([mtn, gcm, sc, tp]) + "_rp"
                fname = "qs_" + "_".join([mtn, gcm, sc, tp])
                f = open(fname, "w")
                f.write(qsub_lines.format(job, mtn, gcm, sc, tp))
                f.close()
                #            subprocess.Popen("qsub " + fname)

