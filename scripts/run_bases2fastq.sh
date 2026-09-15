#!/bin/bash
#
#SBATCH --job-name=element_demultiplex
#SBATCH --cpus-per-task=4
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=64G
#SBATCH --out=run_bases2fastq.out

RUN_DIR=$1
FASTQ_DIR=$2

ml python/3.6.1
source /home/groups/cgawad/element_python_environment/bin/activate

/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/bases2fastq $RUN_DIR $FASTQ_DIR
