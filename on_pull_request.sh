#!/bin/bash


on_pull_request_close_del_branch_if_need() {
  PR_ACTION=$(jq -r .action < "${GITHUB_EVENT_PATH}")
  if [[ "${PR_ACTION}" != "closed" ]];then
    echo "Action is not closed, pass"
    return 0
  fi

  PR_HEAD_REF=$(jq -r .pull_request.head.ref < "${GITHUB_EVENT_PATH}")

  if [[ ! "${PR_HEAD_REF}" =~ 'pr_' ]];then
    echo "Not a valid pull request branch, pass"
    return 0
  fi

  PR_HEAD_BRANCH_URL=$(jq -r .pull_request.head.repo.git_refs_url < "${GITHUB_EVENT_PATH}" |sed "s@{.*}@/heads/$PR_HEAD_REF@g")

  curl \
        --fail \
        -X DELETE \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${PR_HEAD_BRANCH_URL}" || echo "May be has deleted"
}


on_pull_request_open_edit_auto_label_it() {
  PR_ACTION=$(jq -r .action < "${GITHUB_EVENT_PATH}")
  if [[ "${PR_ACTION}" != "edited" && "${PR_ACTION}" != "opened" ]];then
    echo "Is nether edited nor opened action, pass"
    return 0
  fi
  PR_TITLE=$(jq -r .pull_request.title < "${GITHUB_EVENT_PATH}")
  PR_ISSUE_URL=$(jq -r .pull_request.issue_url < "${GITHUB_EVENT_PATH}")

  label=""

  if [[ "${PR_TITLE}" =~ "fix" ]];then
    label="类型:bug"
  elif [[ "${PR_TITLE}" =~ "feat" ]];then
    label="类型:新功能"
  elif [[ "${PR_TITLE}" =~ "perf" || ${PR_TITLE} =~ "refactor" ]];then
    label="类型:优化"
  elif [[ "${PR_TITLE}" =~ "ci" ]];then
    label="结果:无需处理"
  fi
  if [[ -z "${label}" ]];then
    return 0
  fi

  data='{"labels":["'"${label}"'"]}'

  curl \
        --fail \
        -X POST \
        --data ${data} \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${PR_ISSUE_URL}" > /dev/null
}


on_pull_request_open_add_reviewer() {
  PR_ACTION=$(jq -r .action < "${GITHUB_EVENT_PATH}")
  if [[ "${PR_ACTION}" != "opened" ]];then
    echo "不是新建issue, 跳过设置reviewer"
    return 0
  fi
  PR_URL=$(jq -r .pull_request.url < "${GITHUB_EVENT_PATH}")
  PR_REVIEWER_URL="${PR_URL}/requested_reviewers"

  data='{"team_reviewers":["developers"]}'

  curl \
        --fail \
        -X POST \
        --data ${data} \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${PR_REVIEWER_URL}" > /dev/null
}


if [[ "${GITHUB_EVENT_NAME}" != "pull_request" ]];then
  echo "Is not pull request event, exit"
  exit 0
fi

on_pull_request_close_del_branch_if_need
on_pull_request_open_edit_auto_label_it
on_pull_request_open_add_reviewer
