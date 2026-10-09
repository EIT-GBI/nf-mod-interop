// Test-only helper: unpacks a run-folder tarball from nf-core/test-datasets, so
// INTEROP_RUN_METRICS gets the directory it takes in a real pipeline. Runs on
// the host (tests.config assigns an image to INTEROP_.* only).

process UNTAR {
    tag "${meta.id}"

    input:
    tuple val(meta), path(archive)

    output:
    tuple val(meta), path("${meta.id}"), emit: dir

    script:
    """
    mkdir ${meta.id}
    tar -xzf ${archive} -C ${meta.id} --strip-components 1
    """
}
