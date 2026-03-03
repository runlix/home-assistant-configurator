# home-assistant-configurator

Kubernetes-native distroless Docker image for [Home Assistant Configurator](https://github.com/danielperna84/hass-configurator), based on [CausticLab/hass-configurator-docker](https://github.com/CausticLab/hass-configurator-docker).

## Purpose

Provides a minimal, secure Docker image for running Home Assistant Configurator in Kubernetes environments.

## Features

- Distroless base (no shell, minimal attack surface)
- Kubernetes-native permissions (no s6-overlay)
- Read-only root filesystem support
- Non-root execution
- Preserves upstream `settings.conf` startup behavior

## Usage

```bash
docker run -d \
  --name home-assistant-configurator \
  -p 3218:3218 \
  -v /path/to/configurator:/config \
  -v /path/to/homeassistant-config:/hass-config \
  ghcr.io/runlix/home-assistant-configurator:release-latest
```

If `/config/settings.conf` exists, it is passed to `hass-configurator` exactly like the upstream image.
