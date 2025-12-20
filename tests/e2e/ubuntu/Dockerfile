FROM nimlang/nim:2.2.4-ubuntu-regular AS builder
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release

FROM ubuntu:22.04
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /work/why /usr/local/bin/why
COPY tests/e2e/ubuntu/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
