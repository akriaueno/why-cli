FROM nimlang/nim:2.2.4-ubuntu-regular AS builder
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release

FROM alpine:3.20
RUN apk add --no-cache bash ca-certificates gcompat libc6-compat libstdc++
COPY --from=builder /work/why /usr/local/bin/why
COPY tests/e2e/alpine/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
