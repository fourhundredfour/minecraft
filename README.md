# Minecraft

Docker image for the [PaperMC](https://papermc.io) Minecraft server. Just-for-fun project.

Images are built automatically and published to the GitHub Container Registry.
Each image is tagged with its **Minecraft version** (e.g. `1.21.4`), and
the newest stable release is additionally tagged `latest`.

## Quickstart

```bash
docker run -d \
  --name paper \
  -e EULA=true \
  -e MEMORY=2G \
  -p 25565:25565 \
  -v "$(pwd)/data:/data" \
  ghcr.io/fourhundredfour/minecraft:latest
```

> You must accept the [Minecraft EULA](https://aka.ms/MinecraftEULA) by setting
> `EULA=true`. The container refuses to start otherwise.

### docker compose

```yaml
services:
  paper:
    image: ghcr.io/fourhundredfour/minecraft:latest
    ports:
      - "25565:25565"
    environment:
      EULA: "true"
      MEMORY: "4G"
    volumes:
      - ./data:/data
    restart: unless-stopped
    stop_grace_period: 60s
```

## Configuration

Environment variables:

- `EULA` (default `false`) - must be `true` to accept the Minecraft EULA and start the server.
- `MEMORY` (default `2G`) - heap size; sets both `-Xms` and `-Xmx`.
- `JVM_OPTS` (default empty) - extra JVM flags appended before `-jar` (e.g. `-Dpaper.foo=bar`).
- `PAPER_FLAGS` (default empty) - extra Paper/server arguments appended after `--nogui`.

Exposed port: `25565/tcp`. Data volume: `/data`.

## Performance

The image starts the JVM with [Aikar's flags](https://docs.papermc.io/paper/aikars-flags),
a well-known G1GC configuration recommended by PaperMC for consistently low
pause times. Set `MEMORY` to a sensible value for your host (e.g. `4G`); both
the initial and maximum heap are pinned to that value.

## Building locally

`build.sh` resolves the latest stable build for a Minecraft version against the
PaperMC API (via `curl` + `jq`) and passes the version, build number, jar name
and SHA256 as Docker build args.

```bash
# Build the local image tagged papermc:1.21.4
./build.sh 1.21.4

# Pin a specific Paper build
./build.sh 1.21.4 --build 232

# Multi-arch build pushed to a registry
./build.sh 1.21.4 --image ghcr.io/fourhundredfour/minecraft --platform linux/amd64,linux/arm64 --push
```

Or build directly with Docker, supplying the build args yourself:

```bash
docker build \
  --build-arg PAPER_VERSION=1.21.4 \
  --build-arg PAPER_BUILD=232 \
  --build-arg PAPER_JAR=paper-1.21.4-232.jar \
  --build-arg PAPER_SHA256=<sha256> \
  -t minecraft:1.21.4 .
```