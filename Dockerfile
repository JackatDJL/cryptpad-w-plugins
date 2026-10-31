ARG CPAD_VERSION=version-2026.10.0
ARG SSO_VERSION=1.0.0
ARG MON_VERSION=0.0.2
ARG MON_REF=775152911dfb7007d0f1eadab1d2f9e7b09fb376

FROM cryptpad/cryptpad:${CPAD_VERSION}

ARG CPAD_VERSION
ARG SSO_VERSION
ARG MON_VERSION
ARG MON_REF

USER root

ADD https://github.com/cryptpad/sso/archive/refs/tags/${SSO_VERSION}.tar.gz /tmp/sso.tar.gz
ADD https://github.com/cryptpad/cryptpad-monitoring-plugin/archive/${MON_REF}.tar.gz /tmp/monitoring.tar.gz

RUN set -eux; \
    mkdir -p /cryptpad/plugins-store/sso /cryptpad/plugins-store/monitoring /cryptpad/lib/plugins /cryptpad/config; \
    tar -xzf /tmp/sso.tar.gz --strip-components=1 -C /cryptpad/plugins-store/sso; \
    tar -xzf /tmp/monitoring.tar.gz --strip-components=1 -C /cryptpad/plugins-store/monitoring; \
    rm /tmp/sso.tar.gz /tmp/monitoring.tar.gz; \
    test "$(node -p "require('/cryptpad/plugins-store/sso/package.json').version")" = "${SSO_VERSION}"; \
    test "$(node -p "require('/cryptpad/plugins-store/monitoring/package.json').version")" = "${MON_VERSION}"; \
    cd /cryptpad/plugins-store/sso && npm ci --omit=dev --no-audit --no-fund; \
    cd /cryptpad/plugins-store/monitoring && npm install --omit=dev --no-audit --no-fund; \
    chown -R 4001:4001 /cryptpad/plugins-store /cryptpad/lib/plugins /cryptpad/config

LABEL org.opencontainers.image.title="CryptPad with selectable plugins" \
      org.opencontainers.image.description="Official CryptPad image with selectable upstream SSO and monitoring plugins" \
      org.opencontainers.image.source="https://github.com/JackatDJL/cryptpad-w-plugins" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.base.name="cryptpad/cryptpad:${CPAD_VERSION}" \
      org.opencontainers.image.base.version="${CPAD_VERSION}" \
      org.opencontainers.image.version="${CPAD_VERSION}-sso-${SSO_VERSION}-monitor-${MON_VERSION}-ref-${MON_REF}"

COPY --chown=4001:4001 entrypoint-wrapper.sh /cryptpad/entrypoint-wrapper.sh
RUN chmod 0755 /cryptpad/entrypoint-wrapper.sh \
    && chown 4001:4001 /cryptpad/entrypoint-wrapper.sh

USER cryptpad
ENTRYPOINT ["/bin/bash", "/cryptpad/entrypoint-wrapper.sh"]
CMD ["npm", "start"]
