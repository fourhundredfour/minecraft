# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jre-jammy AS downloader

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf /var/lib/apt/lists/*

ARG PAPER_VERSION
ARG PAPER_BUILD
ARG PAPER_JAR
ARG PAPER_SHA256

RUN set -eux; \
    test -n "${PAPER_VERSION}"; \
    test -n "${PAPER_BUILD}"; \
    test -n "${PAPER_JAR}"; \
    test -n "${PAPER_SHA256}"; \
    url="https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}/downloads/${PAPER_JAR}"; \
    curl -fsSL -o /paper.jar "${url}"; \
    echo "${PAPER_SHA256}  /paper.jar" | sha256sum -c -

FROM eclipse-temurin:21-jre-jammy AS runtime

RUN set -eux; \
    groupadd --gid 1000 papermc; \
    useradd --uid 1000 --gid 1000 --create-home --home-dir /home/papermc papermc; \
    mkdir -p /data; \
    chown -R papermc:papermc /data

ENV EULA=false \
    MEMORY=2G \
    JVM_OPTS="" \
    PAPER_FLAGS="" \
    CONSOLE_PIPE=/tmp/minecraft-console.in

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 mc-send.sh /usr/local/bin/mc-send-to-console
RUN ln -s /usr/local/bin/mc-send-to-console /usr/local/bin/mc

WORKDIR /data
VOLUME ["/data"]
EXPOSE 25565

USER papermc

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/25565' || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

COPY --from=downloader /paper.jar /opt/paper/paper.jar

ARG PAPER_VERSION
ARG PAPER_BUILD

ENV PAPER_VERSION=${PAPER_VERSION} \
    PAPER_BUILD=${PAPER_BUILD}

LABEL org.opencontainers.image.version="${PAPER_VERSION}" \
    io.papermc.version="${PAPER_VERSION}" \
    io.papermc.build="${PAPER_BUILD}"
