FROM nimlang/nim:2.2.4-ubuntu-regular AS builder
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release

FROM archlinux:base
RUN pacman -Syu --noconfirm bash ca-certificates coreutils \
  && pacman -Scc --noconfirm
COPY --from=builder /work/why /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/arch/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
