#!/bin/bash -eix

case ${GITHUB_EVENT_NAME} in
"push")
  bash -ixeu /on_push.sh
  ;;
"pull_request")
  bash -ixeu /on_pull_request.sh
esac
