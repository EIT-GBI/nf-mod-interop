ARG DEBIAN_VERSION=13-slim
# TODO: pin the version, and set the checksum of the release archive
# (remove this TODO line once pinned — the CI build and release are gated on its absence)
ARG TOOL_VERSION=0.0.0
ARG TOOL_SHA256=0000000000000000000000000000000000000000000000000000000000000000

# builder #####################################################################
#
# Download a pinned upstream release, verify it, and build it here, so the
# runtime image never carries a compiler, curl or the source tree.
#
# This stage assumes a source tarball built with make. Adapt it to the tool:
#   - prebuilt binary:  skip the build, just install it   (nf-mod-modkit)
#   - jar + launcher:   unpack only                        (nf-mod-fastqc)
#   - bioconda-only:    micromamba with a pinned version, plus procps from apt
#                       (nf-mod-minimap2) — a last resort, the image is larger

FROM debian:${DEBIAN_VERSION} AS builder

ARG TOOL_VERSION
ARG TOOL_SHA256
# TODO: the upstream release URL
ARG TOOL_URL="https://github.com/TODO/__NAME__/archive/refs/tags/v${TOOL_VERSION}.tar.gz"

ENV DEBIAN_FRONTEND=noninteractive

# TODO: add the tool's build dependencies (e.g. zlib1g-dev, libbz2-dev)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build

RUN curl -fsSL --retry 3 -o "__NAME__.tar.gz" "${TOOL_URL}" \
    && echo "${TOOL_SHA256}  __NAME__.tar.gz" | sha256sum -c - \
    && tar -xzf __NAME__.tar.gz \
    && cd "__NAME__-${TOOL_VERSION}" \
    && make -j"$(nproc)" \
    && install -Dm755 __NAME__ /opt/__NAME__/bin/__NAME__ \
    && strip /opt/__NAME__/bin/__NAME__ || true

# runtime #####################################################################

FROM debian:${DEBIAN_VERSION} AS runtime

ARG DEBIAN_VERSION
ARG TOOL_VERSION

# TODO: the upstream source URL and licence
LABEL org.opencontainers.image.title="__NAME__" \
    org.opencontainers.image.description="__NAME__ on debian:${DEBIAN_VERSION}" \
    org.opencontainers.image.version="${TOOL_VERSION}" \
    org.opencontainers.image.source="https://github.com/TODO/__NAME__" \
    org.opencontainers.image.licenses="TODO"

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/__NAME__/bin:${PATH} \
    LC_ALL=C.UTF-8

# procps is not optional: Nextflow's task wrapper shells out to `ps` to collect
# task metrics, and debian-slim does not carry it.
# TODO: add the tool's runtime libraries (the non -dev counterparts of the above)
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=builder /opt/__NAME__ /opt/__NAME__

# No ENTRYPOINT: Nextflow invokes the container as `/bin/bash -c ...`, and an
# ENTRYPOINT of ["__NAME__"] would turn that into `__NAME__ /bin/bash`.
CMD ["__NAME__", "--version"]
