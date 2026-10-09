# nf-mod-__NAME__

<!-- TEMPLATE:START -->
> **Template repo.** Create a new module via GitHub's "Use this template", naming it `nf-mod-<tool>`. The `init-from-template` workflow auto-runs on the first push: it derives `<tool>` from the repo name, replaces the `__NAME__`-style tokens, renames `__SUB__/` to `<tool>/`, strips this block, and removes itself.
>
> Manual fallback (e.g. running locally before pushing, or if the repo name doesn't start with `nf-mod-`): `./scripts/init.sh <tool> [subcommand]`.
>
> Afterwards:
>
> 1. Pin the tool in `Dockerfile` and delete the `# TODO: pin the version` line. Builds and releases are gated on it being gone.
> 2. Fill in the `TODO`s in `<tool>/main.nf` and `<tool>/meta.yml` for the real inputs, command and outputs.
> 3. For another subcommand, copy `<tool>/` to `<subcommand>/` and rename the process to `<TOOL>_<SUBCOMMAND>`.
> 4. Add a test that runs the tool for real next to the stub test. `nf-mod-fastqc` is the worked example.
> 5. Put the tool name and a description in the paragraph below.
>
> Before writing a new module, check the org for an existing `nf-mod-*` repo.
<!-- TEMPLATE:END -->

Nextflow module for __NAME__. Used as a git submodule by pipelines.

Image: `ghcr.io/eit-gbi/nf-mod-__NAME__:v0.0.0`

## Processes

Each subcommand lives in its own folder, with a `main.nf`, a `meta.yml` and an
nf-test case under `tests/`.

| Process | Path | Inputs | Emits |
| --- | --- | --- | --- |
| `__PROCESS__` | `__SUB__/main.nf` | `tuple val(meta), path(input)` | `result`, `versions___NAME_ID__` |

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
    withName: __PROCESS__ {
        ext.args = '--some-flag'
    }
}
```

## Use as submodule

Pin to a release tag rather than a branch, so pipeline runs stay reproducible:

```bash
git submodule add https://github.com/EIT-GBI/nf-mod-__NAME__.git modules/__NAME__
git -C modules/__NAME__ checkout v0.0.0
```

Record the same version in the pipeline's `modules.versions`
(`nf-mod-__NAME__=<version>`). That file is the source of truth, and the pipeline's
sync workflow moves the submodule to match it.

Include the module's container config from your `nextflow.config`. Nextflow
does not read a submodule's config on its own, so without this line the
processes have no image:

```groovy
includeConfig 'modules/__NAME__/conf/module.config'
```

`conf/module.config` pins the image to the version built from this same commit,
and carries no `manifest {}` block, so it will not overwrite your pipeline's own
manifest. Override it in your pipeline with a `withName` selector if you need to.

Then include the processes:

```groovy
include { __PROCESS__ } from './modules/__NAME__/__SUB__/main.nf'
```

## Requirements

Nextflow 26.04.4 or newer. The code is written in Nextflow's strict syntax and
is linted with `nextflow lint` in CI.

## Tests

```bash
nf-test test
```

The stub test checks wiring and output names, and needs no container. Tests
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
