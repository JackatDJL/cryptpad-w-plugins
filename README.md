# CryptPad with selectable plugins

This image is based on the official CryptPad container and ships the upstream SSO plugin (OIDC/SAML) and Prometheus monitoring plugin; both are disabled unless selected with the comma-separated `CPAD_PLUGINS` environment variable. At startup the wrapper copies only the requested plugins from the image's immutable staging store into `/cryptpad/lib/plugins` before handing control to CryptPad.

For a standalone setup walkthrough, see the [deployment guide](docs/deployment.md).
For instructions on adding or updating plugins, see the [plugin maintainer guide](docs/plugins.md).

## Version matrix and image tags

`versions.json` is the source of truth. Its CryptPad value is the exact Docker Hub tag; the build workflow passes these pins to the Dockerfile.

| Image tag | CryptPad Docker tag | SSO | Monitoring |
| --- | --- | --- | --- |
| `ghcr.io/jackatdjl/cryptpad-w-plugins:latest` | `version-2026.10.0` | `1.0.0` | `0.0.2` at `7751529` |
| `ghcr.io/jackatdjl/cryptpad-w-plugins:cpad-2026.10.0` | `version-2026.10.0` | `1.0.0` | `0.0.2` at `7751529` |
| `ghcr.io/jackatdjl/cryptpad-w-plugins:cpad-2026.10.0-sso-1.0.0-mon-0.0.2-ref-7751529` | `version-2026.10.0` | `1.0.0` | `0.0.2` at `7751529` |

The `cpad-` tag removes Docker Hub's `version-` prefix. The full pin tag records all plugin versions and the monitoring commit because that repository currently has no release/tag. The known SSO compatibility pairs are recorded in `sso_compat` in `versions.json`; the CryptPad keys retain the `version-` prefix.

Monitoring plugin `package.json` currently reports `0.0.2`, but the project has no GitHub release or tag. The image therefore pins its current default-branch source to immutable commit `775152911dfb7007d0f1eadab1d2f9e7b09fb376`; the update checker polls the branch commit and package version until upstream publishes a release/tag. GHCR package: [cryptpad-w-plugins](https://github.com/JackatDJL/cryptpad-w-plugins/pkgs/container/cryptpad-w-plugins). After the first publish, set the package visibility to **Public** in GitHub Packages settings if it is not already public.

## Dokploy Docker Compose deployment

Use this as a Dokploy **docker raw** app. It references only the finished image and requires no build step. Replace the example domains with your public HTTPS hostnames and configure your reverse proxy for container port 3000.

```yaml
services:
  cryptpad:
    image: ghcr.io/jackatdjl/cryptpad-w-plugins:latest
    hostname: cryptpad
    restart: unless-stopped
    read_only: true
    environment:
      CPAD_MAIN_DOMAIN: https://pad.example.com
      CPAD_SANDBOX_DOMAIN: https://sandbox.pad.example.com
      CPAD_PLUGINS: sso,monitoring
    ports:
      - "3000:3000"
    volumes:
      - ./data/blob:/cryptpad/blob
      - ./data/block:/cryptpad/block
      - ./customize:/cryptpad/customize
      - ./data/data:/cryptpad/data
      - ./data/files:/cryptpad/datastore
      - ./config:/cryptpad/config
      - ./onlyoffice-dist:/cryptpad/www/common/onlyoffice/dist
      - ./onlyoffice-conf:/cryptpad/onlyoffice-conf
    tmpfs:
      - /tmp:rw,mode=1777,size=64m
      - /cryptpad/lib/plugins:rw,mode=1777,size=32m
    ulimits:
      nofile:
        soft: 1000000
        hard: 1000000
```

The `/cryptpad/lib/plugins` tmpfs mount is required: it lets the non-root wrapper activate selected plugins in a read-only container. The plugin sources stay in `/cryptpad/plugins-store` in the image. Leave `CPAD_PLUGINS` unset or empty to start plain CryptPad; unknown names produce a warning and are skipped.

Make the host directories used by the bind mounts writable by container UID/GID `4001:4001` before first start (especially `config`, `customize`, and the data directories). If you supply your own `config/infra.js`, set its `httpHost` to `0.0.0.0` so the published port can reach CryptPad. When that file is absent, the wrapper creates it from CryptPad's example with that network-bind setting; an existing custom file is left unchanged.

## Configure SSO

The SSO plugin reads `/cryptpad/config/sso.js`, which is persisted by the `./config` mount. The upstream SSO 1.0.0 tag does not include a standalone `sso.example.js` file; its README contains the OIDC and SAML sample configurations. Copy the relevant sample from the [upstream SSO README](https://github.com/cryptpad/sso/blob/1.0.0/README.md#ssojs-sample-configurations) into `config/sso.js`, then fill in your provider URL, client ID/secret, or SAML certificate and key.

For OIDC, configure this redirect URI with the identity provider:

```text
https://<main-domain>/ssoauth
```

Keep credential-bearing `sso.js` private; do not commit it. After changing SSO settings, restart CryptPad and flush its HTTP cache in the Administration interface if the browser still shows stale plugin assets.

## Maintenance

- The scheduled **Check upstream versions** workflow runs on the 1st and 15th of each month. It updates known CryptPad/SSO compatibility pairs and the monitoring package/ref. If a new CryptPad release is not mapped in `sso_compat`, it opens a deduplicated issue asking the maintainer to check release notes and update that map; no unverified build is made.
- SSO is not advanced just because a newer release exists. Its version must be the release documented as compatible with the selected CryptPad version.
- To add a plugin, download its pinned source into `/cryptpad/plugins-store/<name>` during the Docker build, install runtime dependencies there with development dependencies omitted, and set ownership to `4001:4001`. The wrapper accepts safe names when a matching staged directory exists. Add its version/ref to `versions.json` and pass that pin through the build workflow; document any CryptPad compatibility requirement rather than guessing it.
- To add a CryptPad/SSO compatibility pair, verify the CryptPad release notes and update `sso_compat` using the exact `version-<release>` key. Then update the active pins if needed.
- To run a manual image build, open **Actions → Build image → Run workflow** (`workflow_dispatch`). It builds the pins currently committed in `versions.json`.

## License and source

This image is a derivative of AGPL-3.0-licensed CryptPad and its AGPL-3.0 plugins. The complete build source (Dockerfile, wrapper, version pins, and workflows) is this public repository; keep the repository public and preserve the upstream copyright/license notices. See [`LICENSE`](LICENSE). If you operate a modified version of this network service, make its corresponding source available as required by AGPL-3.0.
