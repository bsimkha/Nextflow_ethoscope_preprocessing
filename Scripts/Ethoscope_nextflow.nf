nextflow.enable.dsl=2

params.threads     = params.threads ?: 8

params.zt_0        = params.zt_0 ?: 7.0
params.start_time  = params.start_time ?: 17.0
params.n_days      = params.n_days ?: 5
params.time_zone   = params.time_zone ?: -5.0

process LOAD_DATA {
    tag "$exp"
    cpus params.threads
    memory 8.GB
    stageInMode 'symlink'

    publishDir { "${projectDir}/../Output/${exp}/1_Missing" },
               mode: 'copy',
               pattern: "*.csv",
               overwrite: true

    input:
    tuple val(exp), path(metadata_csv), path(results_dir)

    output:
    tuple val(exp),
          path("${exp}_dt_trimmed.rds"),
          path("${exp}_metadata.rds"),
          emit: loaded

    path "${exp}_missing_monitor_data.csv"
    path "${exp}_missing_and_imputed_processed_data_summary.csv"

    script:
    """
    Rscript "${projectDir}/load_data.R" \
      --metadata_file "${metadata_csv}" \
      --results_dir "${results_dir}" \
      --exp_id "${exp}" \
      --lib "${params.lib}" \
      --zt_0 "${params.zt_0}" \
      --time_zone "${params.time_zone}" \
      --start_time "${params.start_time}" \
      --n_days "${params.n_days}" \
      --outdir "."
    """
}

process RUN_BOUT_ANALYSIS {
    tag "$exp"
    cpus params.threads
    memory 16.GB
    stageInMode 'symlink'

    publishDir { "${projectDir}/../Output/${exp}/2_Bout_details" },
               mode: 'copy',
               pattern: "*_details.csv",
               overwrite: true

    publishDir { "${projectDir}/../Output/${exp}/3_Bout_summary" },
               mode: 'copy',
               pattern: "*_summary.csv",
               overwrite: true

    input:
    tuple val(exp), path(dt_trimmed_rds), path(metadata_rds)

    output:
    path "${exp}_*_details.csv"
    path "${exp}_*_summary.csv"

    script:
    """
    Rscript "${projectDir}/run_bout_analysis.R" \
      --dt_trimmed "${dt_trimmed_rds}" \
      --metadata "${metadata_rds}" \
      --exp_id "${exp}" \
      --lib "${params.lib}" \
      --ind_var "${params.ind_var}" \
      --outdir "."
    """
}

process LAST_TIMESTAMP {
    tag "$exp"
    cpus params.threads
    memory 16.GB
    stageInMode 'symlink'

    publishDir { "${projectDir}/../Output/${exp}/4_Last_timestamp" },
               mode: 'copy',
               pattern: "*.csv",
               overwrite: true

    input:
    tuple val(exp), path(dt_trimmed_rds), path(metadata_rds)

    output:
    path "${exp}_last_timestamp.csv"

    script:
    """
    Rscript "${projectDir}/last_timestamp.R" \
      --dt_trimmed "${dt_trimmed_rds}" \
      --metadata "${metadata_rds}" \
      --exp_id "${exp}" \
      --zt_0 "${params.zt_0}" \
      --lib "${params.lib}" \
      --outdir "."
    """
}

workflow {
    metadata_ch = Channel
        .fromPath("${workflow.projectDir}/../Metadata/*_metadata*")
        .map { meta ->
            def exp = meta.baseName.split('_metadata')[0]

            def folder = file(params.input_dir).listFiles()
                .find { it.isDirectory() && (it.name == exp || it.name.startsWith("${exp}_")) }

            folder ? tuple(exp, meta, file("${folder}/results")) : null
        }
        .filter { it != null }

    LOAD_DATA(metadata_ch)

    RUN_BOUT_ANALYSIS(LOAD_DATA.out.loaded)

    LAST_TIMESTAMP(LOAD_DATA.out.loaded)
}
