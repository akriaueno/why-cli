FROM rust:1.90-bookworm@sha256:3914072ca0c3b8aad871db9169a651ccfce30cf58303e5d6f2db16d1d8a7e58f
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release --locked \
  && install -m 0755 /work/target/release/why /usr/local/bin/why
