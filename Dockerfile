# Container image that runs your code
FROM alpine:3.12

# Copies your code file from your action repository to the filesystem path `/` of the container
RUN apk add --no-cache curl jq bash
COPY *.sh /

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
