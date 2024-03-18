#!/bin/bash

# Check if at least one argument is provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <CLUSTER_NAME> <IAMRoleFor_alfresco-alf-pod>"
    exit 1
fi

# Assign the first argument to CLUSTER_NAME
CLUSTER_NAME=$1

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
export VPC_ID=$(aws eks describe-cluster \
                --name $CLUSTER_NAME \
                --query "cluster.resourcesVpcConfig.vpcId" \
                --output text)
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
-n kube-system --set clusterName=$CLUSTER_NAME --set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller \
--set region=${AWS_REGION} --set vpcId=${VPC_ID}
kubectl -n kube-system rollout status deployment aws-load-balancer-controller
kubectl -n alfresco create secret generic quay-secret --from-file=.dockerconfigjson=/home/ore/.docker/config.json --type=kubernetes.io/dockerconfigjson

# Retrieve the trust policy of the IAM role named $IAMRole
IAMRole=$2
TRUST_POLICY=$(aws iam get-role --role-name $IAMRole --query 'Role.AssumeRolePolicyDocument' --output text)

# Modify the trust policy to change the Condition from "StringEquals" to "ForAnyValue:StringLike"
# and update the "system:serviceaccount" condition to match anything in the "alfresco" namespace
MODIFIED_TRUST_POLICY=$(echo "$TRUST_POLICY" | sed 's/\("Condition":\) \{/"Condition": {/g' | sed 's/\("StringEquals":\) \{/"ForAnyValue:StringLike": {/g' | sed 's/\("system:serviceaccount":\) "\([^"]*\)"/\1"alfresco:*"/g')

# Update the trust policy of the IAM role named $IAMRole
aws iam update-assume-role-policy --role-name $IAMRole --policy-document "$MODIFIED_TRUST_POLICY"
