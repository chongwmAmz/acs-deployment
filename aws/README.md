# Introduction
1. Start with eksctl. Use the [helper template](./aws/eksctl/eksctl-create-cluster-fg-template.yaml) to whip up an EKS cluster that uses Fargate as the compute provider. See [eks-template-ore23.yaml](./aws/eksctl/eks-template-ore23.yaml) for a template with actual values used in the the Oregon region.
2. Run 
```bash
kubectl create cluster -f <nameOfTemplate.yaml>
```
3. eksctl uses Cloudformation to deploy the EKS cluster. Wait for eksctl to complete the creation of the cluster. On the Cloudformation console, look into the `Output` tab to get the AWS EKS infrastructure details for the other AWS resources in the next step.
4. Replace the values with angle brackets `<>` in this [Cloudformation template](./aws/aws-CFN.yaml) with the values generated in the step above.
5. Use the values generated in both steps above to as the parameters for the [createResource.sh script](.aws/kubectl/createResources.sh). The arguments to provide are `eksClusterName` and `iamRoleNameForAlfrescoPods`
```bash
./createResource.sh script <eksClusterName> <iamRoleNameForAlfrescoPods>
   ```
6. Use the values from the above 3 steps to replace the values with angle brackets `<>` in the [aws-helm-values.yaml](./aws/aws-helm-values.yaml) Helm values file.
7. Create a Kubernetes template file using the `helm template` command. Run the command below in the `acs-deployment` directory.  
```bash
helm template --debug --dry-run acs helm/alfresco-content-services -n alfresco -f aws/aws-helm-values.yaml > aws/Alfresco23Template.yaml
```
8. In the `Alfresco23Template.yaml` file, strip off all Ingress objects and replace it with a [single `Ingress` object](https://raw.githubusercontent.com/AlfrescoLabs/ServerlessACS-OpenSearch/main/acs-alfresco-alb-ingress-https.yaml). This single `Ingress` object leverages `Amazon Application Load Balancer` rather than using `NGINX` running in pods as the load balancer.
9. Update the `Service` object for `Alfresco Share` to add the following annotation that allows HTTP 302 that `Share` returns.
```
metadata:
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: /share
    alb.ingress.kubernetes.io/success-codes: 200,302
```
10. Update the `ServiceAccount` object for `alfresco-repo-sa` to add the following annotation that prompts Kubernetes to use the IAM Role to facilitate IRSA.
```
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::817632472177:role/<iamRoleNameForAlfrescoPods>
```
11. Deploy the updated `Alfresco23Template.yaml` template with the following Kubernetes command
```
kubecl -n alfresco apply -f aws/Alfresco23Template.yaml
```
12. If you notice pods getting stuck in a restart loop and the cause seen in the system event log is either a failed startup, readiness or liveness probe, it is likely that the resource request for the pod is too low. You can either allow EKS to wait longer for the pod to complete startup by adding `initialDelaySeconds` or increase the requested CPU for those pods. Note that it takes Fargate approximately 60 seconds to allocate a node to EKS. 
