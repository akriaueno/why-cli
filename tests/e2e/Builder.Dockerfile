FROM nimlang/nim:2.2.4-ubuntu-regular
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release \
  && install -m 0755 /work/why /usr/local/bin/why
