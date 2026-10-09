// Run-level metrics for one Illumina run, read from the binary InterOp files,
// RunParameters.xml and PrimaryAnalysisMetrics.csv.
//
// Mirrors EIT-GBI/Automate-Seq-Run-Metrics-Collection: same metric set, same
// column names, same %Occupied vs %PF tile plot, so rows from either tool line
// up in one log. The extraction lives in resources/usr/bin/, which Nextflow
// stages into the task and puts on PATH only when the consuming pipeline sets
// `nextflow.enable.moduleBinaries = true`. Without it the task fails with
// "collect_illumina_metrics.py: command not found".

process INTEROP_RUN_METRICS {
    tag "${meta.id}"
    label 'process_low'

    input:
    tuple val(meta), path(run_dir)

    output:
    tuple val(meta), path("${meta.id}.run_metrics.csv"), emit: metrics
    tuple val(meta), path("${meta.id}_run_metrics_mqc.tsv"), emit: mqc_table
    // Only patterned flowcells have per-tile %Occupied, so there is no plot for
    // e.g. a MiSeq run.
    tuple val(meta), path("${meta.id}_occupied_vs_pf_mqc.png"), emit: plot, optional: true
    // The `|| echo` matters: eval() runs even under -stub, and python3 exits
    // non-zero wherever interop is not installed.
    tuple val("${task.process}"), val('interop'), eval('python3 -c "import interop; print(interop.__version__)" 2>/dev/null || echo unknown'), emit: versions_interop, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    collect_illumina_metrics.py \\
        ${args} \\
        --run-dir ${run_dir} \\
        --run-id ${meta.id} \\
        --out-prefix ${meta.id}
    """

    stub:
    """
    touch ${meta.id}.run_metrics.csv
    touch ${meta.id}_run_metrics_mqc.tsv
    touch ${meta.id}_occupied_vs_pf_mqc.png
    """
}
