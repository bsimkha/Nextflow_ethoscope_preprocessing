# Ethoscope pre-processing pipeline
This pipeline was built in **Nextflow** to process the **.db** files generated from Ethoscope monitors (Geissmann et. al., https://doi.org/10.1371/journal.pbio.2003026). The pipeline can simultaneously process multiple experimental blocks by automatically pairing metadata files with the corresponding results folder. This pipeline is compatible with a local computer as well as with a HPC cluster.

## Overview
The pipeline automates the following steps (Rethomics, https://rethomics.github.io/):  

**Data linking** - links metadata files with **.db** files  
**Data loading** - loads data into R  
**Data preprocessing** - generates data into **10 s** epochs  
**Phase analysis** - partitions data into **day** and **night**  
**Phenotype bout** - generates files with bout-lengths for each bout of **activity**, **sleep** and **rest**  
**Phenotype summary** - generates files with summaries (bout count, total length, average length, max length and min length) for activity, sleep and rest  
**Last timestamp** - generates last active time stamp for each individual

## Prerequisites
### Core requirement
* Java (version >17)
* Nextflow
* R
### Libraries/packages  
* `behavr`
* `sleepr`
* `scopr`
* `ggetho`
* `dplyr`
* `data.table` 

It is recommended that these libraries are installed in a custom directory. To install libraries in a custom directory in R:
```bash
install.packages("<library_name>", lib = "<path/to/custom/directory>")
```

## Data configuration  
### Input directory
Ethoscope data generally follow the basic format: `results/<machine_id>/<machine_name>/<datetime>/<file.db>`
<pre>
results
├── 0284b915609049b69c83c45d68f0020f
│   └── ETHOSCOPE_028
│       └── 2025-06-24_20-10-26
│           └── 2025-06-24_20-10-26_0284b915609049b69c83c45d68f0020f.db
├── 03085dc1d0bb458bb706e8899df5e391
    └── ETHOSCOPE_030
        └── 2025-06-24_20-11-50
            └── 2025-06-24_20-11-50_03085dc1d0bb458bb706e8899df5e391.db
</pre>
For each experimental blocks, create a separate sub-directory (**Eg: Experiment_1, Experiment_2, etc**), each containing the results folder, and put those sub-directories into a single input directory.  
The general format should be: `<input_dir>/<Experiment_n>/results/<machine_id>/<machine_name>/<datetime>/<file.db>`
<pre>
input_dir
├── Experiment_1
│   └── results
│       ├── ...
│       └── ...
│
├── Experiment_2
│   └── results
│       ├── ...
│       └── ...
│
├── Experiment_3
│   └── results
│       ├── ...
│       └── ...
</pre>

**NOTE**: This version of pipeline only works if the results directories are named "results". Other forms do not work

### Metadata files
Metadata files are `.csv` files that contain metadata information about the experiment. For scalability purposes, metadata files **must** start with the same name as the experimental block folder in the input directory, followed by `_metadata`.  
Example: `Experiment_1_metadata.csv`, `Experiment_2_metadata.csv`, `Experiment_3_metadata.csv`


## Installation  
Clone the repository into your local device or a HPC cluster
```bash
git clone https://github.com/bsimkha/Nextflow_ethoscope_preprocessing
cd Nextflow_ethoscope_preprocessing
```
This will be your working directory. To, get the path to your working direcotry:
```
pwd
```

## Pipeline configuration
Before running the pipeline, please make sure you:
### All users
* Upload all metadata files to `Metadata` folder
* Update all variables encompassed by `<>` in `config.yaml` to represent your experimental information
### HPC users
* Update all variables encompassed by `<>` in `Ethoscope_initiator.sh`

## Running the pipeline
Use the following script to run the pipeline
### Local users
```
nextflow run ./Scripts/Ethoscope_nextflow.nf \
    -params-file ./config.yaml
```
### HPC users
```
sbatch Ethoscope_initiator.sh
```

## Output
Upon a successful run, `Output` direcotry is generated. This contains separate sub-directories for each experimental block. Each sub-directory contains 4 sub-directories:  
* `1_Missing`: Contains information on missing data files, and missing data points within each file
    * `xxx_missing_monitor_data.csv`: Monitors in `xxx_metadata.csv` that do not have `.db` files
    * `xxx_missing_and_imputed_processed_data_summary.csv`: Provides inforamtion on how much data was imputed by Rethomics for monitors found in `xxx_metadata.csv`
* `2_Bout_details`: Contains bout length for each bout of:
    * `xxx_sleep_details.csv`: Contains inforamtion on each bout of sleep (inactivity > 5 min)
    *  `xxx_activity_details.csv`: Contains information on each bout of activity
    *  `xxx_rest_details.csv`: Contains information on each bout of rest (inactivity < 5 min)
    *  `xxx_missing_details.csv`: Contains information on each bout of missed recording that was not imputed by rethomics
* `3_Bout_summary`: Contains individual-level summaries for respective phenotype(s). These files are generally used in statistical analyses after they have been filtered for dead flies.
* `4_Last_timestamp`: Contains time stamp for last recorded activity for each individual. This can be used for manual dead fly identification.

<pre>
Output
├── Experiment_1
│   ├── 1_Missing
│   │   ├── Experiment_1_missing_monitor_data.csv
│   │   └── Experiment_1_missing_and_imputed_processed_data_summary.csv
│   ├── 2_Bout_details
│   │   ├── Experiment_1_sleep_details.csv
│   │   ├── Experiment_1_activity_details.csv
│   │   ├── Experiment_1_rest_details.csv
│   │   └── Experiment_1_missing_data_details.csv
│   ├── 3_Bout_summary
│   │   ├── Experiment_1_sleep_summary.csv
│   │   ├── Experiment_1_activity_summary.csv
│   │   ├── Experiment_1_rest_summary.csv
│   │   └── Experiment_1_missing_data_summary.csv
│   └── 4_Last_timestamp
│       └── Experiment_1_last_timestamp.csv
└── Experiment_2
    ├── 1_Missing
    ├── 2_Bout_details
    ├── 3_Bout_summary
    └── 4_Last_timestamp
</pre>
