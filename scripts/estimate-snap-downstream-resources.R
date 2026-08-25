#!/usr/bin/env Rscript
################################################################################
# estimate-snap-downstream-resources.R
#
# Estimate LSF / future.globals resources for snap modules from upstream onwards.
# Baseline: 8 samples x 50,000 cells.
#
# Usage:
#   Rscript scripts/estimate-snap-downstream-resources.R \
#     --snap-root /path/to/sc-rna-seq-snap \
#     --output inputs/generated_downstream.json \
#     [--update-yaml]
################################################################################

suppressPackageStartupMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) stop("Install yaml: install.packages('yaml')")
  library(yaml)
})

`%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && nzchar(as.character(a))) a else b

parse_args <- function(args) {
  out <- list(snap_root = NULL, output = NULL, update_yaml = FALSE, estimated_cells_per_sample = NULL)
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (key == "--snap-root") { i <- i + 1L; out$snap_root <- args[[i]] }
    else if (key == "--output") { i <- i + 1L; out$output <- args[[i]] }
    else if (key == "--update-yaml") out$update_yaml <- TRUE
    else if (key == "--estimated-cells-per-sample") { i <- i + 1L; out$estimated_cells_per_sample <- as.integer(args[[i]]) }
    else stop("Unknown argument: ", key)
    i <- i + 1L
  }
  if (is.null(out$snap_root)) stop("--snap-root is required")
  out
}

count_metadata_samples <- function(metadata_path) {
  if (!file.exists(metadata_path)) { warning("Metadata not found — using 8 samples"); return(8L) }
  md <- read.delim(metadata_path, stringsAsFactors = FALSE)
  if (!"ID" %in% colnames(md)) stop("Metadata must contain an ID column")
  nrow(md)
}

compute_resources <- function(num_samples, estimated_cells_per_sample) {
  baseline_samples <- 8L
  baseline_cells <- 50000L
  total_cells <- num_samples * estimated_cells_per_sample
  baseline_total <- baseline_samples * baseline_cells
  sample_scale <- max(1L, as.integer(ceiling(num_samples / baseline_samples)))
  cell_scale <- max(1L, as.integer(ceiling(total_cells / baseline_total)))
  scale <- max(sample_scale, cell_scale)

  list(
    num_samples = num_samples,
    estimated_cells_per_sample = estimated_cells_per_sample,
    total_estimated_cells = total_cells,
    resource_tier = if (scale <= 1L) "default" else if (scale <= 2L) "large" else "xlarge",
    scale_factor = scale,
    upstream_cpu = if (num_samples <= 4L) 8L else if (num_samples <= 12L) 16L else 24L,
    upstream_memory_gb = 30L + (cell_scale - 1L) * 10L,
    upstream_future_globals_gib = 200L + (cell_scale - 1L) * 50L,
    integrative_cpu = if (num_samples <= 8L) 10L else 16L,
    integrative_memory_gb = 96L + (cell_scale - 1L) * 24L,
    integrative_future_globals_gib = 200L + (cell_scale - 1L) * 50L,
    cluster_cpu = if (scale <= 1L) 4L else if (scale <= 2L) 8L else 12L,
    cluster_memory_gb = 48L + (cell_scale - 1L) * 16L,
    cluster_future_globals_gib = 400L + (cell_scale - 1L) * 100L,
    contamination_memory_gb = 96L + (cell_scale - 1L) * 24L,
    contamination_future_globals_gib = 400L + (cell_scale - 1L) * 100L,
    cell_types_memory_gb = 64L + (cell_scale - 1L) * 16L,
    de_go_memory_gb = 32L + (cell_scale - 1L) * 8L,
    de_go_future_globals_gib = 200L + (cell_scale - 1L) * 50L,
    lsf_queue = if ((96L + (cell_scale - 1L) * 24L) >= 512L) "large_mem" else "standard"
  )
}

build_sprocket_inputs <- function(snap_root, container_image, notify_email, res) {
  q <- res$lsf_queue
  list(
    `sc_rna_seq_snap_downstream.snap_root` = snap_root,
    `sc_rna_seq_snap_downstream.container_image` = container_image,
    `sc_rna_seq_snap_downstream.notify_email` = notify_email,
    `sc_rna_seq_snap_downstream.run_upstream` = TRUE,
    `sc_rna_seq_snap_downstream.run_integrative` = TRUE,
    `sc_rna_seq_snap_downstream.run_cluster` = TRUE,
    `sc_rna_seq_snap_downstream.run_contamination_removal` = FALSE,
    `sc_rna_seq_snap_downstream.run_cell_types` = TRUE,
    `sc_rna_seq_snap_downstream.run_clone_phylogeny` = FALSE,
    `sc_rna_seq_snap_downstream.run_de_go` = TRUE,
    `sc_rna_seq_snap_downstream.run_rshiny` = FALSE,
    `sc_rna_seq_snap_downstream.num_samples` = res$num_samples,
    `sc_rna_seq_snap_downstream.estimated_cells_per_sample` = res$estimated_cells_per_sample,
    `sc_rna_seq_snap_downstream.upstream_cpu` = res$upstream_cpu,
    `sc_rna_seq_snap_downstream.upstream_memory_gb` = res$upstream_memory_gb,
    `sc_rna_seq_snap_downstream.upstream_future_globals_gib` = res$upstream_future_globals_gib,
    `sc_rna_seq_snap_downstream.upstream_lsf_queue` = q,
    `sc_rna_seq_snap_downstream.integrative_cpu` = res$integrative_cpu,
    `sc_rna_seq_snap_downstream.integrative_memory_gb` = res$integrative_memory_gb,
    `sc_rna_seq_snap_downstream.integrative_future_globals_gib` = res$integrative_future_globals_gib,
    `sc_rna_seq_snap_downstream.integrative_lsf_queue` = q,
    `sc_rna_seq_snap_downstream.cluster_cpu` = res$cluster_cpu,
    `sc_rna_seq_snap_downstream.cluster_memory_gb` = res$cluster_memory_gb,
    `sc_rna_seq_snap_downstream.cluster_future_globals_gib` = res$cluster_future_globals_gib,
    `sc_rna_seq_snap_downstream.cluster_lsf_queue` = q,
    `sc_rna_seq_snap_downstream.contamination_memory_gb` = res$contamination_memory_gb,
    `sc_rna_seq_snap_downstream.contamination_future_globals_gib` = res$contamination_future_globals_gib,
    `sc_rna_seq_snap_downstream.contamination_lsf_queue` = q,
    `sc_rna_seq_snap_downstream.cell_types_memory_gb` = res$cell_types_memory_gb,
    `sc_rna_seq_snap_downstream.cell_types_lsf_queue` = q,
    `sc_rna_seq_snap_downstream.de_go_memory_gb` = res$de_go_memory_gb,
    `sc_rna_seq_snap_downstream.de_go_future_globals_gib` = res$de_go_future_globals_gib,
    `sc_rna_seq_snap_downstream.de_go_lsf_queue` = q
  )
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  snap_root <- normalizePath(args$snap_root, mustWork = TRUE)
  config_path <- file.path(snap_root, "project_parameters.Config.yaml")
  cfg <- read_yaml(config_path)

  metadata_dir <- gsub('"', "", cfg$metadata_dir %||% file.path(snap_root, "data", "project_metadata"))
  metadata_path <- file.path(metadata_dir, cfg$metadata_file %||% "project_metadata.tsv")
  num_samples <- cfg$resource_profile$num_samples %||% count_metadata_samples(metadata_path)
  estimated_cells <- args$estimated_cells_per_sample %||% cfg$resource_profile$estimated_cells_per_sample %||% 50000L

  res <- compute_resources(as.integer(num_samples), as.integer(estimated_cells))

  cat("Downstream resource estimate:", snap_root, "\n")
  cat("  tier:", res$resource_tier, " samples:", res$num_samples, " total cells:", res$total_estimated_cells, "\n")
  cat("  upstream:", res$upstream_cpu, "cpu", res$upstream_memory_gb, "GB future:", res$upstream_future_globals_gib, "GiB\n")
  cat("  integrative:", res$integrative_cpu, "cpu", res$integrative_memory_gb, "GB future:", res$integrative_future_globals_gib, "GiB\n")
  cat("  cluster:", res$cluster_cpu, "cpu", res$cluster_memory_gb, "GB future:", res$cluster_future_globals_gib, "GiB\n")

  if (isTRUE(args$update_yaml)) {
    cfg$resource_profile <- list(
      num_samples = res$num_samples,
      estimated_cells_per_sample = res$estimated_cells_per_sample,
      total_estimated_cells = res$total_estimated_cells,
      resource_tier = res$resource_tier,
      scale_factor = res$scale_factor
    )
    cfg$future_globals_value_upstream <- res$upstream_future_globals_gib
    cfg$future_globals_value_integrative <- res$integrative_future_globals_gib
    cfg$future_globals_value_clustering <- res$cluster_future_globals_gib
    cfg$future_globals_value_contamination <- res$contamination_future_globals_gib
    cfg$future_globals_value_dego <- res$de_go_future_globals_gib
    write_yaml(cfg, config_path)
    cat("Updated future_globals_* values in", config_path, "\n")
  }

  container_image <- cfg$resource_profile$container_image %||% file.path(snap_root, "rstudio_4.4.0_seurat_4.4.0_latest.sif")
  notify_email <- cfg$CONTACT_EMAIL %||% "user.name@stjude.org"
  payload <- list(resource_estimate = res, sprocket_inputs = build_sprocket_inputs(snap_root, container_image, notify_email, res))

  if (!is.null(args$output)) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install jsonlite")
    dir.create(dirname(normalizePath(args$output, mustWork = FALSE)), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(payload, args$output, auto_unbox = TRUE, pretty = TRUE)
    cat("Wrote", args$output, "\n")
  }
  invisible(payload)
}

if (sys.nframe() == 0L) main()
