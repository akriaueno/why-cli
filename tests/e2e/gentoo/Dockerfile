FROM nimlang/nim:2.2.4-ubuntu-regular AS builder
WORKDIR /work
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN nimble build -d:release

FROM gentoo/stage3:latest
ENV FEATURES="-sandbox -usersandbox"
RUN emerge --sync \
  && emerge --quiet app-portage/portage-utils
COPY --from=builder /work/why /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/gentoo/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
