# Builder image and tag from docker-matrix.json
ARG BUILDER_IMAGE=docker.io/library/debian
ARG BUILDER_TAG=bookworm-slim
# Base image and tag from docker-matrix.json
ARG BASE_IMAGE=ghcr.io/runlix/distroless-runtime
ARG BASE_TAG=stable
# Selected digests (build script will set based on target configuration)
# Default to empty string - build script should always provide valid digests
# If empty, FROM will fail (which is desired to enforce digest pinning)
ARG BUILDER_DIGEST=""
ARG BASE_DIGEST=""
# hass-configurator version from docker-matrix.json
ARG HC_BUILD_VERSION=0.5.2

# STAGE 1 — install hass-configurator and runtime dependencies
FROM ${BUILDER_IMAGE}:${BUILDER_TAG}@${BUILDER_DIGEST} AS configurator-deps

ARG HC_BUILD_VERSION

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    openssh-client \
    python3 \
    python3-pip \
 && pip3 install --no-cache-dir --break-system-packages \
    hass-configurator==${HC_BUILD_VERSION} \
    gitpython \
    pyotp \
 && rm -rf /var/lib/apt/lists/*

# Replicates upstream run.sh behavior without requiring a shell in distroless.
RUN mkdir -p /app \
 && cat > /app/entrypoint.py <<'PYEOF'
import os
import os.path

config = "/config/settings.conf"
cmd = ["/usr/local/bin/hass-configurator"]
if os.path.isfile(config):
    cmd.append(config)
os.execv(cmd[0], cmd)
PYEOF

# STAGE 2 — distroless final image
FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

# Hardcoded for arm64 - no conditionals needed!
ARG LIB_DIR=aarch64-linux-gnu

COPY --from=configurator-deps /app/entrypoint.py /app/entrypoint.py

# Python runtime and installed packages
COPY --from=configurator-deps /usr/bin/python3 /usr/bin/python3
COPY --from=configurator-deps /usr/bin/python3.11 /usr/bin/python3.11
COPY --from=configurator-deps /usr/lib/python3.11 /usr/lib/python3.11
COPY --from=configurator-deps /usr/lib/${LIB_DIR}/libpython3.11.so.* /usr/lib/${LIB_DIR}/
COPY --from=configurator-deps /usr/local/lib/python3.11/dist-packages /usr/local/lib/python3.11/dist-packages
COPY --from=configurator-deps /usr/local/bin/hass-configurator /usr/local/bin/hass-configurator

# Keep git/ssh integration compatible with upstream image behavior.
COPY --from=configurator-deps /usr/bin/git /usr/bin/git
COPY --from=configurator-deps /usr/bin/ssh /usr/bin/ssh
COPY --from=configurator-deps /usr/bin/ssh-keyscan /usr/bin/ssh-keyscan
COPY --from=configurator-deps /usr/lib/git-core /usr/lib/git-core
COPY --from=configurator-deps /etc/ssh/ssh_config /etc/ssh/ssh_config

# Copy dependency libraries required by Python, git and ssh.
COPY --from=configurator-deps /usr/lib/${LIB_DIR}/ /usr/lib/${LIB_DIR}/

WORKDIR /app
USER 65532:65532
EXPOSE 3218
VOLUME ["/config"]
ENTRYPOINT ["/usr/bin/python3", "/app/entrypoint.py"]
