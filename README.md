# Platform Engineering

** WORK IN PROGRESS **

Click "Use this template" to create a new repo in your account.

## ii) Preparation
The ArgoCD platform app configuration currently points to the parent repository. Change this now.

```
export DT_TENANT_LIVE=https://abc12345.live.dynatrace.com
export DT_TENANT_APPS=https://abc12345.apps.dynatrace.com
find . -type f -not -path '*/\.*' -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$DT_TENANT_LIVE#g" {} +
find . -type f -not -path '*/\.*' -exec sed -i "s#DT_TENANT_APPS_PLACEHOLDER#$DT_TENANT_APPS#g" {} +
```

Replace the GitHub repo placeholder with the URL of your forked repo:

```
export GITHUB_REPO_URL=https://github.com/you/your-repo.git
find . -type f -not -path '*/\.*' -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$GITHUB_REPO_URL#g" {} +
```

Replace the ingress domain (eg. `dtu-test-s99-abc123.dynatrace.training`)
```
export INGRESS_DOMAIN=dtu-test-s99-abc123.dynatrace.training
find . -type f -not -path '*/\.*' -exec sed -i "s#INGRESS_DOMAIN_PLACEHOLDER#$INGRESS_DOMAIN#g" {} +
```

Commit all changes:

```
git add -A
git commit -m "Update URLs"
git push
```

## Preparation: Create oAuth Client TODO (Skip for now)

[Follow steps 1 to 3 to create an OAuth Client](https://www.dynatrace.com/support/help/platform-modules/business-analytics/ba-api-ingest#oauth-client)

You should now have 3 pieces of information:

1. `oAuth Client ID`: `dt0s02.1234ABCD`
2. `oAuth Client Secret`: `dt0s02.1234ABCD.*********`
3. `DT Account URN`: urn:dtaccount:********-****-****-****-************`

These details will be used to send Dynatrace bizevents for different applications in various namespaces.

## Install and configure ArgoCD on Cluster

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Port Forward: Access ArgoCD

```
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

This command will appear to hang. That is OK. Leave it running.

Open a new terminal for any new commands you need to run.

## Login to Argo

Switch back to the terminal window and print out the argocd password:

```
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD
```

Username: `admin`
Password: `see above`

Go to `http://localhost:8080` and log in to Argo.

The UI should show "No Applications".

## Apply Platform Apps

Install the platform apps now.

```
kubectl apply -f gitops/platform.yml
```

Wait until the "platform" application is green before proceeding.

## Create Business Events Secrets TODO (Skip for now)

Since secrets are namespace specific, we need to create an identical secret in each namespaces from which we wish to emit bizevents.

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

You MUST modify the snippet below. Do not just copy and paste:
```
DT_TENANT=YOURURLHERE; history -d $(history 1)
```

Now set your oAuth client ID:
```
DT_OAUTH_CLIENT_ID=YOUROAUTHCLIENTID; history -d $(history 1)
```

Now set your oAuth client secret:
```
DT_OAUTH_CLIENT_SECRET=YOUROAUTHCLIENTSECRET; history -d $(history 1)
```

Now set your account URN:
```
DT_ACCOUNT_URN=urn:dtaccount:********; history -d $(history 1)
```

Now create the secrets in each namespace. You can copy and paste this as-is:
```
kubectl -n default create secret generic dt-bizevent-oauth-details --from-literal=dtTenant=$DT_TENANT --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
kubectl -n keptndemo create secret generic dt-bizevent-oauth-details --from-literal=dtTenant=$DT_TENANT --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
kubectl -n dynatrace create secret generic dt-bizevent-oauth-details --from-literal=dtTenant=$DT_TENANT --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
kubectl -n opentelemetry create secret generic dt-bizevent-oauth-details 
--from-literal=dtTenant=$DT_TENANT --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
kubectl -n webhook create secret generic dt-bizevent-oauth-details --from-literal=dtTenant=$DT_TENANT --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
```

## Create Dynatrace Secret to Activate the OneAgent

The OneAgent operator will be deployed onto the cluster, but it needs to know where to send data. It needs your DT tenant details.

> Note: You need to modify the commands below. DO NOT just copy and paste.

1. Go to your Dynatrace environment.
1. Go to install OneAgent Kubernetes page.
1. Click "Create Token" next to "Dynatrace Operator token". Copy the value and set it in the command below.
1. Click "Create Token" next to "Data ingest token". Copy the value and set it in the command below

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

Set the operator token:
```
DT_OP_TOKEN=YOURTOKENVALUEHERE; history -d $(history 1)
```

Now set the data ingest token:
```
DT_INGEST_TOKEN=YOURTOKENVALUEHERE; history -d $(history 1)
```

You can copy and paste the command below as-is.

```
kubectl -n dynatrace create secret generic hot-day-platform-engineering --from-literal=apiToken=$DT_OP_TOKEN --from-literal=dataIngestToken=$DT_INGEST_TOKEN
```

## Create Dynatrace OpenTelemetry Ingest Token

An OpenTelemetry collector is deployed but does not have the DT endpoint details. Using the same method as above, create those details now.

> Note: You need to modify the commands below. DO NOT just copy and paste.

1. Go to your Dynatrace environment.
1. Go to "Access Tokens"
1. Generate an access token with the following permissions:
    1. `openTelemetryTrace.ingest`
    1. `logs.ingest`
    1. `metrics.ingest`
    1. `events.ingest`


Set the OpenTelemetry access token value:

```
DT_ALL_INGEST_TOKEN=YOURAPITOKENVALUEHERE; history -d $(history 1)
```

Create the secret:
```
kubectl -n opentelemetry create secret generic dt-details --from-literal=DT_URL=$DT_TENANT_LIVE --from-literal=DT_OTEL_ALL_INGEST_TOKEN=$DT_ALL_INGEST_TOKEN
```

## Configure Gitlab

Follow the instructions and steps in [gitlab-setup.sh](gitlab-setup.sh)

## Recap

By now, you should see 12 applications in ArgoCD:

| App Name| Description |
|----------|---------|
| platform | The logical "wrapper" app which contains the other platform applications |
| argoconfig | configuration items for argocd |
| argo-rollouts | Argo Rollouts |
| argo-workflows | Argo Workflows |
| backstage| Backstage application |
| cron-jobs | CronJobs live here. Security scanners. |
| dynatrace | Deploys DT components |
| gitlab | Gitlab |
| keptn | Keptn components |
| namespaces| wrapper app to create all namespaces |
| nginx-ingress| Nginx ingress to access cluster |
| opentelemetry | OpenTelemetry collector to send data to DT |

## Usage

1. Visit backstage
1. Enter your username eg. `user4`
1. Create the application
1. Visit argocd / backstage to see your app being deployed

