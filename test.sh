BUCKET_NAME=cfn-test-conditions
REGION=us-east-1

# Read the conditions.json file
conditions_file="conditions.json"
if [[ ! -f $conditions_file ]]; then
    echo "$conditions_file not found!"
    exit 1
fi

replace_file="roles.json.template"
if [[ ! -f $replace_file ]]; then
    echo "$replace_file not found!"
    exit 1
fi

length=$(jq '. | length' $conditions_file)  # Get the number of elements in the array

# Loop through each element in conditions.json
for ((i=0; i<$length; i++)); do
    echo "[$i] ===START==="
    jq ".[$i]" $conditions_file
    current_condition=$(jq -j ".[$i] | tostring" $conditions_file | gsed ':a;N;$!ba;s/\n/\\n/g')
    sed "s|\$replace|$current_condition|g" $replace_file > "roles.json"

    aws s3 cp --profile "${AWS_PROFILE}" _roles.json s3://${BUCKET_NAME}/cloudformation/test/roles.json
    aws s3 cp --profile "${AWS_PROFILE}" substack.json s3://${BUCKET_NAME}/cloudformation/test/substack.json
    aws cloudformation create-stack --profile "${AWS_PROFILE}" --region "${REGION}" \
        --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
        --disable-rollback \
        --stack-name cfn-test-conditions-$i --template-body file://input.json > _output.json
    echo "[$i] Stack creation started. Waiting for status..."

    # Extract StackId from the _output.json
    stack_id=$(jq -r '.StackId' _output.json)
    while true; do
        # Fetch the current status of the stack
        status=$(aws cloudformation describe-stacks --profile "${AWS_PROFILE}" --region "${REGION}" --stack-name $stack_id | jq -r '.Stacks[0].StackStatus')
        case $status in
            CREATE_COMPLETE)
                echo "[$i] Stack creation succeeded! Deleting stack..."
                break # exit the while loop
                ;;
            CREATE_FAILED|ROLLBACK_COMPLETE|ROLLBACK_FAILED)
                echo "[$i] Stack creation failed. Deleting stack..."
                break # exit the while loop
                ;;
            *) # For other statuses like CREATE_IN_PROGRESS, just wait and poll again
                sleep 20 # wait before checking again
                ;;
        esac
    done

    # Expect the stack to delete in 20 seconds.
    aws cloudformation delete-stack --profile "${AWS_PROFILE}" --region "${REGION}" --stack-name $stack_id
    sleep 20

    echo "[$i] ====END===="
done
