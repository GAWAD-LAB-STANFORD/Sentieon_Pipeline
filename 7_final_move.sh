#!/bin/bash
#
#SBATCH --job-name=final_move
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=120G

set -x

RESULTS_DIR=$1
FINAL_DIR=$2

cd $RESULTS_DIR

#checking a bunch of the outputs:

mkdir -p 01_final_outputs
rsync -a --exclude '01_final_outputs' ${RESULTS_DIR}/01* 01_final_outputs/

mkdir -p $FINAL_DIR

rsync -rl $RESULTS_DIR/* $FINAL_DIR

echo "current directory is `pwd`"
