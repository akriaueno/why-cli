FROM alpine:3.20
RUN apk add --no-cache bash ca-certificates gcompat libc6-compat libstdc++
COPY tests/e2e/why-linux-amd64 /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/alpine/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
