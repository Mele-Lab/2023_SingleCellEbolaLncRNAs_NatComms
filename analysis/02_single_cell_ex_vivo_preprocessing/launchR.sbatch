#!/bin/bash
#SBATCH --job-name=PreprocessZyagen
#SBATCH --workdir=.
#SBATCH --cpus-per-task=48
#SBATCH --qos=debug

module load R 

Rscript 03_figurepaper.R