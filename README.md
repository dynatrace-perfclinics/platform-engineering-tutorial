# Platform Engineering

** WORK IN PROGRESS **

## FORK this repository for each training class!

As every training clas will have unique URLs to our K8s cluster we need to fork this into a GitHub account, e.g: class1, class2, ... -> and then run through the rest of the steps

## Preparation

The ArgoCD platform app configuration currently points to the parent repository. Change this now.

:warning: You need to change these values and do not use trailing slashes :warning:

Configure these two values:
```
export DT_TENANT="abc12345"
export BASE_DOMAIN="SOMEVALUE.dynatrace.training"
```

Execute this as-is:
```
export DT_TENANT_LIVE="https://$DT_TENANT.live.dynatrace.com"
export DT_TENANT_APPS="https://$DT_TENANT.apps.dynatrace.com"
find . -type f -not -path '*/\.*' -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$DT_TENANT_LIVE#g" {} +
find . -type f -not -path '*/\.*' -exec sed -i "s#DT_TENANT_APPS_PLACEHOLDER#$DT_TENANT_APPS#g" {} +
find . -type f -not -path '*/\.*' -exec sed -i "s#BASE_DOMAIN_PLACEHOLDER#$BASE_DOMAIN#g" {} +
```

Commit all changes:

```
git add -A
git commit -m "Update URLs"
git push
```

[Follow steps 1 to 3 to create an OAuth Client](https://www.dynatrace.com/support/help/platform-modules/business-analytics/ba-api-ingest#oauth-client).

The client (and the service user) need these permissions:

1. `storage:bizevents:read`
1. `storage:buckets:read`
1. `storage:events:write`

You should now have 3 pieces of information:

1. `oAuth Client ID`: `dt0s02.1234ABCD`
2. `oAuth Client Secret`: `dt0s02.1234ABCD.*********`
3. `DT Account URN`: urn:dtaccount:********-****-****-****-************`

These details will be used to send Dynatrace bizevents for different applications in various namespaces.

## Create all Dynatrace Secrets

### Create Dynatrace Secret to Activate the OneAgent

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
kubectl create namespace dynatrace
kubectl -n dynatrace create secret generic hot-day-platform-engineering --from-literal=apiToken=$DT_OP_TOKEN --from-literal=dataIngestToken=$DT_INGEST_TOKEN
```

### Create Dynatrace OpenTelemetry Ingest Token

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
kubectl create namespace opentelemetry
kubectl -n opentelemetry create secret generic dt-details --from-literal=DT_URL=$DT_TENANT_LIVE --from-literal=DT_OTEL_ALL_INGEST_TOKEN=$DT_ALL_INGEST_TOKEN
```
### Create a Configuration as Code (aka Monaco) Token

The token depends on the configuration you wish to read / write (see the [monaco](monaco/)) folder monaco configurations in [gitlab-setup.sh](gitlab-setup.sh).

Initially the token needs the following permissions:

1. `Access problem and event feed, metrics, and topology`
1. `Read configuration` and `Write configuration`
1. `Read settings` and `Write settings`
1. `Read SLO` and `Write SLO`
1. `Create and read synthetic monitors, locations, and nodes`

Create the token:

```
DT_MONACO_TOKEN=dt0c01.******.*************; history -d $(history 1)
kubectl create namespace monaco
kubectl -n monaco create secret generic monaco-secret --from-literal=monacoToken=$DT_MONACO_TOKEN
```

### Create Business Events Secrets

> Note: Applying the platform app above creates the namespaces
> You must wait for that before performing this step.

Since secrets are namespace specific, we need to create an identical secret in each namespaces from which we wish to emit bizevents.

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

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
kubectl -n dynatrace create secret generic dt-bizevent-oauth-details --from-literal=dtTenant=$DT_TENANT_LIVE --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
kubectl -n opentelemetry create secret generic dt-bizevent-oauth-details --from-literal=dtTenant=$DT_TENANT_LIVE --from-literal=oAuthClientID=$DT_OAUTH_CLIENT_ID --from-literal=oAuthClientSecret=$DT_OAUTH_CLIENT_SECRET --from-literal=accountURN=$DT_ACCOUNT_URN
```


## Install and configure ArgoCD on Cluster

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## (optional) Login through Port-Forward: Access ArgoCD before creating the Ingress

```
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

This command will appear to hang. That is OK. Leave it running.

Open a new terminal for any new commands you need to run.

Switch back to the terminal window and print out the argocd password:

```
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD
```

Username: `admin`
Password: `see above`

Go to `http://localhost:8080` and log in to Argo.

The UI should show "No Applications".

## Apply Platform Apps: GitLab, Dynatrace, Backstage, ...

Install the platform apps now.

```
kubectl apply -f gitops/platform.yml
```

If you do port-forward with Argo: Wait until the "platform" application is green before proceeding.
If you dont: try to access https://argcd.$BASE_DOMAIN

## Configure Gitlab

To login to GitLab we use `root` as the username
Password can be obtained via
```
GITLABPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode)
echo "GitLab user: root"
echo "GitLab pwd: $GITLABPWD"
```

### Set https access

1. Log into GitLab
2. Go to `https://gitlab.$BASEDOMAIN/admin/application_settings/general`
3. Change the "Custom Git clone URL for HTTP(S)" from `http://...`` to `https://...`

### Create Personal Access Token (PAT)

1. Log into Gitlab
2. Go to your user profile `https://gitlab.$BASEDOMAIN-/profile/personal_access_tokens`
3. Create a PAT with `api, read_repository, write_repository`

### Set up GitLab

When you have a Personal Access Token (PAT), configure this:
```
export GL_PAT="YOURGLPAT"
export BASE_DOMAIN="dtu-test-*****.dynatrace.training"
```

Now run the following:
```
# TODO: Update to proper repo to your fork!
export FORKED_REPO_NAME=YOURREPONAME    # e.g: classroom1
export FORKED_GITHUB_ORGNAME=YOURORG    # e.g: dynatrace
export TEMPLATE_REPO="https://github.com/$FORKED_GITHUB_ORGNAME/$FORKED_REPO_NAME"
export GIT_USER="root"
export GIT_PWD="$GL_PAT"
export GIT_EMAIL="admin@example.com"
export GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME="backstage-templates"
export GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME="applications-template"

# Create empty template repo for backstage templates
curl -X POST -d '{"name": "'$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME'", "initialize_with_readme": true, "visibility": "public"}' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$BASE_DOMAIN/api/v4/projects"
# Create empty template repo for app templates
curl -X POST -d '{"name": "'$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME'", "initialize_with_readme": true, "visibility": "public"}' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$BASE_DOMAIN/api/v4/projects"

# Clone files from template GitHub.com repo
git config --global user.email "$GIT_EMAIL" && git config --global user.name "$GIT_USER"
# Ensure terminal is in home directory
cd
# Clone template files
git clone $REPO_TO_CLONE
# Clone new empty repo for backstage templates
git clone https://gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git
# Clone new empty repo for app templates
git clone https://gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME.git
# Copy files from template for backstage templates repo
# Then commit and push files
cp -R $TEMPLATE_REPO/backstage-templates ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git
# Copy files from template
cd
cp -R $TEMPLATE_REPO/apptemplates ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME.git
# Done creating "backstage template" repo
# Done creating "applications template" repo

# Create 'group1'
# This group is where the backstage bootstrap process will create the "app teams" projects
# TODO: Rename to something more logical like "projects" or "teamprojects"
curl -X POST -d '{ "name": "group1", "path": "group1", "visibility": "public" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$BASE_DOMAIN/api/v4/groups"

# TODO: Can this logic be moved into a postsync workflow when Gitlab is installed?
```

## Configure Backstage

When Argo is installed and all the platform apps are installed and happily green, configure a secret for Backstage:

This is from the 'alice' user (see [argocd-cm.yml](gitops/manifests/platform/argoconfig/argocd-cm.yml))

```
# Set the default context to the argocd namespace so 'argocd' CLI works
kubectl config set-context --current --namespace=argocd
ARGOCD_TOKEN="argocd.token=$(argocd account generate-token --account alice)"
# Reset the context to 'default' namespace
kubectl config set-context --current --namespace=default 
kubectl -n backstage create secret generic backstage-secrets --from-literal=GITLAB_TOKEN=$GL_PAT --from-literal=ARGOCD_TOKEN=$ARGOCD_TOKEN
```
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
1. Enter your username eg. `team4`
1. Create the application
1. Visit argocd / backstage to see your app being deployed
