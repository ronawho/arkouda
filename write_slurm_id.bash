#!/bin/bash

# If we're the first node, write the slurm jobid to a file
if [ `scontrol show hostnames | head -n1` == `hostname` ]; then
  echo $SLURM_JOBID > $WRITE_SLURM_ID_FILENAME
fi

$@
