ARG BUILDER_REF="docker.io/library/debian:bookworm-slim@sha256:13cb01d584d2c23f475c088c168a48f9a08f033a10460572fbfd10912ec5ba7c"
ARG BASE_REF="ghcr.io/runlix/distroless-runtime-v2-canary:stable@sha256:a39da96f68c2145594b573baeed3858c9f032e186997efdba9a005cc79563cb9"
ARG HC_BUILD_VERSION="0.5.2"
ARG GITPYTHON_VERSION="3.1.46"
ARG PYOTP_VERSION="2.9.0"

FROM ${BUILDER_REF} AS configurator-deps

ARG GITPYTHON_VERSION
ARG HC_BUILD_VERSION
ARG PYOTP_VERSION

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      openssh-client \
      python3 \
      python3-pip \
 && pip3 install --no-cache-dir --break-system-packages \
      "hass-configurator==${HC_BUILD_VERSION}" \
      "gitpython==${GITPYTHON_VERSION}" \
      "pyotp==${PYOTP_VERSION}" \
 && rm -rf /var/lib/apt/lists/*

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

FROM ${BASE_REF}

ARG LIB_DIR="x86_64-linux-gnu"

COPY --from=configurator-deps /app/entrypoint.py /app/entrypoint.py

COPY --from=configurator-deps /usr/bin/python3 /usr/bin/python3
COPY --from=configurator-deps /usr/bin/python3.11 /usr/bin/python3.11
COPY --from=configurator-deps /usr/lib/python3.11 /usr/lib/python3.11
COPY --from=configurator-deps /usr/lib/${LIB_DIR}/libpython3.11.so.* /usr/lib/${LIB_DIR}/
COPY --from=configurator-deps /usr/local/lib/python3.11/dist-packages /usr/local/lib/python3.11/dist-packages
COPY --from=configurator-deps /usr/local/bin/hass-configurator /usr/local/bin/hass-configurator

COPY --from=configurator-deps /usr/bin/git /usr/bin/git
COPY --from=configurator-deps /usr/bin/ssh /usr/bin/ssh
COPY --from=configurator-deps /usr/bin/ssh-keyscan /usr/bin/ssh-keyscan
COPY --from=configurator-deps /usr/lib/git-core /usr/lib/git-core
COPY --from=configurator-deps /etc/ssh/ssh_config /etc/ssh/ssh_config

COPY --from=configurator-deps /usr/lib/${LIB_DIR}/ /usr/lib/${LIB_DIR}/

WORKDIR /app
USER 65532:65532
EXPOSE 3218
VOLUME ["/config"]
ENTRYPOINT ["/usr/bin/python3", "/app/entrypoint.py"]
