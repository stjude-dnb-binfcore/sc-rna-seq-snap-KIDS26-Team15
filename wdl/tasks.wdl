version 1.1

# Task wrappers for sc-rna-seq-snap modules starting at upstream-analysis.
# Assumes FastQC and Cell Ranger have already completed.

task run_upstream {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 16
    Int memory_gb = 30
    Int future_globals_gib = 200
    String lsf_queue = "standard"
  }

  command <<<
    set -euo pipefail
    cd "~{snap_root}/analyses/upstream-analysis"
    singularity exec ~{container_image} bash run-upstream-analysis.sh
    echo "done" > upstream.done
  >>>

  output {
    File done_flag = "upstream.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "Upstream Seurat QC module"
    future_globals_gib: future_globals_gib
  }
}

task run_integrative {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 10
    Int memory_gb = 96
    Int future_globals_gib = 200
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/integrative-analysis"
    singularity exec ~{container_image} bash run-integrative-analysis.sh
    echo "done" > integrative.done
  >>>

  output {
    File done_flag = "integrative.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "Integrative analysis module"
    future_globals_gib: future_globals_gib
  }
}

task run_cluster {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 4
    Int memory_gb = 48
    Int future_globals_gib = 400
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/cluster-cell-calling"
    singularity exec ~{container_image} bash run-cluster-cell-calling.sh
    echo "done" > cluster.done
  >>>

  output {
    File done_flag = "cluster.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "Cluster cell calling module"
    future_globals_gib: future_globals_gib
  }
}

task run_contamination_removal {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 8
    Int memory_gb = 96
    Int future_globals_gib = 400
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/cell-contamination-removal-analysis"
    singularity exec ~{container_image} bash run-cell-contamination-removal-analysis.sh
    echo "done" > contamination.done
  >>>

  output {
    File done_flag = "contamination.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "Cell contamination removal module"
    future_globals_gib: future_globals_gib
  }
}

task run_cell_types {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 4
    Int memory_gb = 64
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/cell-types-annotation"
    singularity exec ~{container_image} bash run-cell-types-annotation.sh
    echo "done" > cell_types.done
  >>>

  output {
    File done_flag = "cell_types.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "Cell types annotation module"
  }
}

task run_clone_phylogeny {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 16
    Int memory_gb = 30
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/clone-phylogeny-analysis"
    singularity exec ~{container_image} bash run-clone-phylogeny-analysis.sh
    echo "done" > clone_phylogeny.done
  >>>

  output {
    File done_flag = "clone_phylogeny.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "Clone phylogeny analysis module"
  }
}

task run_de_go {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 4
    Int memory_gb = 32
    Int future_globals_gib = 200
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/de-go-analysis"
    singularity exec ~{container_image} bash run-de-go-analysis.sh
    echo "done" > de_go.done
  >>>

  output {
    File done_flag = "de_go.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "DE and GO analysis module"
    future_globals_gib: future_globals_gib
  }
}

task run_rshiny {
  input {
    String snap_root
    String container_image
    String notify_email
    Int cpu = 4
    Int memory_gb = 30
    String lsf_queue = "standard"
    File? wait_on = none
  }

  command <<<
    set -euo pipefail
    if [ -n "~{wait_on}" ]; then echo "Previous step: ~{wait_on}"; fi
    cd "~{snap_root}/analyses/rshiny-app"
    singularity exec ~{container_image} bash run-rshiny-app.sh
    echo "done" > rshiny.done
  >>>

  output {
    File done_flag = "rshiny.done"
  }

  runtime {
    cpu: cpu
    memory: "~{memory_gb} GB"
    queue: lsf_queue
  }

  meta {
    description: "R Shiny app packaging module"
  }
}
