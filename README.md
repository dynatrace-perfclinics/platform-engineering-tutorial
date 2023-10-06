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

In [gitops/app-of-apps.yml](https://github.com/dynatrace-perfclinics/platform-engineering-tutorial/blob/main/gitops/app-of-apps.yml#L9), change the `repoUrl` field.

Replace `'https://github.com/dynatrace-perfclinics/platform-engineering-tutorial.git` with the URL of your repository URL.

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

## Authorise the ArgoCD CLI

```
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username=admin --password=$ARGOCD_PASSWORD --port-forward --port-forward-namespace argocd --plaintext
```
Go to "Ports". Find the entry for port `8080`.

Hover over the URL and click the globe icon. ArgoCD should launch in a new browser tab.

## Login to Argo

Switch back to the terminal window and print out the argocd password:

```
echo $ARGOCD_PASSWORD
```

Username: `admin`
Password: `see above`

Use these details to log into the Argo UI.

## Apply Platform App

The "platform" application uses the ArgoCD ["app of apps" concept](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) to install many applications inside one "parent" app.

This tutorial uses is to bootstrap the cluster:

```
kubectl -n argocd apply -f gitops/app-of-apps.yaml
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
git add gitops/manifests/dynatrace
git commit -m "add oneagent + encrypted secret"
git push
```

## Recap

By now, you should see 3 applications in ArgoCD:
- platform (deployed in wave 1)
- sealed-secrets (deployed in wave 1)
- dynatrace (deployed in wave 2)

The OneAgent should connect to your DT environment and be visible within a few moments.