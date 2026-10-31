# Deployment guide

This guide deploys the prebuilt CryptPad-with-plugins image as a Dokploy Docker Raw Compose app. The image is based on official CryptPad `version-2026.10.0`, with SSO `1.0.0` and monitoring `0.0.2` (monitoring source commit `775152911dfb7007d0f1eadab1d2f9e7b09fb376`), as pinned in `versions.json`.

## Prerequisites

- A Dokploy instance where you can create a **Docker Raw** app and configure its reverse proxy.
- Public HTTPS hostnames for CryptPad's main and sandbox domains.
- A way to provide persistent host directories for the bind mounts below; the container runs as UID/GID `4001:4001`.
- If enabling SSO, an identity provider and its OIDC or SAML configuration/credentials.

## Choose and pull the image

Use a published GHCR tag. The tags currently listed in the README's version matrix are:

- `ghcr.io/jackatdjl/cryptpad-w-plugins:latest`
- `ghcr.io/jackatdjl/cryptpad-w-plugins:cpad-2026.10.0`
- `ghcr.io/jackatdjl/cryptpad-w-plugins:cpad-2026.10.0-sso-1.0.0-mon-0.0.2-ref-7751529`

The full pin tag records the CryptPad, SSO, and monitoring versions/ref. `latest` is convenient but can move as images are published. The `cpad-` tag removes Docker Hub's `version-` prefix. GHCR package: [cryptpad-w-plugins](https://github.com/JackatDJL/cryptpad-w-plugins/pkgs/container/cryptpad-w-plugins). If the package is not public, set its visibility to **Public** in GitHub Packages settings before expecting an unauthenticated deployment to pull it.

## Dokploy Docker Raw Compose

Create a Docker Raw app in Dokploy and use the following Compose configuration. Replace both example hostnames with your public HTTPS hostnames. This uses the finished image and does not require a build step.

```yaml
services:
  cryptpad:
    image: ghcr.io/jackatdjl/cryptpad-w-plugins:cpad-2026.10.0-sso-1.0.0-mon-0.0.2-ref-7751529
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

Configure Dokploy's reverse proxy to send traffic to the container on port `3000`. The main and sandbox domains must be separate hostnames, and the environment values should be their public HTTPS origins. The wrapper generates the default `config/infra.js` with `httpHost: "0.0.0.0"`, so the app can be reached through its published container port. If you provide your own `config/infra.js`, set its `httpHost` to `0.0.0.0`; the wrapper leaves an existing file unchanged. The proxy remains responsible for exposing the public HTTPS hostnames and forwarding to the app.

### Persistent directories and read-only operation

The Compose mounts persist CryptPad data and configuration on the host. Ensure all host directories used by these bind mounts are writable by container UID/GID `4001:4001` before first start, especially `config`, `customize`, and the data directories. The mount paths are `data/blob`, `data/block`, `customize`, `data/data`, `data/files`, `config`, `onlyoffice-dist`, and `onlyoffice-conf` relative to the Compose project directory.

The container is configured read-only. `/tmp` and `/cryptpad/lib/plugins` are writable tmpfs mounts; the latter is required because the non-root entrypoint wrapper stages enabled plugins there at startup. Plugin sources remain in the image under `/cryptpad/plugins-store`. Do not omit the `/cryptpad/lib/plugins` tmpfs when using the read-only configuration.

## Plugin selection

The image includes SSO and monitoring, but neither is enabled automatically. Set `CPAD_PLUGINS` to a comma-separated list such as `sso,monitoring` to opt in. Leave it unset or empty to run without either plugin. The wrapper stages requested plugins only when a matching directory exists in the image; unsafe names are ignored and unknown names produce a warning and are skipped.

## Configure SSO

When SSO is selected, configure `/cryptpad/config/sso.js` (persisted through the `./config` bind mount). The SSO `1.0.0` tag does not include a standalone `sso.example.js`; use the relevant OIDC or SAML sample from the [upstream SSO README](https://github.com/cryptpad/sso/blob/1.0.0/README.md#ssojs-sample-configurations) and fill in the provider URL, client ID/secret, or SAML certificate and key as applicable.

For OIDC, configure this redirect URI with the identity provider:

```text
https://<main-domain>/ssoauth
```

Keep credential-bearing `sso.js` private and do not commit it. Restart CryptPad after changing SSO settings. If the browser still shows stale plugin assets afterward, flush the HTTP cache in CryptPad's Administration interface.

## First-start validation and troubleshooting

- Confirm the image can be pulled and the service starts. The GHCR package must be public for an unauthenticated pull.
- Check startup output for `cryptpad-plugin-wrapper` messages. A `staged plugin` message confirms activation; an `unknown plugin` warning means the requested name is not present in the image and was skipped.
- If startup exits while preparing the default infra config, the wrapper could not set `httpHost` to `0.0.0.0` in the generated config. Check the image's expected `config.local/infra.example.js` source and configuration mount setup.
- If a custom `config/infra.js` is present, verify that its `httpHost` is `0.0.0.0`; custom files are not rewritten by the wrapper.
- If the app cannot write data or configuration, check host bind-mount ownership and write permissions for UID/GID `4001:4001`.
- If selected plugins are not staged with a read-only root filesystem, verify that `/cryptpad/lib/plugins` is mounted as writable tmpfs.
- Check the reverse proxy's upstream port is `3000`, and that its configured public hostnames match `CPAD_MAIN_DOMAIN` and `CPAD_SANDBOX_DOMAIN`.

## Upgrades and backups

The `config`, data, customization, and other mounted contents live in host bind-mount directories rather than only in the container. Preserve those directories when replacing the container. Before an upgrade, retain a copy of the persistent mounted data and configuration using your host's backup process. For reproducible image selection, prefer a versioned/full-pin tag over `latest`; the full pin identifies the plugin versions and monitoring source ref as well as the CryptPad release.
