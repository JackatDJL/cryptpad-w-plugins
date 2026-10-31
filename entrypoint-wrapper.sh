#!/bin/sh
set -eu

export LC_ALL=C

plugin_list=${CPAD_PLUGINS-}
plugin_store=/cryptpad/plugins-store
active_plugins=/cryptpad/lib/plugins

while [ -n "$plugin_list" ]; do
    case "$plugin_list" in
        *,*)
            plugin=${plugin_list%%,*}
            plugin_list=${plugin_list#*,}
            ;;
        *)
            plugin=$plugin_list
            plugin_list=
            ;;
    esac

    # Trim leading and trailing whitespace without changing the remaining list.
    plugin=$(printf '%s\n' "$plugin" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$plugin" ] || continue

    case "$plugin" in
        .|..|*[!A-Za-z0-9._-]*)
            printf 'cryptpad-plugin-wrapper: ignoring unsafe plugin name: %s\n' "$plugin" >&2
            continue
            ;;
    esac

    if [ ! -d "$plugin_store/$plugin" ]; then
        printf 'cryptpad-plugin-wrapper: unknown plugin "%s"; skipping\n' "$plugin" >&2
        continue
    fi

    mkdir -p "$active_plugins"
    rm -rf "$active_plugins/$plugin"
    cp -R "$plugin_store/$plugin" "$active_plugins/$plugin"
    printf 'cryptpad-plugin-wrapper: staged plugin "%s"\n' "$plugin"
done

# The upstream Docker example's infra config binds to localhost, which cannot
# be reached through a published container port. Respect custom config, but
# make the generated default reachable from the container network.
if [ ! -f /cryptpad/config/infra.js ]; then
    sed '/httpHost:/s/"localhost"/"0.0.0.0"/' \
        /cryptpad/config.local/infra.example.js > /cryptpad/config/infra.js
    if ! grep -q 'httpHost: "0.0.0.0"' /cryptpad/config/infra.js; then
        printf 'cryptpad-plugin-wrapper: could not set default infra httpHost to 0.0.0.0\n' >&2
        exit 1
    fi
fi

exec /bin/bash /cryptpad/docker-entrypoint.sh "$@"
