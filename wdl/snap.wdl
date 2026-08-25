version 1.1

import "tasks.wdl" as snap

# Downstream snap workflow: upstream-analysis through rshiny-app.
# Assumes FastQC and Cell Ranger are already complete.

workflow sc_rna_seq_snap_downstream {
  meta {
    description: "Resource-aware orchestration of snap modules from upstream onwards"
    author: "DNB Bioinformatics Core / KIDS26 Team 15"
  }

  input {
    String snap_root
    String container_image
    String notify_email = "user.name@stjude.org"

    Boolean run_upstream = true
    Boolean run_integrative = true
    Boolean run_cluster = true
    Boolean run_contamination_removal = false
    Boolean run_cell_types = true
    Boolean run_clone_phylogeny = false
    Boolean run_de_go = true
    Boolean run_rshiny = true

    Int num_samples = 8
    Int estimated_cells_per_sample = 50000

    Int upstream_cpu = 16
    Int upstream_memory_gb = 30
    Int upstream_future_globals_gib = 200
    String upstream_lsf_queue = "standard"

    Int integrative_cpu = 10
    Int integrative_memory_gb = 96
    Int integrative_future_globals_gib = 200
    String integrative_lsf_queue = "standard"

    Int cluster_cpu = 4
    Int cluster_memory_gb = 48
    Int cluster_future_globals_gib = 400
    String cluster_lsf_queue = "standard"

    Int contamination_cpu = 8
    Int contamination_memory_gb = 96
    Int contamination_future_globals_gib = 400
    String contamination_lsf_queue = "standard"

    Int cell_types_cpu = 4
    Int cell_types_memory_gb = 64
    String cell_types_lsf_queue = "standard"

    Int clone_phylogeny_cpu = 16
    Int clone_phylogeny_memory_gb = 30
    String clone_phylogeny_lsf_queue = "standard"

    Int de_go_cpu = 4
    Int de_go_memory_gb = 32
    Int de_go_future_globals_gib = 200
    String de_go_lsf_queue = "standard"

    Int rshiny_cpu = 4
    Int rshiny_memory_gb = 30
    String rshiny_lsf_queue = "standard"
  }

  Int total_estimated_cells = num_samples * estimated_cells_per_sample
  File? chain_done = none

  if (run_upstream) {
    call snap.run_upstream as upstream {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = upstream_cpu,
        memory_gb = upstream_memory_gb,
        future_globals_gib = upstream_future_globals_gib,
        lsf_queue = upstream_lsf_queue,
    }
  }

  File? upstream_done = if (run_upstream) then upstream.done_flag else chain_done

  if (run_integrative) {
    call snap.run_integrative as integrative {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = integrative_cpu,
        memory_gb = integrative_memory_gb,
        future_globals_gib = integrative_future_globals_gib,
        lsf_queue = integrative_lsf_queue,
        wait_on = upstream_done,
    }
  }

  File? integrative_done = if (run_integrative) then integrative.done_flag else upstream_done

  if (run_cluster) {
    call snap.run_cluster as cluster {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = cluster_cpu,
        memory_gb = cluster_memory_gb,
        future_globals_gib = cluster_future_globals_gib,
        lsf_queue = cluster_lsf_queue,
        wait_on = integrative_done,
    }
  }

  File? cluster_done = if (run_cluster) then cluster.done_flag else integrative_done

  if (run_contamination_removal) {
    call snap.run_contamination_removal as contamination {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = contamination_cpu,
        memory_gb = contamination_memory_gb,
        future_globals_gib = contamination_future_globals_gib,
        lsf_queue = contamination_lsf_queue,
        wait_on = cluster_done,
    }
  }

  File? contamination_done = if (run_contamination_removal) then contamination.done_flag else cluster_done

  if (run_cell_types) {
    call snap.run_cell_types as cell_types {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = cell_types_cpu,
        memory_gb = cell_types_memory_gb,
        lsf_queue = cell_types_lsf_queue,
        wait_on = contamination_done,
    }
  }

  File? cell_types_done = if (run_cell_types) then cell_types.done_flag else contamination_done

  if (run_clone_phylogeny) {
    call snap.run_clone_phylogeny as clone_phylogeny {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = clone_phylogeny_cpu,
        memory_gb = clone_phylogeny_memory_gb,
        lsf_queue = clone_phylogeny_lsf_queue,
        wait_on = cell_types_done,
    }
  }

  File? clone_phylogeny_done = if (run_clone_phylogeny) then clone_phylogeny.done_flag else cell_types_done

  if (run_de_go) {
    call snap.run_de_go as de_go {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = de_go_cpu,
        memory_gb = de_go_memory_gb,
        future_globals_gib = de_go_future_globals_gib,
        lsf_queue = de_go_lsf_queue,
        wait_on = clone_phylogeny_done,
    }
  }

  File? de_go_done = if (run_de_go) then de_go.done_flag else clone_phylogeny_done

  if (run_rshiny) {
    call snap.run_rshiny as rshiny {
      input:
        snap_root = snap_root,
        container_image = container_image,
        notify_email = notify_email,
        cpu = rshiny_cpu,
        memory_gb = rshiny_memory_gb,
        lsf_queue = rshiny_lsf_queue,
        wait_on = de_go_done,
    }
  }

  output {
    Int cohort_num_samples = num_samples
    Int cohort_total_estimated_cells = total_estimated_cells
    File? upstream_done_flag = upstream_done
    File? integrative_done_flag = integrative_done
    File? cluster_done_flag = cluster_done
    File? contamination_done_flag = contamination_done
    File? cell_types_done_flag = cell_types_done
    File? clone_phylogeny_done_flag = clone_phylogeny_done
    File? de_go_done_flag = de_go_done
    File? rshiny_done_flag = rshiny.done_flag
  }
}
