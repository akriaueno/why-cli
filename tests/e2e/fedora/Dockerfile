FROM nimlang/nim:2.2.6 AS builder
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release

FROM fedora:40
RUN dnf -y install bash ca-certificates coreutils \
  && dnf clean all
COPY --from=builder /work/why /usr/local/bin/why
COPY tests/e2e/fedora/test.sh /test.sh
ENTRYPOINT ["/usr/bin/bash", "/test.sh"]
