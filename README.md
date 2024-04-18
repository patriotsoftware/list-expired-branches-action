# list-expired-branches-action

Returns a json containing the branch names that match a last commit date older than retention policy.


## Parameters

#### 'days-retention'
Optional parameter that allows to specify a number of days as retention policy.

## Output

#### 'expired-branches-json'
Json object containing the ```branch_name``` results.

## Sample Use

```
  get-expired-branches:
    name: Checking Repository Branches Expiration
    if: ${{ github.event_name == 'schedule' && github.event.schedule == '0 0 * * MON' }}
    runs-on: psidev-linux
    outputs:
      expired-branches-json: ${{ steps.expired-branches.outputs.expired-branches-json }}
    steps:
    - uses: patriotsoftware/list-expired-branches-action@v1
      id: expired-branches
      with:
        days-retention: 1   
```