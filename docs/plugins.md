# Plugin maintainer guide

This guide describes how plugin support is implemented in this repository and what maintainers need to validate when adding or updating a plugin. The current image stages upstream SSO and monitoring sources at build time; `CPAD_PLUGINS` controls which staged directories are activated when the container starts.

## Confirmed repository behavior

- The Dockerfile downloads sources into `/cryptpad/plugins-store/<name>`. It currently uses the SSO release tag and a full monitoring commit SHA, unpacks each archive, checks each plugin's `package.json` version against a build argument, and installs production dependencies.
- The image's runtime user is `cryptpad`. The Dockerfile assigns ownership of `/cryptpad/plugins-store`, `/cryptpad/lib/plugins`, and `/cryptpad/config` to UID/GID `4001:4001` before switching to that user.
- The entrypoint wrapper parses comma-separated `CPAD_PLUGINS`, trims whitespace, and accepts only names containing ASCII letters, digits, `.`, `_`, or `-`, except the special names `.` and `..` are rejected. Unsafe names are logged and ignored. Names without a matching directory under `/cryptpad/plugins-store` are warned about and skipped.
- For each accepted, existing plugin directory, the wrapper removes any active copy at `/cryptpad/lib/plugins/<name>`, copies the staged directory there, and logs that it staged the plugin. An empty or unset `CPAD_PLUGINS` stages no plugins.
- `versions.json` currently records CryptPad, SSO, and monitoring pins, plus known CryptPad-to-SSO compatibility pairs. The build workflow reads these values and passes the corresponding build arguments to the Dockerfile.

## Add a plugin to the image

1. Choose a stable plugin name for the staging directory and the `CPAD_PLUGINS` entry. It must pass the wrapper's safe-name rules above.
2. Pin each source to a full commit SHA or a verified archive digest. A release tag is a human-readable version label, not an immutable pin; if you use one, resolve it to a commit or verify the archive digest and record that immutable identifier alongside the release version. The current Dockerfile fetches SSO by release tag (its package-version check does not make the source immutable) and monitoring by full commit SHA.
3. Extend the Dockerfile to fetch and unpack the pinned source into `/cryptpad/plugins-store/<name>`. Add build arguments for the plugin's pin(s), and validate its package version against the expected version where the upstream package declares one, following the existing `test ... package.json ...` pattern. If the source has no release/tag, pin its commit separately from its package version, as monitoring does.
4. Install runtime dependencies in that staged directory with development dependencies omitted, if the plugin requires dependency installation. The current SSO and monitoring steps use npm; choose and validate the appropriate install process for the new plugin rather than assuming every plugin uses npm.
5. Preserve ownership for runtime staging: include the new directory in the Dockerfile's recursive `chown` to `4001:4001`. The wrapper runs as the non-root CryptPad user, so the image's staged source and writable active-plugin location must be usable by that user.
6. Add the new version/ref metadata to `versions.json`, and wire the corresponding fields through `.github/workflows/build.yml` into Docker build arguments. The existing workflow currently wires only `cryptpad`, `sso`, `monitoring`, and `monitoring_ref`; adding a JSON field alone does not make it a build pin.
7. Document the plugin name, pin, and any verified CryptPad compatibility requirements. Do not infer compatibility from the existence of a source release.

## Pins, workflow behavior, and compatibility

`versions.json` is the source of truth for the current build pins. The build workflow reads it, creates the `latest`, CryptPad-version, and full version/ref tags, then builds and publishes for `linux/amd64` and `linux/arm64`. Its push path filters include `Dockerfile`, `entrypoint-wrapper.sh`, and `versions.json`; it also supports manual dispatch and workflow calls. When adding pin fields, keep the workflow's extraction, outputs, and Docker build-args in sync, and update any image metadata/tagging that should identify the new pin.

The scheduled **Check upstream versions** workflow currently checks CryptPad, SSO, and monitoring only. It requires an entry in `versions.json`'s `sso_compat` map before it considers the latest CryptPad release safe to pin/build; it does not establish compatibility for arbitrary new plugins. For a new plugin, or a CryptPad/plugin version change, maintainers must check the relevant upstream compatibility information and record verified constraints. Extend the updater only if automated tracking of the new plugin is intended; do not assume it will discover or pin it automatically.

## Maintainer validation

The following are validation tasks, not guarantees made by the wrapper or version updater:

- Confirm the selected source ref is immutable and corresponds to the intended plugin release/commit; verify its package metadata and runtime dependency installation.
- Build the image with the new Dockerfile/workflow pins and confirm the build-time version check succeeds where applicable.
- Start the image with that plugin name in `CPAD_PLUGINS` and confirm the wrapper logs `staged plugin "<name>"`. Also check the behavior for an empty selection and an unknown name; the wrapper's documented skip behavior does not prove plugin functionality.
- Test the plugin against each CryptPad version you intend to support, including its runtime configuration and expected operation. Record verified compatibility rather than treating a successful image build as compatibility evidence.
- Check ownership and runtime writes with the image's non-root user and the deployment's read-only/tmpfs setup. The deployment guide documents the `/cryptpad/lib/plugins` tmpfs requirement for activating plugins in that setup.

The build workflow's existing `workflow_dispatch` path can be used for manual image builds, but it consumes the pins currently committed in `versions.json`; maintainers must ensure the Dockerfile and workflow have first been wired for any new plugin.
