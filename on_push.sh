#!/bin/bash

generate_create_pr_data()
{
  cat <<EOF
{
  "title": "${PR_TITLE}",
  "body": "${PR_BODY}",
  "head": "${PR_HEAD}",
  "base": "${PR_BASE}"
}
EOF
}

# 当push了 PR Request分支(分支名称 pr_${TO_BRANCH}_other)
on_push_pr_branch() {
  PR_REF=$(jq -r .ref < "${GITHUB_EVENT_PATH}")
  PR_HEAD=$(basename "${PR_REF}")
  PR_BASE=$(echo "${PR_HEAD}" | sed -E 's@pr_([a-zA-Z0-9]+)_.*@\1@g')

  if ! echo "${PR_HEAD}" | grep -E 'pr_[a-zA-Z0-9]+_.+';then
    echo "Not a pr request branch, should be pr_${PR_BASE}_other: ${PR_HEAD}"
    return 0
  fi

  # 应该是pr_${TO_BRANCH}_other
  if [[ -z "${PR_BASE}" ]];then
    echo "Unexepect error occur"
    return 0
  fi

  PR_TITLE=$(jq -r .head_commit.message < "${GITHUB_EVENT_PATH}")
  if [[ -z "${PR_TITLE}" ]];then
    echo "No commit found, exit"
    exit 1
  fi

  PR_BODY=$(jq -r '.commits|map(.message)|join("<br>")' < "${GITHUB_EVENT_PATH}")
  PR_URL=$(jq -r '.repository.pulls_url' < "${GITHUB_EVENT_PATH}"|sed 's@{.*}@@g')


  curl \
        --fail \
        -X POST \
        --data "$(generate_create_pr_data)" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${PR_URL}"
}

if [[ "${GITHUB_EVENT_NAME}" != "push" ]];then
  exit 0
fi

on_push_pr_branch


