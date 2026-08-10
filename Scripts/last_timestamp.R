args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NA_character_) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) return(default)
  args[idx + 1]
}

lib             <- get_arg("--lib")
dt_trimmed_file  <- get_arg("--dt_trimmed")
metadata_file    <- get_arg("--metadata")
exp_id           <- get_arg("--exp_id")
zt_0             <- as.numeric(get_arg("--zt_0"))
outdir           <- get_arg("--outdir", ".")

if (is.na(dt_trimmed_file) || is.na(metadata_file) || is.na(exp_id)) {
  stop("Missing required arguments: --dt_trimmed, --metadata, --exp_id, --zt_0")
}

if (!is.na(lib) && nzchar(lib)) {
  .libPaths(c(lib, .libPaths()))
}

suppressPackageStartupMessages(library(data.table))
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
dt_trimmed     <- readRDS(dt_trimmed_file)
Metadata_found <- readRDS(metadata_file)

if (!is.data.table(dt_trimmed))     dt_trimmed     <- as.data.table(dt_trimmed)
if (!is.data.table(Metadata_found)) Metadata_found <- as.data.table(Metadata_found)
if (!"datetime" %in% names(Metadata_found)) {
  stop("Metadata_found does not contain a date column")
}

# t = 0 already represents zt_0 (time zone already accounted for upstream).
# Anchor t = 0 at zt_0, on the setup date.
setup_dates <- unique(Metadata_found[, .(id, datetime)])
setup_dates[, date := as.Date(datetime)]
setup_dates[, setup_anchor := as.POSIXct(paste(date, "00:00:00"), tz = "UTC") + zt_0 * 3600]

# Last REAL (non-missing) timestamp per id
last_t <- dt_trimmed[missing == FALSE, .(last_t = max(t)), by = id]

result <- merge(last_t, setup_dates[, .(id, setup_anchor)], by = "id", all.x = TRUE)
result[, last_timestamp := as.character(format(
  setup_anchor + last_t,
  format = "%Y-%m-%d %H:%M:%S",
  tz = "UTC"
))]

out <- result[, .(id, last_t, last_timestamp)]
fwrite(out, file.path(outdir, paste0(exp_id, "_last_timestamp.csv")))