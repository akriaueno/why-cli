FROM opensuse/leap:15.6
RUN zypper -n install bash ca-certificates coreutils \
  && zypper clean -a
COPY tests/e2e/why-linux-amd64 /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/opensuse/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
