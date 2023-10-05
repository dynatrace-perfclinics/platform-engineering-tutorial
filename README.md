# Platform Engineering

** WORK IN PROGRESS **

Click "Use this template" to create a new repo in your account.

In your repository, click "Code" then "Codespaces" then "Create codespace on main".

A new browser tab will open and the system will begin installing.

Wait for system to start.

A kubernetes cluster is now running and ArgoCD is installed.

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