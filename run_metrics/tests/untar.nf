// Test-only helper: unpacks a run-folder tarball from nf-core/test-datasets, so
// INTEROP_RUN_METRICS gets the directory it takes in a real pipeline. Runs on
// the host (tests.config assigns an image to INTEROP_.* only).
//
// `pam` is an optional PrimaryAnalysisMetrics.csv (pass [] for none), placed
// where a NextSeq 2000 writes it. No public NextSeq 2000 run folder exists, so
// this is how the tests reach the code that reads it.

process UNTAR {
    tag "${meta.id}"

    input:
    tuple val(meta), path(archive)
    path pam, stageAs: 'pam/*'

    output:
    tuple val(meta), path("${meta.id}"), emit: dir

    script:
    def add_pam = pam ? "mkdir ${meta.id}/PrimaryAnalysisMetrics && cp ${pam} ${meta.id}/PrimaryAnalysisMetrics/PrimaryAnalysisMetrics.csv" : ''
    """
    mkdir ${meta.id}
    tar -xzf ${archive} -C ${meta.id} --strip-components 1
    ${add_pam}
    """
}
