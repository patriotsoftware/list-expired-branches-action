# define expiration date
EXPIRATION_DATE=$(date -d "$days_retention days ago" +%s)
formatted_exp_date=$(date -d @${EXPIRATION_DATE} +'%Y-%m-%d %H:%M:%S')

printf '%s\n' "Branches with last commit older than $formatted_exp_date are expired. Resources can be restored with another branch deploy."

# GitHub branches excluding master/main without origin prefix
git fetch --all
github_branches=$(git branch -r | grep -vE 'origin/(main|master)' | sed 's/origin\///')

# Helm installed branches excluding main 
#   NOTE: custom colum is using branch name used during install
helm_branches=$(kubectl get deploy -n $namespace --no-headers  -o custom-columns='BRANCH:.spec.template.spec.containers[*].env[?(@.name=="BRANCH_NAME")].value' | tr ' ' '\n' | sort -u | grep -v -E '^(main|master)$')
expired_branches=()

# Expired GitHub branches
for branch in ${github_branches[@]}; do    
    LAST_COMMIT=$(git log -1 --format=%ct "origin/$branch")

    if [ $LAST_COMMIT -lt $EXPIRATION_DATE ] && [[ $branch != v* ]]; then
        LAST_COMMIT_DATE=$(date -d @$LAST_COMMIT +'%Y-%m-%d %H:%M:%S')

        echo "$LAST_COMMIT_DATE last commit $branch"
        expired_branches+=(""$branch"")       
    fi   
done

# Expired Helm branches
#   NOTE: helm installed branches that do not exist on GitHub are expired.
for branch in ${helm_branches[@]}; do
    on_GitHub='false'
    for gh_branch in ${github_branches[@]}; do 
        [[ $gh_branch == $branch ]] && on_GitHub='true' && break
    done 
    [[ $on_GitHub == 'false' ]] && expired_branches+=(""$branch"")
done

if [ -z $expired_branches ]; then
    printf '\n%s\n' "No expired branches found."
    echo "has-expired=false" >> $GITHUB_OUTPUT
else        
    printf '\n%s\n' "Found expired branches."
    echo "has-expired=true" >> $GITHUB_OUTPUT
fi

# display results
printf '\n%s\n' "//// GitHub Branches ////"
printf '%s\n' ${github_branches[@]}

printf '\n%s\n' "//// Helm branches ////"
printf '%s\n' ${helm_branches[@]}

printf '\n%s\n' "//// Expired Branches ////"
printf '%s\n' ${expired_branches[@]}
expired_data=$(printf '"%s"\n' ${expired_branches[@]}|paste -sd, -)
json_expired_data="{\"branch_name\": [$expired_data]}"
echo "expired-json=$json_expired_data" >> $GITHUB_OUTPUT
