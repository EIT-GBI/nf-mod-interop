# nf-mod-interop

Nextflow module for Illumina run-level QC metrics read from the binary InterOp
files. Used as a git submodule by pipelines (first: nf-seQC).

`INTEROP_RUN_METRICS` mirrors
[Automate-Seq-Run-Metrics-Collection](https://github.com/EIT-GBI/Automate-Seq-Run-Metrics-Collection),
the cron-based collector for the NextSeq 2000: same metric set, same column
names (`LOG_COLUMNS`) and same %Occupied vs %PF plot, so rows from both tools
concatenate into one log. **Keep `LOG_COLUMNS` in
`run_metrics/resources/usr/bin/collect_illumina_metrics.py` in sync with that
repo's `utils.py`**, and keep the InterOp, numpy and matplotlib pins in the
Dockerfile in step with its `uv.lock`. The script's docstring lists where it
deliberately differs.

Image: `ghcr.io/eit-gbi/nf-mod-interop:v0.0.0`

## Processes

Each subcommand lives in its own folder, with a `main.nf`, a `meta.yml` and an
nf-test case under `tests/`.

| Process | Path | Inputs | Emits |
| --- | --- | --- | --- |
| `INTEROP_RUN_METRICS` | `run_metrics/main.nf` | `tuple val(meta), path(run_dir)` | `metrics`, `mqc_table`, `plot` (optional), `versions_interop` |

Every process publishes its tool version on the `versions` topic as
`[process, tool, version]`.

## Publishing

These processes do **not** publish their own outputs, and must never declare
`publishDir`. Publishing is the consuming pipeline's job, via a workflow
`output {}` block. A module that also sets `publishDir` publishes everything
twice.

## Resources

Processes carry a `process_low` / `process_medium` / `process_high` label and
no `cpus` or `memory` of their own. The consuming pipeline decides what each
label means.

## Tool arguments

Flags are passed through `task.ext.args` (and `args2`/`args3` where a process
runs more than one command) rather than read from pipeline `params`, so the
module never depends on a particular pipeline's parameter names:

```groovy
process {
    withName: INTEROP_RUN_METRICS {
        ext.args = '--some-flag'
    }
}
```

## Use as submodule

Pin to a release tag rather than a branch, so pipeline runs stay reproducible:

```bash
git submodule add https://github.com/EIT-GBI/nf-mod-interop.git modules/interop
git -C modules/interop checkout v0.0.0
```

Record the same version in the pipeline's `modules.versions`
(`nf-mod-interop=<version>`). That file is the source of truth, and the pipeline's
sync workflow moves the submodule to match it.

Include the module's container config from your `nextflow.config`. Nextflow
does not read a submodule's config on its own, so without this line the
processes have no image:

```groovy
includeConfig 'modules/interop/conf/module.config'
```

`INTEROP_RUN_METRICS` runs a Python script shipped in
`run_metrics/resources/usr/bin/`. Nextflow stages that folder into the task and
puts it on `PATH` only when module binaries are enabled, so the pipeline's
`nextflow.config` also needs:

```groovy
nextflow.enable.moduleBinaries = true
```

Without it the task fails with `collect_illumina_metrics.py: command not
found`. The script deliberately lives in the repo rather than in the image:
releases rebuild the image only when the Dockerfile changes, so a script fix
baked into the image would ship in a stale one.

`conf/module.config` pins the image to the version built from this same commit,
and carries no `manifest {}` block, so it will not overwrite your pipeline's own
manifest. Override it in your pipeline with a `withName` selector if you need to.

Then include the processes:

```groovy
include { INTEROP_RUN_METRICS } from './modules/interop/run_metrics/main.nf'
```

## Requirements

Nextflow 26.04.4 or newer. The code is written in Nextflow's strict syntax and
is linted with `nextflow lint` in CI.

## Tests

```bash
nf-test test
```

The stub test checks wiring and output names, and needs no container. The
other tests unpack two real run folders from nf-core/test-datasets (a NovaSeq
patterned flowcell and a MiSeq) and snapshot the metric rows. Tests
that run the tool for real use `tests.config`, which resolves the image through
`conf/module.config` and needs Docker. In CI, the image is built from this
commit's Dockerfile under that exact tag first, so the tests run against the
Dockerfile under review rather than whatever was last published.

## Releasing

Merging a PR to `main` with exactly one `bump:patch`, `bump:minor` or
`bump:major` label bumps `manifest.version` in `nextflow.config`. It also
rewrites the image tag in `conf/module.config` and this README to match, then
tags the release and builds or re-tags the container image. The image is
rebuilt only when the Dockerfile has changed since the last release. The
release can also be run by hand from the Actions tab.

Every workflow that pushes to `main` (or reads other repos) uses a token from
the **eit-gbi-release-bot** GitHub App, read from the org secrets
`RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY`. For a new repo to release, the
app must be installed on it and be on its `main` ruleset's bypass list. The
default `GITHUB_TOKEN` cannot bypass rulesets.
