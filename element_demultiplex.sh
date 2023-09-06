#!/bin/bash
#
#SBATCH --job-name=element_demultiplex
#SBATCH --cpus-per-task=4
#SBATCH --time=2-00:00:00
#SBATCH --partition=cgawad
#SBATCH --nodes=1
#SBATCH --mem=180G

while [ "$1" != "" ]; do
    case $1 in
        --run_dir )     shift
                            RUN_DIR=$1
                            ;;
		--fastq_dir )   shift
						FASTQ_DIR=$1
						;;
    esac
    shift
done

source /home/groups/cgawad/element_python_environment/bin/activate

BASE2FASTQ_DIR="/oak/stanford/projects/onc-seq/AV230702/"

$BASE2FASTQ_DIR/bases2fastq $RUN_DIR $FASTQ_DIR

#fix folder structure by moving to the Samples subfolder and then moving all files in their subfolders to the top structure
cd $FASTQ_DIR/Samples

find . -maxdepth 2 -type f -name "*.fastq.gz" -exec mv {} $FASTQ_DIR/ \;
