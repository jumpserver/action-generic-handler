#!/bin/bash -eix

case ${GITHUB_EVENT_NAME} in
"push")
  echo "Event is push, run push handler"
  bash -ixeu /on_push.sh
  ;;
"pull_request")
  echo "Event is pull_request, run pull request handler"
  bash -ixeu /on_pull_request.sh
esac
