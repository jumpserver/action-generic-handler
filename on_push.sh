#!/bin/bash
# Require env
# GITHUB_TOKEN
# GITHUB_EVENT_PATH=/tmp/abc.json
# GITHUB_REPOSITORY=ibuler/koko

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

# 当push了 PR Request分支(分支名称 pr@${TO_BRANCH}@other)
on_push_pr_branch() {
  PR_REF=$(jq -r .ref < "${GITHUB_EVENT_PATH}")
  PR_HEAD=$(basename "${PR_REF}")
  PR_BASE=$(echo "${PR_HEAD}" | awk -F@ '{ print $2 }')

  if ! echo "${PR_HEAD}" | grep -E '^pr@[a-zA-Z0-9.]+@.+';then
    echo "Not a pr request branch, should be pr_BRANCH_other: ${PR_HEAD}"
    return 0
  fi

  # 应该是pr@${TO_BRANCH}@other
  if [[ -z "${PR_BASE}" ]];then
    echo "Unexepect error occur"
    return 0
  fi

  PR_TITLE=$(jq -r .head_commit.message < "${GITHUB_EVENT_PATH}")
  if [[ -z "${PR_TITLE}" ]];then
    echo "No commit found, exit"
    exit 1
  fi

  BASE_BRANCH_DETAIL_URL=$(jq -r .repository.git_refs_url < "${GITHUB_EVENT_PATH}" | sed "s@{.*}@/heads/${PR_BASE}@g")
  curl \
        --fail \
        -X GET \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${BASE_BRANCH_DETAIL_URL}" | jq '.ref' || return 1


  PR_BODY=$(jq -r '.commits|map(.message)|join("<br>")' < "${GITHUB_EVENT_PATH}")
  PR_URL=$(jq -r '.repository.pulls_url' < "${GITHUB_EVENT_PATH}"|sed 's@{.*}@@g')


  curl \
        --fail \
        -X POST \
        --data "$(generate_create_pr_data)" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${PR_URL}" > /dev/null
}

function add_remote_github() {
  # Clone仓库
  git config --global user.name "github-actions"
  git config --global user.email "github-actions@jumpserver.org"
  remote_url="https://${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
  rm -rf GITHUB_REPO
  git clone "${remote_url}" "GITHUB_REPO" && cd "GITHUB_REPO" || exit 2
  git status
  git fetch origin
  git remote -v
}
function clean_remote_github() {
  cd ..
  rm -rf "GITHUB_REPO"
}

# 当push了 PR Request分支(分支名称 repr@TO_BRANCHES@REBASE_START@OTHER)
# example: repr@master_v1.0_v2.0@7f01ed8d6f1@fix-some-bug
rebase_branch_and_push_pr_branch() {
  PR_REF=$(jq -r .ref < "${GITHUB_EVENT_PATH}")
  PR_HEAD=$(basename "${PR_REF}")
  PR_BASES=$(echo "${PR_HEAD}" | awk -F@ '{ print $2 }')
  PR_REBASE_START=$(echo "${PR_HEAD}" | awk -F@ '{ print $3 }')
  PR_OTHER=$(echo "${PR_HEAD}" | awk -F@ '{ print $4 }')

  if ! echo "${PR_HEAD}" | grep -E '^repr@[a-zA-Z0-9._]+@[a-z0-9]+@.+';then
    echo "Not a pr request branch, should be repr@TO_BRANCHES@REBASE_START@OTHER: ${PR_HEAD}"
    return 0
  fi

  # 应该是master_v1.0_v2.0
  if [[ -z "${PR_BASES}" ]];then
    echo "Unexpect error occur"
    return 0
  fi

  # 切换成可迭代的
  PR_BASES=$(echo "${PR_BASES}" | tr "_" "\n")

  # 添加github认证
  add_remote_github

  for b in $PR_BASES;do
    echo -e "\n>>> Start process $b"
    new_pr_branch_name="pr@${b}@${PR_OTHER}"
    remote_branch_name="origin/$b"
    git checkout "${PR_HEAD}" || echo ""
    git branch -D "${new_pr_branch_name}" &> /dev/null || echo ""
    git checkout -b "${new_pr_branch_name}"
    git rebase "${PR_REBASE_START}" --onto="${remote_branch_name}"
    ret="$?"
    if [[ "${ret}" != "0" ]];then
      echo "Rebase failed ${ret}: ${remote_branch_name}"
      git rebase --abort || echo ""
      continue
    fi
    git push origin "${new_pr_branch_name}:${new_pr_branch_name}"
  done
  git checkout "${PR_HEAD}" || echo ""
  git branch | grep 'pr'

  # 清理掉这个分支, 再清理本地仓库
  git push origin :"${PR_HEAD}"
  clean_remote_github
}

if [[ "${GITHUB_EVENT_NAME}" != "push" ]];then
  exit 0
fi

on_push_pr_branch
rebase_branch_and_push_pr_branch


