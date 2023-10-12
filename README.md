# Platform Engineering

** WORK IN PROGRESS **

Click "Use this template" to create a new repo in your account.

In your repository, click "Code" then "Codespaces" then "Create codespace on main".

A new browser tab will open and the system will begin installing.

Wait for system to start.

Run all commands inside the codespace browser window.

A kubernetes cluster is now running and ArgoCD is installed.

## Preparation: Update repoURL
The ArgoCD platform app configuration currently points to the parent repository. Change this now.

In the following files, change the `repoUrl` field:

- [gitops/app-of-apps.yml](gitops/app-of-apps.yml#L12)
- [gitops/applications/dynatrace.yml](gitops/applications/dynatrace.yml#L12)
- [gitops/applications/opentelemetry.yml](gitops/applications/opentelemetry.yml#L12)
- [gitops/applications/webhook.site.yml](gitops/applications/webhook.site.yml#L12)

Replace `https://github.com/dynatrace-perfclinics/platform-engineering-tutorial.git` with the URL of your repository URL.

Commit those changes:

```
git add gitops/app-of-apps.yml
git commit -m "update repoURL"
git push
```

Any changes you make to files will now be picked up automatically by ArgoCD and synced to the cluster.

## Port forward to access argocd

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

Go to "Ports". Find the entry for port `8080`.

Hover over the URL and click the globe icon. ArgoCD should launch in a new browser tab.

## Apply Platform App

The "platform" application uses the ArgoCD ["app of apps" concept](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) to install many applications inside one "parent" app.

This tutorial uses is to bootstrap the cluster:

```
kubectl -n argocd apply -f gitops/app-of-apps.yml
```

## Create Dynatrace Secret and install OneAgent

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

Encrypt the values and commit the secret to Git:
```
sed -i "s#https://abc12345.live.dynatrace.com#$DT_TENANT#g" gitops/manifests/dynatrace/dynatrace.yml
kubectl -n dynatrace create secret generic hot-day-platform-engineering --dry-run=client --from-literal=apiToken=$DT_OP_TOKEN --from-literal=dataIngestToken=$DT_INGEST_TOKEN -o yaml | kubeseal -o yaml > gitops/manifests/dynatrace/dynakubesecret.yml
git add gitops/manifests/dynatrace/*
git commit -m "add oneagent + encrypted secret"
git push
```

## Create Dynatrace OpenTelemetry Ingest Token

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

Encrypt the values and commit the secret to Git:
```
kubectl -n opentelemetry create secret generic dt-details --dry-run=client --from-literal=DT_URL=$DT_TENANT --from-literal=DT_OTEL_TRACE_INGEST_TOKEN=$DT_INGEST_TOKEN -o yaml | kubeseal -o yaml > gitops/manifests/opentelemetry/dynatrace-opentelemetry-ingest-secret.yml
git add gitops/manifests/opentelemetryt
git commit -m "add dt url and opentelemetry token to encrypted secret"
git push
```

## Recap

By now, you should see 5 applications in ArgoCD:
- platform (deployed in wave 1)
- sealed-secrets (deployed in wave 1)
- opentelemetry-collector (deployed in wave 1)
- opentelemetry (deployed in wave 2)
- dynatrace (deployed in wave 2)
- webhook.site (deployed in wave 2)

The OneAgent should connect to your DT environment and be visible within a few moments.
