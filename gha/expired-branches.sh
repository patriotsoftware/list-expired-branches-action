#! /usr/bin/env bash

# define expiration date
EXPIRATION_DATE=$(date -d "$days_retention days ago" +%s)
formatted_exp_date=$(date -d @"${EXPIRATION_DATE}" +'%Y-%m-%d %H:%M:%S')

printf '%s\n' "Branches with last commit older than $formatted_exp_date ($days_retention days ago) are expired. Resources can be restored with another branch deploy."

echo "repository=$repository"

# GitHub branches excluding master/main without origin prefix
if [[ $repository == '' ]]; then
    echo "without repo name"
    git_remote="$(git remote get-url origin)"
else
    echo "with repo name"
    git_remote="https://github.com/${repository}.git"
fi

github_branches=$(git ls-remote --heads $git_remote | awk '{print $2}' | sed 's/refs\/heads\///' | grep -vE '(main|master)')

printf '\n%s\n' "//// GitHub Branches ////"
printf '"%s"\n' "${github_branches[@]}"

# Helm installed branches excluding main 
#   NOTE: custom column is using branch name used during install
helm_branches=$(kubectl get deploy -n $namespace --no-headers  -o custom-columns='BRANCH:.spec.template.spec.containers[*].env[?(@.name=="BRANCH_NAME")].value' | tr ' ' '\n' | sort -u | grep -v -E '^(main|master)$')
printf '\n%s\n' "//// Helm Branches ////"
printf '"%s"\n' "${helm_branches[@]}"

expired_branches=()

# Expired GitHub branches
for branch in "${github_branches[@]}"; do
    COMMIT_HASH=$(git ls-remote $git_remote refs/heads/$branch | awk '{print $1}')
    LAST_COMMIT=$(git show -s --format=%ct $COMMIT_HASH)

    if [ $LAST_COMMIT -lt $EXPIRATION_DATE ] && [[ $branch != v* ]]; then
        LAST_COMMIT_DATE=$(date -d @$LAST_COMMIT +'%Y-%m-%d %H:%M:%S')

        echo "$LAST_COMMIT_DATE last commit $branch"
        expired_branches+=($branch)       
    fi   
done

# Expired Helm branches
#   NOTE: helm installed branches that do not exist on GitHub are expired.
for h_branch in "${helm_branches[@]}"; do
    on_GitHub='false'
    for gh_branch in "${github_branches[@]}"; do 
        [[ $gh_branch == $h_branch ]] && echo "'$h_branch' is on GitHub" && on_GitHub='true' && break
    done 
    [[ $on_GitHub == 'false' ]] && echo "'$h_branch' not found on GitHub" && expired_branches+=($h_branch)
done

if [ -z $expired_branches ]; then
    printf '\n%s\n' "No expired branches found."
    echo "has-expired-branches=false" >> $GITHUB_OUTPUT
else        
    printf '\n%s\n' "Found expired branches."
    echo "has-expired-branches=true" >> $GITHUB_OUTPUT
fi

# display results
printf '\n%s\n' "//// Expired Branches ////"
printf '"%s"\n' "${expired_branches[@]}"

expired_data=$(printf '"%s"\n' "${expired_branches[@]}"|paste -sd, -)
json_expired_data="{\"branch_name\": [$expired_data]}"
echo "expired-branches-json=$json_expired_data" >> $GITHUB_OUTPUT
