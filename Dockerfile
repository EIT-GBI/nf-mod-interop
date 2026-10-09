# syntax=docker/dockerfile:1
ARG DEBIAN_VERSION=13-slim
# For the image label only: the installed version is pinned, with hashes, in
# requirements.txt below. Keep the two in step.
ARG INTEROP_VERSION=1.9.0

# builder #####################################################################
#
# InterOp's Python bindings, numpy and matplotlib all ship as manylinux wheels
# for x86_64 and aarch64, so nothing is compiled. The builder stage installs
# them into a venv at /opt/interop, so the runtime image never carries pip's
# build tooling or python3-venv.
#
# Python is Debian 13's python3 (3.13), the same base as every other nf-mod.
# Automate-Seq-Run-Metrics-Collection runs 3.14, but the packages are the
# versions in its uv.lock.

FROM debian:${DEBIAN_VERSION} AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Everything the image installs, transitive dependencies included, each pinned
# with the sha256 of its CPython 3.13 wheels for x86_64 and aarch64. Versions
# follow the uv.lock of Automate-Seq-Run-Metrics-Collection; to change one,
# update it there too and take the new hashes from
# https://pypi.org/pypi/<name>/<version>/json.
#
# It is inline rather than a separate file on purpose: release.yml and
# build.yml rebuild the image only when the Dockerfile changes, so a version
# bump in another file would re-tag the old image instead.
COPY <<"EOF" /tmp/requirements.txt
interop==1.9.0 \
    --hash=sha256:721e20d54ee9e52559fad7b6c9b1b759d2eba16eede6d0cd31ebcd91afff9c15 \
    --hash=sha256:12acda3aaf2f404ccdcdbbe3b48b65d8a687614623aed6a568431aba2d16aea8
numpy==2.4.3 \
    --hash=sha256:decb0eb8a53c3b009b0962378065589685d66b23467ef5dac16cbe818afde27f \
    --hash=sha256:d5f51900414fc9204a0e0da158ba2ac52b75656e7dce7e77fb9f84bfa343b4cc
matplotlib==3.10.8 \
    --hash=sha256:a0a7f52498f72f13d4a25ea70f35f4cb60642b466cbb0a9be951b5bc3f45a486 \
    --hash=sha256:646d95230efb9ca614a7a594d4fcacde0ac61d25e37dd51710b36477594963ce
contourpy==1.4.0 \
    --hash=sha256:9c0e07c691f3b3321913ed9b8161c50ea5f77fadd006f52f5e755359b0dcbfc5 \
    --hash=sha256:f1219a8898523cba821085f2da8a1b962cc696325763f09d7f93538ba43b2d70
cycler==0.12.1 \
    --hash=sha256:85cef7cff222d8644161529808465972e51340599459b8ac3ccbac5a854e0d30
fonttools==4.66.1 \
    --hash=sha256:1801fdad5600118327171e0e8aa79f7cc48831dd55ab36998c9de03bd5ffe6cd \
    --hash=sha256:83572afe48733bad7a4a9c11721d3a726c2e976d82b063fc9bdd049d76955abd \
    --hash=sha256:7234ae9e28db64273fbbfa72caebd0a97e3bdba6b05064114741b9539ef339d0
kiwisolver==1.5.1 \
    --hash=sha256:74ad5c3dad54a4641b4c28cd15ded70899d04459c6c7aeacafea716be97cce6d \
    --hash=sha256:21e46b23a2da695c364124817bc01d970effd5483147f8d66a6a7167e3f6b851
packaging==26.3 \
    --hash=sha256:d7193f7c8e4e93f444fde0262bf90af30e16fa0ad0ad44cb553c87339b23cd1c
pillow==12.3.0 \
    --hash=sha256:f7401aebd7f581d7f83a439d87d474999317ee099218e5ad25d125290990ba65 \
    --hash=sha256:0847a763afefb695bc912d7c131e7e0632d4edc1d8698f58ddabec8e46b8b6d3
pyparsing==3.3.3 \
    --hash=sha256:ece8c00a69cf01b45d0b1dedabb469c90d8caf996d4fda40f147627a122849a4
python-dateutil==2.9.0.post0 \
    --hash=sha256:a8b2bc7bffae282281c8140a97d3aa9c14da0b136dfe83f850eea9a5f7470427
six==1.17.0 \
    --hash=sha256:4721f391ed90541fddacab5acf947aa0d3dc7d27b2e1e8eda2be8970586c3274
EOF

# --require-hashes: pip refuses any file whose sha256 is not in
# requirements.txt, and any dependency not listed there.
RUN python3 -m venv /opt/interop \
    && /opt/interop/bin/pip install --no-cache-dir --only-binary=:all: \
        --require-hashes -r /tmp/requirements.txt

# runtime #####################################################################

FROM debian:${DEBIAN_VERSION} AS runtime

ARG DEBIAN_VERSION
ARG INTEROP_VERSION

LABEL org.opencontainers.image.title="interop" \
    org.opencontainers.image.description="Illumina InterOp ${INTEROP_VERSION} Python bindings, numpy and matplotlib on debian:${DEBIAN_VERSION}" \
    org.opencontainers.image.version="${INTEROP_VERSION}" \
    org.opencontainers.image.source="https://github.com/Illumina/interop" \
    org.opencontainers.image.licenses="GPL-3.0"

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/interop/bin:${PATH} \
    LC_ALL=C.UTF-8 \
    MPLBACKEND=Agg \
    MPLCONFIGDIR=/opt/matplotlib

# python3 is the interpreter the venv links to, at the same path as in the
# builder. procps is not optional: Nextflow's task wrapper shells out to `ps`
# to collect task metrics, and debian-slim does not carry it.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        procps \
        python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=builder /opt/interop /opt/interop

# Build the matplotlib font cache at image build time, in a fixed world-writable
# directory: tasks run as the calling user (docker -u, Singularity), whose home
# is not writable, and would otherwise rebuild the cache on every run.
RUN mkdir -p "${MPLCONFIGDIR}" \
    && python3 -c "import matplotlib.pyplot" \
    && chmod -R a+rwX "${MPLCONFIGDIR}"

# No ENTRYPOINT: Nextflow invokes the container as `/bin/bash -c ...`.
CMD ["python3", "-c", "import interop; print(interop.__version__)"]
