// TODO: one line on what this process does, and anything non-obvious about how
// it drives the tool (e.g. an output flag that has to stay fixed).

process __PROCESS__ {
    tag "${meta.id}"
    // TODO: process_low / process_medium / process_high. The consuming pipeline
    // defines what each label means; the module never sets cpus or memory itself.
    label 'process_low'

    input:
    // TODO: declare the real inputs
    tuple val(meta), path(input)

    output:
    // TODO: declare the real outputs, one emit per file type
    tuple val(meta), path("${meta.id}.txt"), emit: result
    // Every process reports its tool version on the `versions` topic. eval()
    // runs even under -stub and a non-zero exit fails the task, so keep the
    // command's exit status that of a filter (sed) rather than the tool.
    // TODO: adjust the parsing to the tool's --version output
    tuple val("${task.process}"), val('__NAME__'), eval('__NAME__ --version 2>&1 | head -n 1 | sed "s/^[^0-9]*//"'), emit: versions___NAME_ID__, topic: versions

    script:
    // Flags come from task.ext.args, never from pipeline params, so the module
    // does not depend on any one pipeline's parameter names.
    def args = task.ext.args ?: ''
    // TODO: the real command
    """
    __NAME__ \\
        ${args} \\
        ${input} \\
        > ${meta.id}.txt
    """

    stub:
    """
    touch ${meta.id}.txt
    """
}
