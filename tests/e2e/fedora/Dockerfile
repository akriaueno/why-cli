FROM fedora:40
RUN dnf -y install bash ca-certificates coreutils \
  && dnf clean all
COPY tests/e2e/why-linux-amd64 /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/fedora/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
