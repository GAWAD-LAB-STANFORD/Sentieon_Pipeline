#!/bin/bash
#
#SBATCH --job-name=3_PTATO
#SBATCH --time=6-23:00:00
#SBATCH --partition=cgawad
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --mem=60G
#SBATCH --mail-type=ALL
#SBATCH --error=PTATO.err


source /home/groups/cgawad/miniconda3/etc/profile.d/conda.sh

conda deactivate

conda activate scan2_sigs

ml java/18.0.2


export PATH=$PATH:/home/groups/cgawad/nextflow
export PATH=$PATH:/oak/stanford/groups/cgawad/Scripts/PTATO
## change configs_path later to not just use PTATO's config path, either that or create a config path for the user

PTATO_PATH=/oak/stanford/groups/cgawad/Scripts/PTATO
CONFIGS_PATH=/oak/stanford/groups/cgawad/Scripts/PTATO/configs


nextflow run ${PTATO_PATH}/ptato.nf -c ${CONFIGS_PATH}/run.config -profile slurm -resume

