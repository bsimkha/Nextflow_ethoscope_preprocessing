#!/bin/bash
#
#SBATCH --job-name=<job name>
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --partition=<partition>
#SBATCH --time=30-00:00:00
#SBATCH --mem=16G
#SBATCH --output=<path/to/working/directory>/log/output_%j.txt
#SBATCH --error=<path/to/working/directory>/log/error_%j.txt
#SBATCH --mail-type=all
#SBATCH --mail-user=<user email>

#Initialize the correct conda/mamba and bring conda/mamba into bash environment
source <path to conda initialization script>
source <path to mamba initialization script>

#Activate the correct conda/mamba environment containing Neftflow installation
mamba activate nextflow

#Load correct R version
module load <R version, Eg: R/4.3.0>

cd <path/to/working/directory>

#Run the nextflow script
nextflow run ./Scripts/Ethoscope_nextflow.nf \
    -c ./nextflow.config \
    -params-file ./config.yaml
