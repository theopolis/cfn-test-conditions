## cfn-test-conditions

This example code is used to determine what AWS IAM condition keys can be used with `cloudformation:CreateStack`.

A condition on `CreateStack` when used by a StackSet is important because the executor role may be used as a "confused deputy" if it can also be used to create Stacks outside of the intended StackSet.

The problem is that "sub stacks", or Stacks that run as a result of a StackSet resource, have limited conditions.
One of the most important condition keys `cloudformation:TemplateURL` is unusable because CloudFormation uses an internal copy of the template in an internal S3 bucket.

All other keys are also either non-set so they cannot be used.

Keys:
- `cloudformation:TemplateUrl`: This is re-written to an internal CloudFormation S3 bucket ([see below](https://github.com/theopolis/cfn-test-conditions#guessing-the-internal-bucket-for-templateurl)).
- `aws:SourceArn`: Not set by CloudFormation.
- `aws:SourceIdentity`: Not set by CloudFormation.
- `aws:PrincipalArn`: Set to the executor role, which is not helpful when trying to mitigate a confused deputy situation.
- `aws:PrincipalIsAWSService`: Set to false.
- `cloudformation:ResourceTypes`: Not set by CloudFormation.
- `cloudformation:RoleARN`: Set to null.
- `aws:ViaAWSService`: Set to false.
- `aws:CalledViaFirst`: Set to null.

And `aws:SourceIp` cannot be used because with StackSets the IP is an AWS internal IP, which is rewritten to `cloudformation.amazonaws.com`.

## Using this tool

This documentation is for reproducing the conditions tests.

### How this works

This repo contains a script `./test.sh` that will enumerate condition statements within `./conditions.json`.

For each of these conditions, the script will replace the StackSet's execution role IAM policy condition for `cloudformation:CreateStack`.

The script will then upload the TemplateURL to an S3 bucket, execute the stack, and check the result.

If the stack succeeds then the condition passed.

### How to use

Set your profile.

```sh
$ export AWS_PROFILE=your-profile
```

Update the code to replace `cfn-test-conditions` with a name of your choice.
This name should have an associated S3 bucket in the account you will use.
This bucket's objects should be publically accessible so that CloudFormation can read objects.

```sh
./test.sh
```

### Guessing the internal bucket for TemplateURL

The most frustrating thing about CloudFormation StackSet stack templates is that CloudFormation does not use the origin TemplateURL. This means the `cloudformation:TemplateURL` condition is unusable.

CloudFormation seems to use a URL like:

```
https://executor-templates-${AWS_INTERNAL_ACCOUNT_ID}-${AWS_REGION}.s3.${AWS_REGION}.amazonaws.com/${UUID}.${AWS_ACCOUNT_ID}.template
```

It will take hours to guess the URL, but you can use:

```sh
./guess.sh
```
