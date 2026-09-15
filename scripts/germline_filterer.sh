#!/bin/bash

#SBATCH --job-name=germline_filterer
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --mem=180G

ml math py-numpy/1.19.2_py36
ml py-pandas/1.0.3_py36

CONTROL_ROWS_INCLUDED=$1
CONTROL_ROWS_FILTERED=$2
NORMAL_SAMPLE_NAME=$3

python3 /oak/stanford/groups/cgawad/Scripts/TEST_Sentieon_Pipeline/scripts/remove_control_rows.py -d $CONTROL_ROWS_INCLUDED -p $CONTROL_ROWS_FILTERED -n $NORMAL_SAMPLE_NAME

