args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NA_character_) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) return(default)
  args[idx + 1]
}

lib <- get_arg("--lib")
if (!is.na(lib) && nzchar(lib)) {
  .libPaths(c(lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(data.table)
})

dt_trimmed_file <- get_arg("--dt_trimmed")
metadata_file   <- get_arg("--metadata")
exp_id          <- get_arg("--exp_id")
ind_var         <- get_arg("--ind_var", "")
outdir          <- get_arg("--outdir", ".")

if (is.na(dt_trimmed_file) || is.na(metadata_file) || is.na(exp_id)) {
  stop("Missing required arguments: --dt_trimmed, --metadata, --exp_id")
}

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

dt_trimmed     <- readRDS(dt_trimmed_file)
Metadata_found <- readRDS(metadata_file)

if (!is.data.table(dt_trimmed))     dt_trimmed     <- as.data.table(dt_trimmed)
if (!is.data.table(Metadata_found)) Metadata_found <- as.data.table(Metadata_found)

if (!"phase" %in% names(dt_trimmed)) {
  dt_trimmed[, phase := ifelse(t %% (24 * 3600) < (12 * 3600), "day", "night")]
}

setorder(dt_trimmed, id, t)

# Keep only the metadata variables listed in ind_var listed in config.yaml
ind_var <- trimws(unlist(strsplit(ind_var, ",")))
ind_var <- ind_var[nzchar(ind_var)]

keep_cols <- intersect(c("id", ind_var), names(Metadata_found))
meta_keep <- unique(Metadata_found[, ..keep_cols])

# Every id x phase (day/night) combination, with metadata attached
meta_with_phase <- meta_keep[, .(phase = c("day", "night")), by = names(meta_keep)]

compute_bouts <- function(dt, state_col) {
  state_col <- deparse(substitute(state_col))
  temp_dt <- copy(dt)
  temp_dt[, bout_id := cumsum(get(state_col) & !shift(get(state_col), fill = FALSE)), by = id]
  bouts <- temp_dt[get(state_col) == TRUE,
                   .(
                     phase = first(phase),
                     duration_s = .N * 10
                   ),
                   by = .(id, bout_id)
  ]
  
  merge(bouts, meta_with_phase, by = c("id", "phase"), all.y = TRUE)
}

compute_bout_summary <- function(dt, state_col) {
  state_col <- deparse(substitute(state_col))
  temp_dt <- copy(dt)
  temp_dt[, bout_id := cumsum(get(state_col) & !shift(get(state_col), fill = FALSE)), by = id]
  
  bouts <- temp_dt[get(state_col) == TRUE,
                   .(
                     phase = first(phase),
                     duration_s = .N * 10
                   ),
                   by = .(id, bout_id)
  ]
  
  summary <- bouts[, .(
    bouts            = .N,
    total_duration_s = sum(duration_s),
    avg_duration_s   = mean(duration_s),
    min_duration_s   = min(duration_s),
    max_duration_s   = max(duration_s)
  ), by = .(id, phase)]
  
  out <- merge(meta_with_phase, summary, by = c("id", "phase"), all.x = TRUE)
  
  num_cols <- c("bouts", "total_duration_s", "avg_duration_s", "min_duration_s", "max_duration_s")
  out[, (num_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0, x)), .SDcols = num_cols]
  
  out[]
}

phenotypes <- c(asleep = "sleep", moving = "activity", resting = "rest", missing = "missing_data")

for (state_col in names(phenotypes)) {
  label <- phenotypes[[state_col]]
  state_sym <- as.symbol(state_col)
  
  bouts   <- eval(bquote(compute_bouts(dt_trimmed, .(state_sym))))
  summary <- eval(bquote(compute_bout_summary(dt_trimmed, .(state_sym))))
  
  fwrite(bouts,   file.path(outdir, paste0(exp_id, "_", label, "_details.csv")))
  fwrite(summary, file.path(outdir, paste0(exp_id, "_", label, "_summary.csv")))
}