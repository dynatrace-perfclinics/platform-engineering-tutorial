# Platform Engineering

** WORK IN PROGRESS **

Click "Use this template" to create a new repo in your account.

## i) Preparation: Install tools on your local machine

These tools should be installed on the machine you will use to interact with the cluster:

```
###########
# Install kubectl
# This is used to interact with your cluster
###########
curl -LO https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# remove copy in ~
rm kubectl

################
# Install helm
# This is used once to install Argo
# TODO: Investigate use of ArgoCD Autopilot
# So that everything (inc. Argo install can live in Git)
# https://argocd-autopilot.readthedocs.io/en/stable/
################
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
sudo chmod +x /usr/local/bin/helm
rm get_helm.sh

#################
# Install sealed secrets kubeseal
# This is necessary to encrypt the Kubernetes Secret values
#################
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.1/kubeseal-0.24.1-linux-amd64.tar.gz
tar -xf kubeseal-0.24.1-linux-amd64.tar.gz
sudo chmod +x kubeseal
sudo mv kubeseal /usr/local/bin
rm kubeseal-0.24.1-linux-amd64.tar.gz
# Restore overwritten files
git restore LICENSE
git restore README.md
```

## ii) Preparation: Update repoURL
The ArgoCD platform app configuration currently points to the parent repository. Change this now.

In the following files, change the `repoUrl` field:

- [gitops/layer2apps.yml](gitops/layer2apps.yml#L12)
- [gitops/applications/layer2/dynatrace.yml](gitops/applications/layer2/dynatrace.yml#L12)
- [gitops/applications/layer2/opentelemetry.yml](gitops/applications/layer2/opentelemetry.yml#L12)
- [gitops/applications/layer2/webhook.site.yml](gitops/applications/layer2/webhook.site.yml#L12)

Replace `https://github.com/dynatrace-perfclinics/platform-engineering-tutorial.git` with the URL of your repository URL.

Commit those changes:

```
git add gitops/layer2apps.yml
git add gitops/applications/layer2/*
git commit -m "update repoURL"
git push
```

Any changes you make to files will now be picked up automatically by ArgoCD and synced to the cluster.


> You should have access to an empty kubernetes cluster.
> Make sure you can `kubectl get namespaces` successfully before proceeding.

## iii) Preparation: Create oAuth Client

[Follow steps 1 to 3 to create an OAuth Client](https://www.dynatrace.com/support/help/platform-modules/business-analytics/ba-api-ingest#oauth-client)

You should now have 3 pieces of information:

1. `oAuth Client ID`: `dt0s02.1234ABCD`
2. `oAuth Client Secret`: `dt0s02.1234ABCD.*********`
3. `DT Account URN`: urn:dtaccount:********-****-****-****-************`

These details will be used to send Dynatrace bizevents for different applications in various namespaces.

## 2) Install and configure ArgoCD on Cluster

```
# Install Argo
# TODO: Improve
# Investigate use of ArgoCD Autopilot to bootstrap cluster
# https://argocd-autopilot.readthedocs.io/en/stable/
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configuring ArgoCD for access without TLS
# and preconfigure Argo traces to go to the collector
# OTEL collector will be deployed later
kubectl -n argocd apply -f .devcontainer/argocd-cm.yml

# Restart ArgoCD to pick up the new value from the ConfigMap above
kubectl -n argocd scale deploy/argocd-server --replicas=0
kubectl -n argocd scale deploy/argocd-server --replicas=1
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
```

`kubectl get ns` should show a new namespace called `argocd`

## 3) Port forward to access argocd

```
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

This command will appear to hang. That is OK. Leave it running.

Open a new terminal for any new commands you need to run.

## 4) Login to Argo

Switch back to the terminal window and print out the argocd password:

```
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD
```

Username: `admin`
Password: `see above`

Go to `http://localhost:8080` and log in to Argo.

The UI should show "No Applications".

## 5) Apply Layer 1 Apps

The platform relies on common tooling, so deploy this in "layer 1" first:

```
kubectl apply -f gitops/layer1apps.yml
```

Wait until the "layer1" application is green before proceeding.

## 7) Create Business Events Secrets

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

## 6) Create Dynatrace Secret to Activate the OneAgent

The OneAgent operator will be deployed onto the cluster, but it needs to know where to send data. It needs your DT tenant details.

> Note: You need to modify the commands below. DO NOT just copy and paste.

1. Note your DT tenant URL. Like `https://xyz3344.live.dynatrace.com` (no trailing slash)
1. Go to your Dynatrace environment.
1. Go to install OneAgent Kubernetes page.
1. Click "Create Token" next to "Dynatrace Operator token". Copy the value and set it in the command below.
1. Click "Create Token" next to "Data ingest token". Copy the value and set it in the command below

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

```
DT_TENANT=YOURURLHERE; history -d $(history 1)
```

Now set the operator token:
```
DT_OP_TOKEN=YOURTOKENVALUEHERE; history -d $(history 1)
```

Now set the data ingest token:
```
DT_INGEST_TOKEN=YOURTOKENVALUEHERE; history -d $(history 1)
```

You can copy and paste the command below as-is.

```
sed -i "s#https://abc12345.live.dynatrace.com#$DT_TENANT#g" gitops/manifests/layer2/dynatrace/dynatrace.yml
kubectl -n dynatrace create secret generic hot-day-platform-engineering --from-literal=apiToken=$DT_OP_TOKEN --from-literal=dataIngestToken=$DT_INGEST_TOKEN
git add gitops/manifests/layer2/dynatrace/dynatrace.yml
git commit -m "add oneagent config"
git push
```

## 7) Create Dynatrace OpenTelemetry Ingest Token

An OpenTelemetry collector is deployed but does not have the DT endpoint details. Using the same method as above, create those details now.

> Note: You need to modify the commands below. DO NOT just copy and paste.

1. Note your DT tenant URL. Like `https://xyz3344.live.dynatrace.com` (no trailing slash)
1. Go to your Dynatrace environment.
1. Go to "Access Tokens"
1. Generate an access token with `openTelemetry.ingest` permissions

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

Set the Dynatrace URL:

```
DT_TENANT=YOURURLHERE; history -d $(history 1)
```

Now set the OpenTelemetry access token value:

```
DT_INGEST_TOKEN=YOURAPITOKENVALUEHERE; history -d $(history 1)
```

Create the secret:
```
kubectl -n opentelemetry create secret generic dt-details --from-literal=DT_URL=$DT_TENANT --from-literal=DT_OTEL_TRACE_INGEST_TOKEN=$DT_INGEST_TOKEN
```

## 8) Apply Layer 2 Apps

The "platform" application uses the ArgoCD ["app of apps" concept](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) to install many applications inside one "parent" app.

This tutorial uses is to bootstrap the cluster:

```
kubectl -n argocd apply -f gitops/layer2apps.yml
```

## 9) Apply Layer 3 Apps

Now deploy the demo application:

```
kubectl -n argocd apply -f gitops/layer3apps.yml
```

## Recap

By now, you should see 5 applications in ArgoCD:

| App Name| Layer | Wave | Description|
|----------|--------|--------|---------|
| sealed-secrets | 1 | 1 | Encrypts secret values to enable GitOps with secrets |
| platform | 2 | 1 | The logical "wrapper" app which contains the other platform applications |
| dynatrace | 2 | 1 | Deploys DT components |
| opentelemetry-collector | 2 | 2 | Deploys an OpenTelemetry collector preconfigured to send data to DT |
| webhook.site | 2 | 2 | Demo endpoint system to accept and visualise HTTP requests |
| opentelemetry | 2 | 3 | Configuration for the OpenTelemetry collector |


The OneAgent should connect to your DT environment and be visible within a few moments.

-----------------------------------------

### Additional Info to be sorted

### ArgoCD Traces

Argo is configured (when you `kubectl apply` [.devcontainer/argocd-cm.ym](.devcontainer/argocd-cm.yml) to send OpenTelemetry traces to the OTEL collector.

[The collector is configured](gitops/applications/opentelemetry-collector-contrib.yml#L33-#L45) to send traces to DT.

#### Webhook.site

Webhook.site is an on-cluster UI which allows us to `curl POST` payloads and it'll show in the UI.
It is available in the `webhook` namespace on port `8084`.

The first time you load the URI, it generates a UUID. You use that to interact with the endpoint.

However, we can precreate the endpoint (we could do this on cluster creation) so we know (and can GitOps preconfigure) the endpoints.

[See here for how to do this](https://github.com/webhooksite/webhook.site/issues/151).

#### Triggering Monaco

We could use [Argo Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/#usage) to trigger a `Job` or workflow when the initial deployment is done.

For example, when the `dynatrace` application is synced and healthy, we use the `PostSync` hook to trigger a `curlimage/curl` Job which triggers a DT workflow to trigger Monaco.
