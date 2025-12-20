FROM ubuntu:22.04
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY tests/e2e/why-linux-amd64 /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/ubuntu/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
