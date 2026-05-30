FROM rust:1.90-bookworm
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release --locked \
  && install -m 0755 /work/target/release/why /usr/local/bin/why
