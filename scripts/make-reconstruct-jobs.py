#!/usr/bin/env python
import subprocess

gcms = ["CCSM4.r6i1p1", "CNRM-CM5.r1i1p1", "CSIRO-Mk3-6-0.r2i1p1",
        "HadGEM2-CC.r1i1p1", "inmcm4.r1i1p1", "IPSL-CM5A-LR.r1i1p1",
        "MIROC5.r1i1p1", "MPI-ESM-LR.r1i1p1", "MRI-CGCM3.r1i1p1"]
scenarios = ["rcp45", "rcp85"]
mtns = ["CM", "DM", "GM"]

qsub_lines ="""#!/bin/bash

## Run the full landscape historical temperature reconstruction


#$ -V
#$ -N {0}
#$ -o ../results/$JOB_NAME.o$JOB_ID
#$ -e ../results/$JOB_NAME.e$JOB_ID
#$ -cwd
#$ -S /bin/bash
#$ -P hrothgar
#$ -pe fill 12
#$ -q normal

R --slave --args  {1} {2} {3} < ~/projects/skyisland-climate/scripts/reconstruct-climate.R
"""


# historical
for mtn in mtns :
    job = "recons_hist_" + mtn
    fname = "qsub_recons_hist_" + mtn
    f = open(fname, "w")
    f.write(qsub_lines.format(job, mtn, "", ""))
    f.close()
#    subprocess.Popen("qsub " + fname)

# projected
for mtn in mtns:
    for gcm in gcms:
        for sc in scenarios:
            job = "recons_proj_" + "_".join([mtn, gcm, sc])
            fname = "qsub_recons_" + "_".join([mtn, gcm, sc])
            f = open(fname, "w")
            f.write(qsub_lines.format(job, mtn, gcm, sc))
            f.close()
#            subprocess.Popen("qsub " + fname)
