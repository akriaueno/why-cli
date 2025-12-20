FROM nimlang/nim:2.2.4-ubuntu-regular AS builder
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release

FROM opensuse/leap:15.6
RUN zypper -n install bash ca-certificates coreutils \
  && zypper clean -a
COPY --from=builder /work/why /usr/local/bin/why
COPY tests/e2e/opensuse/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
