args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NA_character_) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) return(default)
  args[idx + 1]
}

lib <- get_arg("--lib")
.libPaths(c(lib, .libPaths()))

suppressPackageStartupMessages({
  library(scopr)
  library(sleepr)
  library(data.table)
  library(dplyr)
})

metadata_file <- get_arg("--metadata_file")
results_dir   <- get_arg("--results_dir")
exp_id        <- get_arg("--exp_id")
zt_0          <- as.numeric(get_arg("--zt_0"))
time_zone     <- as.numeric(get_arg("--time_zone"))
start_time    <- as.numeric(get_arg("--start_time"))
n_days        <- as.numeric(get_arg("--n_days"))
outdir        <- get_arg("--outdir", ".")

if (is.na(metadata_file) || is.na(results_dir) || is.na(exp_id)) {
  stop("Missing required arguments: --metadata_file, --results_dir, --exp_id")
}

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# Load metadata
Metadata <- fread(metadata_file)
if ("date" %in% names(Metadata)) {
  Metadata[, date := as.Date(date, format = "%m/%d/%Y")]
}

# Link metadata to result files
Metadata_found <- link_ethoscope_metadata(Metadata, result_dir = results_dir)
Metadata_missing <- Metadata[!machine_name %in% Metadata_found$machine_name]

# Load and annotate
dt <- load_ethoscope(
  Metadata_found,
  reference_hour = zt_0 - time_zone, #This adjusts the time zone for all analyses downstream
  FUN = sleepr::sleep_annotation,
  verbose = FALSE
)

# Compute the analysis window
start_t <- as.integer(start_time * 3600)
end_t   <- as.integer((n_days * 24 * 3600) + start_t - 10)

# Trim to the requested window
dt_trimmed <- dt[t %between% c(start_t, end_t)]

# Add resting
dt_trimmed[, resting := !moving & !asleep]

# Add missing bins on a 10-second grid
setorder(dt_trimmed, id, t)

dt_expected <- dt_trimmed[, .(t = seq(start_t, end_t, by = 10)), by = id]
dt_trimmed[, missing := FALSE]

dt_trimmed <- merge(
  dt_expected,
  dt_trimmed,
  by = c("id", "t"),
  all.x = TRUE,
  sort = FALSE
)

# Reattach metadata class
setkey(dt_trimmed, id)
dt_trimmed <- behavr(dt_trimmed, Metadata_found)

# Mark inserted rows as missing
dt_trimmed[is.na(missing), `:=`(
  missing = TRUE,
  moving = FALSE,
  asleep = FALSE,
  is_interpolated = FALSE,
  resting = FALSE
)]

# Missing / imputed summary
Missing_data <- dt_trimmed %>%
  group_by(id) %>%
  summarise(
    Total_missing   = sum(is_interpolated, na.rm = TRUE) * 10 + sum(missing, na.rm = TRUE) * 10,
    Assigned_sleep  = sum(is_interpolated & asleep, na.rm = TRUE) * 10,
    Assigned_rest   = sum(is_interpolated & resting, na.rm = TRUE) * 10,
    Not_assigned    = sum(missing, na.rm = TRUE) * 10,
    .groups = "drop"
  ) %>%
  filter(Total_missing > 0)

# Save intermediates
saveRDS(dt_trimmed, file.path(outdir, paste0(exp_id, "_dt_trimmed.rds")))
saveRDS(Metadata_found, file.path(outdir, paste0(exp_id, "_metadata.rds")))

# Save QC outputs
fwrite(Metadata_missing, file.path(outdir, paste0(exp_id, "_missing_monitor_data.csv")))
fwrite(Missing_data, file.path(outdir, paste0(exp_id, "_missing_and_imputed_processed_data_summary.csv")))