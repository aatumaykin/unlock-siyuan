# ponytail: no vendored source. Clone upstream at build time, apply .patches/, build.
# Version is sourced from VERSION file (single source of truth).
# Build tag: docker build -t unlock-siyuan:$(grep PATCH_REVISION VERSION | cut -d= -f2 | xargs echo $(grep UPSTREAM_VERSION VERSION | cut -d= -f2))-...

FROM --platform=$BUILDPLATFORM node:21 AS node-build

ARG NPM_REGISTRY=

COPY VERSION /version
COPY .patches/ /patches/

WORKDIR /app
RUN <<EORUN
#!/bin/sh -e
. /version
git clone --branch "v${UPSTREAM_VERSION}" --depth=1 https://github.com/siyuan-note/siyuan.git /tmp/siyuan
git -C /tmp/siyuan apply /patches/*.patch
cp -r /tmp/siyuan/app/* /app/
EORUN

RUN <<EORUN
#!/bin/sh -e
corepack enable
corepack install --global "$(node -e 'console.log(require("./package.json").packageManager)')"
npm config set registry "${NPM_REGISTRY}"
pnpm install --silent
EORUN

RUN <<EORUN
#!/bin/sh -e
pnpm run build
mkdir /artifacts
mv appearance stage guide changelogs /artifacts/
EORUN

FROM golang:1.25-alpine AS go-build

COPY VERSION /version
COPY .patches/ /patches/

RUN <<EORUN
#!/bin/sh -e
. /version
apk add --no-cache git gcc musl-dev
git clone --branch "v${UPSTREAM_VERSION}" --depth=1 https://github.com/siyuan-note/siyuan.git /tmp/siyuan
git -C /tmp/siyuan apply /patches/*.patch
mkdir -p /kernel
cp -r /tmp/siyuan/kernel/* /kernel/
EORUN

WORKDIR /kernel
RUN go env -w GO111MODULE=on && go env -w CGO_ENABLED=1

RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg \
    go mod download

RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg \
    go build --tags fts5 -v -ldflags "-s -w"

FROM alpine:latest
LABEL maintainer="Liang Ding<845765@qq.com>"

RUN apk add --no-cache ca-certificates tzdata su-exec

ENV TZ=Asia/Shanghai
ENV HOME=/home/siyuan
ENV RUN_IN_CONTAINER=true
EXPOSE 6806

WORKDIR /opt/siyuan/
COPY --from=go-build --chmod=755 /kernel/kernel /kernel/entrypoint.sh .
COPY --from=node-build /artifacts .

ENTRYPOINT ["/opt/siyuan/entrypoint.sh"]
CMD ["/opt/siyuan/kernel"]
