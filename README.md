# home-assistant-configurator

`home-assistant-configurator` publishes the Runlix container image for [Home Assistant Configurator](https://github.com/danielperna84/hass-configurator).

The current published image name is:

```text
ghcr.io/runlix/home-assistant-configurator
```

Use a versioned stable manifest tag from [release.json](release.json):

```dockerfile
FROM ghcr.io/runlix/home-assistant-configurator:<version>-stable
```

The authoritative published tags, digests, and source revision live in [release.json](release.json).

## What's Included

- `hass-configurator`
- `git`
- `openssh-client`
- `GitPython`
- `pyotp`
- the distroless runtime base from `distroless-runtime-v2-canary`

The image keeps the distroless runtime model while preserving the upstream `/config/settings.conf` startup behavior through a small Python entrypoint shim.

## Branch Layout

`main` owns metadata and automation config:

- `README.md`
- `release.json`
- `renovate.json`
- `.github/workflows/validate-release-metadata.yml`

`release` owns build and publish inputs:

- `.ci/build.json`
- `.ci/smoke-test.sh`
- `linux-*.Dockerfile`
- `.github/workflows/validate-build.yml`
- `.github/workflows/publish-release.yml`

## Release Flow

Changes merge to `release`, where `Publish Release` builds the versioned `stable` and `debug` multi-arch manifests, attests them, optionally sends Telegram, and opens the sync PR back to `main`.

`main` validates metadata and config-only changes with `Validate Release Metadata`.

## Runtime Behavior

If `/config/settings.conf` exists, the container starts `hass-configurator` with that file path exactly like the upstream image.

Expose port `3218/tcp`, mount `/config` for persistent configurator state, and mount `/hass-config` if you want the configurator to work against a Home Assistant configuration directory at the conventional path.
