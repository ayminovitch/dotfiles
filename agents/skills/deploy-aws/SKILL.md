---
name: deploy-aws
description: Deploy a containerized Python/FastAPI AI service to AWS with Amazon ECS Express Mode (Fargate + load balancer + HTTPS + auto scaling from one command), images in ECR, secrets in Secrets Manager, and GitHub Actions deploying through OIDC with no stored AWS keys. Use when the user wants to ship, host or deploy a project on AWS.
---

# Deploy to AWS (ECS Express Mode)

ECS Express Mode is AWS's simple container hosting: one call creates Fargate tasks, an
Application Load Balancer with HTTPS, auto scaling and networking. (App Runner no longer accepts
new customers; AWS recommends Express Mode instead.) The user's project template already has a
non-root Dockerfile, a `/health` endpoint and port 8000.

Costs: an always-on Fargate task plus a load balancer is billed every hour, even with no
traffic. Estimate with the AWS Pricing Calculator first, use a budget alert, and delete test
services when done. Ask before creating anything billable.

## One-time setup (AWS CLI, per account/region)

```bash
export AWS_REGION=eu-west-1 APP=<name>          # pick the region closest to users
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# 1. Image registry
aws ecr create-repository --repository-name "$APP" --image-scanning-configuration scanOnPush=true

# 2. The two roles Express Mode needs
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam create-role --role-name ecsInfrastructureRoleForExpressServices --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices

# 3. Secrets (API keys) — never in the image or in plain environment variables
aws secretsmanager create-secret --name "$APP/anthropic-api-key" --secret-string "<key>"
```

Give `ecsTaskExecutionRole` permission to read **only** this app's secrets
(`secretsmanager:GetSecretValue` on `arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT:secret:$APP/*`).
IAM is eventually consistent: if the next step fails with an assume-role error, wait a minute.

## Container config as code — `deploy/container.json`

```json
{
  "image": "IMAGE",
  "containerPort": 8000,
  "environment": [
    {"name": "ENVIRONMENT", "value": "production"},
    {"name": "LLM_MODEL", "value": "anthropic/<model>"}
  ],
  "secrets": [
    {"name": "ANTHROPIC_API_KEY", "valueFrom": "arn:aws:secretsmanager:<region>:<account>:secret:<app>/anthropic-api-key"}
  ]
}
```

Every deploy sends this whole file with the new image, so config changes are reviewed in git
and never drift.

## First deploy (from the Mac)

Build for the CPU architecture the service runs (`linux/amd64` here; your M1 builds arm64 unless
told otherwise — or set the service's `--cpu-architecture ARM64` and build arm64 everywhere):

```bash
REG=$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr get-login-password | docker login --username AWS --password-stdin "$REG"
docker buildx build --platform linux/amd64 -t "$REG/$APP:v1" --push .
jq --arg img "$REG/$APP:v1" '.image = $img' deploy/container.json > /tmp/container.json
aws ecs create-express-gateway-service --service-name "$APP" \
  --primary-container file:///tmp/container.json \
  --execution-role-arn "arn:aws:iam::$ACCOUNT:role/ecsTaskExecutionRole" \
  --infrastructure-role-arn "arn:aws:iam::$ACCOUNT:role/ecsInfrastructureRoleForExpressServices" \
  --health-check-path /health --scaling-target '{"minTaskCount":1,"maxTaskCount":3}' --monitor-resources
```

Get the URL and status with `aws ecs describe-express-gateway-service --service-arn <arn>`;
it is ready when the status is `ACTIVE`. Then `curl https://<url>/health`.

## Continuous deploy — GitHub Actions with OIDC (no AWS keys in GitHub)

1. Add GitHub as an identity provider in IAM (`token.actions.githubusercontent.com`, audience
   `sts.amazonaws.com`) and a role `github-deploy-<app>` that trusts it **only** for this repo's
   `main` branch (condition `token.actions.githubusercontent.com:sub` =
   `repo:<owner>/<repo>:ref:refs/heads/main`). Permissions: push to this one ECR repository,
   `ecs:UpdateExpressGatewayService` / `ecs:DescribeExpressGatewayService` on this service, and
   `iam:PassRole` for `ecsTaskExecutionRole`.
2. In the repo settings → Variables: `AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `ECR_REPOSITORY`,
   `ECS_SERVICE_ARN`.
3. `.github/workflows/deploy.yml`:

```yaml
name: deploy
on:
  push:
    branches: [main]
permissions:
  id-token: write   # lets the job request a short-lived AWS token
  contents: read
concurrency: deploy-production
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        run: |
          IMAGE="${{ steps.ecr.outputs.registry }}/${{ vars.ECR_REPOSITORY }}:${{ github.sha }}"
          docker build -t "$IMAGE" .
          docker push "$IMAGE"
          jq --arg img "$IMAGE" '.image = $img' deploy/container.json > container.json
      - name: Deploy
        run: |
          aws ecs update-express-gateway-service \
            --service-arn "${{ vars.ECS_SERVICE_ARN }}" \
            --primary-container file://container.json
```

Make it run only after CI passes (branch protection on `main` requiring the `ci` workflow).

## Checklist before calling it done

HTTPS URL answers `/health` · secrets come from Secrets Manager · logs visible in CloudWatch ·
min/max task counts set · a budget alert exists · rollback = redeploy the previous image tag
(`git revert` + push, or rerun the workflow for the previous commit) · README has the URL and
how to deploy.
