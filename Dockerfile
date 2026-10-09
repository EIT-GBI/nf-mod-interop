ARG PYTHON_VERSION=3.14
# Kept identical to the uv.lock of EIT-GBI/Automate-Seq-Run-Metrics-Collection,
# so this module and that collector read InterOp with the same library.
ARG INTEROP_VERSION=1.9.0
ARG NUMPY_VERSION=2.4.3
ARG MATPLOTLIB_VERSION=3.10.8

# InterOp ships its Python bindings as manylinux wheels for x86_64 and aarch64,
# so there is nothing to compile and no builder stage: pip installs the pinned
# wheels straight into the runtime image. Older InterOp releases (e.g. 1.3.2)
# have no aarch64 wheel and fail the arm64 build.

FROM python:${PYTHON_VERSION}-slim

ARG PYTHON_VERSION
ARG INTEROP_VERSION
ARG NUMPY_VERSION
ARG MATPLOTLIB_VERSION

LABEL org.opencontainers.image.title="interop" \
    org.opencontainers.image.description="Illumina InterOp ${INTEROP_VERSION} Python bindings, numpy and matplotlib on python:${PYTHON_VERSION}-slim" \
    org.opencontainers.image.version="${INTEROP_VERSION}" \
    org.opencontainers.image.source="https://github.com/Illumina/interop" \
    org.opencontainers.image.licenses="GPL-3.0"

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    MPLBACKEND=Agg \
    MPLCONFIGDIR=/opt/matplotlib

# procps is not optional: Nextflow's task wrapper shells out to `ps` to collect
# task metrics, and debian-slim does not carry it.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN pip install --no-cache-dir --only-binary=:all: \
        "interop==${INTEROP_VERSION}" \
        "numpy==${NUMPY_VERSION}" \
        "matplotlib==${MATPLOTLIB_VERSION}"

# Build the matplotlib font cache at image build time, in a fixed world-readable
# directory: tasks run as the calling user (docker -u, Singularity), whose home
# is not writable, and would otherwise rebuild the cache on every run.
RUN mkdir -p "${MPLCONFIGDIR}" \
    && python -c "import matplotlib.pyplot" \
    && chmod -R a+rwX "${MPLCONFIGDIR}"

# No ENTRYPOINT: Nextflow invokes the container as `/bin/bash -c ...`.
CMD ["python", "-c", "import interop; print(interop.__version__)"]
