# Platform Engineering with Dynatrace Tutorial

** WORK IN PROGRESS ** - getting this ready for Dynatrace Perform 2024 HOT (Hands On Training) Days

## Step 1: FORK or USE CASE TEMPLATE to create a new training class repository!

This repository contains K8s CRDs that defines the core platform for each training class. Its our "Core Platform GitOps Repo" that contains ArgoCD Applications allowing ArgoCD to deploy Backstage, GitLab, OpenTelemetry, Keptn, Dynatrace and more ...

Every training class environment therefore needs its own unique copy of this repo as it will also include the unique domain name definitions.

Therefore its necessary to either *FORK* this repository or *USE AS TEMPLATE* to create a new repository, e.g: https://github.com/yourorg/reponame_class1, https://github.com/yourorg/reponame_class2 ...

Once you have your own version of this repository continue with the next steps!

## Step 2: Replace GitHub Repo references in Platform CRDs


First, create a GitHub PAT with `Contents` `read` & `write` permissions. You can limit this to the single repo if you want.

Some of the files we just cloned are pointing to other files in our GitHub repo. To point to our just cloned repository we need to do this

```
export YOUR_GITHUB_EMAIL=YOUREMAIL
export YOUR_GITHUB_USERNAME=YOURGITHUBUSERNAME
export YOUR_GITHUB_PAT=YOURGITHUBPAT                 # e.g: github_pat_*******
export FORKED_GITHUB_ORGNAME=YOURORG    # e.g: dtu-engineering
export FORKED_REPO_NAME=YOURREPONAME    # e.g: classroom1
export FORKED_TEMPLATE_REPO="https://github.com/$FORKED_GITHUB_ORGNAME/$FORKED_REPO_NAME"

# Clone the template files locally
git clone $FORKED_TEMPLATE_REPO
cd $FORKED_REPO_NAME

# Now lets replace the placeholders
find . -type f -not -path '*/\.*' -exec sed -i "s#FORKED_GITHUB_ORGNAME_PLACEHOLDER#$FORKED_GITHUB_ORGNAME#g" {} +
find . -type f -not -path '*/\.*' -exec sed -i "s#FORKED_REPO_NAME_PLACEHOLDER#$FORKED_REPO_NAME#g" {} +
find . -type f -not -path '*/\.*' -exec sed -i "s#FORKED_TEMPLATE_REPO_PLACEHOLDER#$FORKED_TEMPLATE_REPO#g" {} +

# Now lets commit those GitHub Urls
git add -A
git commit -m "Update GitHub Template Repo URLs"
git push
```

## Step 2: Preparations: Domain Names, Tokens ...

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
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$DT_TENANT_LIVE#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_APPS_PLACEHOLDER#$DT_TENANT_APPS#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#BASE_DOMAIN_PLACEHOLDER#$BASE_DOMAIN#g" {} +

```

Commit all changes. When prompted for a password, use the GitHub PAT token.

```
git config --global user.email "$YOUR_GITHUB_EMAIL"
git config --global user.name "$YOUR_GITHUB_USERNAME"
git add -A
git commit -m "Update URLs"
git push
```

## Step 3: Create all Dynatrace Configuration and Secrets

We have a couple of Dynatrace integrations that require tokens and OAuth credentials stored in k8s secrets. Lets create them one by one!

### 3.1 Create Dynatrace Secret to Activate the OneAgent

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

### 3.2 Create Dynatrace OpenTelemetry Ingest Token

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

### 3.3 Create a Configuration as Code (aka Monaco) Token

The token depends on the configuration you wish to read / write (see the [monaco](monaco/)) folder monaco configurations.

Initially the token needs the following permissions:

1. `Access problem and event feed, metrics, and topology`
2. `Read configuration` and `Write configuration`
3. `Read settings` and `Write settings`
4. `Read SLO` and `Write SLO`
5. `Create and read synthetic monitors, locations, and nodes`

Create the token:

```
DT_MONACO_TOKEN=dt0c01.******.*************; history -d $(history 1)
kubectl create namespace monaco
kubectl -n monaco create secret generic monaco-secret --from-literal=monacoToken=$DT_MONACO_TOKEN
```

### 3.4 Create an ArgoCD Notifications Token

We are using ArgoCD Notifications to send Events to Dynatrace using the Events API V2. For that we need to a token that can send events to Dynatrace

```
DT_NOTIFICATION_TOKEN=dt0c01.******.*************; history -d $(history 1)
kubectl create namespace monaco
kubectl -n monaco create secret generic argocd-notifications-secret --from-literal=dynatrace-url=$DT_TENANT_LIVE --from-literal=dynatrace-token=$DT_NOTIFICATION_TOKEN
```

### 3.5 Create Business Events Secrets

We will need an OAuth client to send BizEvents.

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


## Step 4: Install and configure ArgoCD on Cluster

ArgoCD is our central GitOps Operator that deploys our Core Platform Components (taken from this repository) as well as will deploy custom apps that attendees will create during the class room hands-on tutorials!

```
kubectl create ns argocd
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
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCDPWD
```

Username: `admin`
Password: `see above`

Go to `http://localhost:8080` and log in to Argo.

The UI should show "No Applications".

You can also do:

```
kubectl config set-context --current --namespace=argocd
argocd app list
```

## Step 5: Apply Platform Apps: GitLab, Dynatrace, Backstage, ...

Now its time to tell ArgoCD to install all our platform components. For that we have a so called AppOfApps prepared that tells ArgoCD from which folders in our GitHub repository to fetch Backstage, GitLab, OpenTelemetry, ...

```
kubectl apply -f gitops/platform.yml
```

If you do port-forward with Argo: Wait until the "platform" application is green before proceeding.
If you dont: try to access https://argocd.$BASE_DOMAIN

## Step 6: Configure GitLab

GitLab is our git repository for all apps that the attendees will create and that will then be deployed by ArgoCD on the target k8s cluster.

To login to GitLab we use `root` as the username
Password can be obtained via
```
GITLABPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode)
echo "GitLab user: root"
echo "GitLab pwd: $GITLABPWD"
```

### 6.1 Set HTTPS Clone access

This step is needed because otherwise GitLab will return http:// address when Backstage creates new GitLab repositories which will then fail at a later stage.
There is a setting we need to change in the GitLab UI

1. Log into GitLab
2. Go to `https://gitlab.$BASEDOMAIN/admin/application_settings/general`
3. Change the "Custom Git clone URL for HTTP(S)" from `http://gitlab.xxxxx` to `https://gitlab.$BASEDOMAIN`

### 6.2 Create Personal Access Token (PAT)

In order for tools like Backstage to interact with GitLab we need a PAT.

1. Log into Gitlab
2. Go to your user profile `https://gitlab.$BASEDOMAIN-/profile/personal_access_tokens`
3. Create a PAT with `api, read_repository, write_repository`

### 6.3 Initialize GitLab with template repositories

When you have a Personal Access Token (PAT), configure this:
```
export GL_PAT="YOURGLPAT"
```

Now run the following:
```
# You should already have the next three set from our first step!
# export FORKED_GITHUB_ORGNAME=YOURORG    # e.g: dtu-engineering
# export FORKED_REPO_NAME=YOURREPONAME    # e.g: classroom1
# export FORKED_TEMPLATE_REPO="https://github.com/$FORKED_GITHUB_ORGNAME/$FORKED_REPO_NAME"

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
# Clone new empty repo for backstage templates
git clone https://gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git
# Clone new empty repo for app templates
git clone https://gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME.git
# Copy files from template for backstage templates repo
# Then commit and push files
cp -R $FORKED_TEMPLATE_REPO/backstage-templates ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git
# Copy files from template
cd
cp -R $FORKED_TEMPLATE_REPO/apptemplates ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
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

```

## Step 7: Configure Backstage

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

## Step 8: Recap

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

You should be able to get all your credentials you need through this:
```
GITLABURL=https://gitlab.$BASEDOMAIN
GITLABUSER=root
GITLABPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode)

ARGOCDURL=https://argocd.$BASEDOMAIN
ARGOCDUSER=admin
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

BACKSTAGEURL=https://backstage.$BASEDOMAIN

echo "-------------------------------------------------------------"
echo "GitLab:    $GITLABURL"
echo "User:      $GITLABUSER"
echo "Pwd:       $GITLABPWD"
echo "----"
echo "ArgoCD:    $ARGOCDLABURL"
echo "User:      $ARGOCDLABUSER"
echo "Pwd:       $ARGOCDLABPWD"
echo "----"
echo "Backstage: $BACKSTAGEURL"
echo "----"
echo "Dynatrace: $DT_TENANT_APPS"
```

## Step 9: Usage

1. Visit backstage
2. Create a new app based on the default template
3. Fill out all form values eg. `team4`, ...
4. Create the application
5. Visit argocd / backstage to see your app being deployed
6. Visit Dynatrace to see everything being deployed
