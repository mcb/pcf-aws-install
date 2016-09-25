get_output_value() {
  local key=$1
  local stack=$2
  echo $stack | jq -r ".Stacks[0].Outputs[] | select(.OutputKey == \"$key\") | .OutputValue"
}
