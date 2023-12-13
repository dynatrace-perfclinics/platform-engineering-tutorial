# Platform Engineering with Dynatrace Tutorial

** WORK IN PROGRESS ** - getting this ready for Dynatrace Perform 2024 HOT (Hands On Training) Days

## End User Hands-On Tutorials

All Tutorials can be found in the [Hands On](./handson/) folder
* [Hands On 1: Explore the Platform we have built for you](./handson/handson1.md)
* [Hands-On 2: Create a new Service, Deploy it, Explore with Dynatrace](./handson/handson2.md)
* [Hands-On 3: Setting up an SRG (Site Reliability Guardian)](./handson/handson3.md)
* [Hands-On 4: Deploy a new version of our app](./handson/handson4.md)
* [Hands-On 5: Explore the Platform Observability Use Cases (WORK IN PROGRESS)](./handson/handson5.md)

## Step 0: Create a new Repository based on the Tutorial Repo

The original repository is https://github.com/dynatrace-perfclinics/platform-engineering-tutorial!

If you plan to run a workshop then we suggest to create your own fork or copy (by using this as a template) repository and then replace all the XX_PLACEHOLDERS in your repository to point to your Dynatrace Tenants and your BASE_DOMAIN (E.g: *.classroom.yourdomain.com)

If you intend to run multiple class rooms - like we did at Perform 2024 HOTDAYS - then the best is to create multiple copies of the `gitops` folder, e.g: `gitops_class1`, `gitops_class2` ... and then replace all the PLACEHOLDERS for each class room. This allows you to have a single "Core Platform GitOps Repo" containing all CRDs for your individual Platforms

### Step 0.1: Replace GitHub Repo references in Platform CRDs

Some of the files we just cloned are pointing to other files in our GitHub repo. To point to our just cloned repository we need to do this

```
# These are the details of your Dynatrace Tenant, BASE-Domain & GEOLOCATION for Synthetics (they differ between prod and sprint tenants!)
export DT_TENANT="abc12345"
export BASE_DOMAIN="SOMEVALUE.dynatrace.training"
export DT_GEOLOCATION=GEOLOCATION-XXXXXXX     # eg: GEOLOCATION-DDAA176627F5667A for prod live
export DT_TENANT_LIVE="https://$DT_TENANT.sprint.dynatracelabs.com"           # BEAWARE OF .sprint.dynatrace.labs vs .dynatrace.com
export DT_TENANT_APPS="https://$DT_TENANT.sprint.apps.dynatracelabs.com"

# These are the details of your cloned/forked/copied GitHub Repo
export FORKED_GITHUB_ORGNAME=dynatrace-perfclinics
export FORKED_REPO_NAME=hotday-perform-2024-test 
export FORKED_REPO_GITOPS_CLASSROOMID=gitops_dryrun
export FORKED_TEMPLATE_REPO="https://github.com/$FORKED_GITHUB_ORGNAME/$FORKED_REPO_NAME"

# Clone the template files locally
cd
git clone $FORKED_TEMPLATE_REPO
cd $FORKED_REPO_NAME/$FORKED_REPO_GITOPS_CLASSROOMID

# Now lets replace the placeholders
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#GEOLOCATION_PLACEHOLDER#$DT_GEOLOCATION#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$DT_TENANT_LIVE#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_APPS_PLACEHOLDER#$DT_TENANT_APPS#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#BASE_DOMAIN_PLACEHOLDER#$BASE_DOMAIN#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#FORKED_GITHUB_ORGNAME_PLACEHOLDER#$FORKED_GITHUB_ORGNAME#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#FORKED_REPO_NAME_PLACEHOLDER#$FORKED_REPO_NAME#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#FORKED_TEMPLATE_REPO_PLACEHOLDER#$FORKED_TEMPLATE_REPO#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#FORKED_REPO_GITOPS_CLASSROOMID_PLACEHOLDER#$FORKED_REPO_GITOPS_CLASSROOMID#g" {} +

# Now lets commit those GitHub Urls
git add -A
git commit -m "Update GitHub Template Repo URLs"
git push
```

Go back out to the root directory of your cloned git repo
```
cd ..
```

## Step 1 (assuming you have a repo based on Step 0): Preparing Tokens and Env Variables

If the github repo was already prepared by setting all placeholders as described in Step 1 & 2 then you only need to clone the repo locally like this:

```
export FORKED_GITHUB_ORGNAME=dynatrace-perfclinics
export FORKED_REPO_NAME=hotday-perform-2024-test 
export FORKED_REPO_GITOPS_CLASSROOMID=gitops_dryrun
export FORKED_TEMPLATE_REPO="https://github.com/$FORKED_GITHUB_ORGNAME/$FORKED_REPO_NAME"

# Clone the template files locally (if you havent done so yet)
git clone $FORKED_TEMPLATE_REPO
cd $FORKED_REPO_NAME
```

Also you have to set those env-variables for the domains
```
export DT_TENANT="abc12345"
export BASE_DOMAIN="SOMEVALUE.dynatrace.training"
export DT_TENANT_LIVE="https://$DT_TENANT.sprint.dynatracelabs.com"
export DT_TENANT_APPS="https://$DT_TENANT.sprint.apps.dynatracelabs.com"
export DT_GEOLOCATION=GEOLOCATION-XXXXXXX     # eg: GEOLOCATION-DDAA176627F5667A for prod live
```

In Step 2 we are going to create lots of tokens. IN case you already have them - here a quick overview to set them:
```
DT_INGEST_TOKEN=token; history -d $(history 1)
DT_OP_TOKEN=token; history -d $(history 1)
DT_ALL_INGEST_TOKEN=token; history -d $(history 1)
DT_MONACO_TOKEN=token; history -d $(history 1)
DT_NOTIFICATION_TOKEN=token; history -d $(history 1)
```

## Step 2: Create all Dynatrace Configuration and Secrets

We have a couple of Dynatrace integrations that require tokens and OAuth credentials stored in k8s secrets. Lets create them one by one!

### 2.1 Create Dynatrace Secret to Activate the OneAgent

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

### 2.2 Create Dynatrace OpenTelemetry Ingest Token

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

### 2.3 Create a Configuration as Code (aka Monaco) Token

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
kubectl -n dynatrace create secret generic monaco-secret --from-literal=monacoToken=$DT_MONACO_TOKEN
```

### 2.4 Create an ArgoCD Notifications Token

We are using ArgoCD Notifications to send Events to Dynatrace using the Events API V2. For that we need to a token that can send events to Dynatrace

```
DT_NOTIFICATION_TOKEN=dt0c01.******.*************; history -d $(history 1)
kubectl create namespace argocd
kubectl -n argocd create secret generic argocd-notifications-secret --from-literal=dynatrace-url=$DT_TENANT_LIVE --from-literal=dynatrace-token=$DT_NOTIFICATION_TOKEN
```

### 2.5 Create Business Events Secrets

We will need an OAuth client to send BizEvents.

[Follow steps 1 to 3 to create an OAuth Client](https://www.dynatrace.com/support/help/platform-modules/business-analytics/ba-api-ingest#oauth-client).

The client (and the service user) need these permissions:

1. `storage:bizevents:read`
1. `storage:buckets:read`
1. `storage:events:write`

You should now have 3 pieces of information:

1. `oAuth Client ID`: `dt0s02.1234ABCD`
2. `oAuth Client Secret`: `dt0s02.1234ABCD.*********`
3. `DT Account URN`: `urn:dtaccount:********-****-****-****-************`

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


## Step 3: Install and configure ArgoCD on Cluster

ArgoCD is our central GitOps Operator that deploys our Core Platform Components (taken from this repository) as well as will deploy custom apps that attendees will create during the class room hands-on tutorials!

```
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

In order for Argo to be accessible via the Ingress we need to do two things: apply a config map to tell it about allow unsecure traffic behind the ingress - and - the ingress itself.

```
kubectl apply -n argocd -f $FORKED_REPO_GITOPS_CLASSROOMID/manifests/platform/argoconfig/argo.ingress.yml
kubectl apply -n argocd -f $FORKED_REPO_GITOPS_CLASSROOMID/manifests/platform/argoconfig/argocd-cmd-params-cm.yml
```

Last but not least - we need to restart the argo-server pod to pickup the new ConfigMap
```
kubectl -n argocd scale deploy -l app.kubernetes.io/name=argocd-server --replicas=0
kubectl -n argocd scale deploy -l app.kubernetes.io/name=argocd-server --replicas=1
```

### Step 3.1 - Login to ArgoCD (if your K8s comes with an nginx ingress already)

We should now be able to login to ArgoCD with the following details assuming we have an Ingres Controller on EKS:
```
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "User: admin"
echo "Password: $ARGOCDPWD"
echo "URL: https://argo.$BASE_DOMAIN"
```

The ArgoUI should say "No Applications"


## Step 4: Apply Platform Apps: GitLab, Dynatrace, Backstage, ...

Now its time to tell ArgoCD to install all our platform components. For that we have a so called AppOfApps prepared that tells ArgoCD from which folders in our GitHub repository to fetch Backstage, GitLab, OpenTelemetry, ...

```
kubectl apply -f $FORKED_REPO_GITOPS_CLASSROOMID/platform.yml
```

Expect `argo-config` to be "Degraded" due to the `customer-apps` AppSet. This is fine because we haven't configured Gitlab yet, so it is safe to ignore this error for now.

## Step 4.1: In case ArgoCD needs the Ingress Controller installed via the Platform we can now log in

We should now definitely be able to login as we also installed our own nginx-ingress controller

```
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "User: admin"
echo "Password: $ARGOCDPWD"
echo "URL: https://argo.$BASE_DOMAIN"
```

## Step 5: Configure GitLab

GitLab is our git repository for all apps that the attendees will create and that will then be deployed by ArgoCD on the target k8s cluster.

To login to GitLab we use `root` as the username
Password can be obtained via
```
GITLABPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode)
echo "GitLab user: root"
echo "GitLab pwd: $GITLABPWD"
```

### 5.1 Create Personal Access Token (PAT)

In order for tools like Backstage to interact with GitLab we need a PAT.

1. Log into Gitlab
2. Go to your user profile `https://gitlab.$BASE_DOMAIN/-/profile/personal_access_tokens`
3. Create a PAT with `api`, `read_repository` and `write_repository`

### 5.2 Initialize GitLab with template repositories

When you have a Personal Access Token (PAT), configure this:
```
export GL_PAT="YOURGLPAT"
```

Now run the following:
```
# You should already have the next three set from our first step!
export FORKED_GITHUB_ORGNAME=dynatrace-perfclinics
export FORKED_REPO_NAME=hotday-perform-2024-test
export FORKED_TEMPLATE_REPO="https://github.com/$FORKED_GITHUB_ORGNAME/$FORKED_REPO_NAME"
export DT_TENANT="abc12345"
export BASE_DOMAIN="SOMEVALUE.dynatrace.training"
export DT_TENANT_LIVE="https://$DT_TENANT.sprint.dynatracelabs.com"
export DT_TENANT_APPS="https://$DT_TENANT.sprint.apps.dynatracelabs.com"
export DT_GEOLOCATION=GEOLOCATION-XXXXXXX     # eg: GEOLOCATION-DDAA176627F5667A for prod live

export GIT_USER="root"
export GIT_PWD="$GL_PAT"
export GIT_EMAIL="admin@example.com"
export GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME="backstage-templates"
export GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME="applications-template"

# 1) disable signups for security
# 2) set clone URL to https:// not http:// for backstage
# 3) disable the warning about ssh keys (all repos are public anyway)
# 4) disable "auto devops" pipeline and UI info box
curl --request PUT --header "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$BASE_DOMAIN/api/v4/application/settings?signup_enabled=false&custom_http_clone_url_root=https://gitlab.$BASE_DOMAIN/&user_show_add_ssh_key_message=false&auto_devops_enabled=false"

# Create 'group1'
# This group is where the backstage bootstrap process will create the "app teams" projects
# TODO: Rename to something more logical like "projects" or "teamprojects"
curl -X POST -d '{ "name": "group1", "path": "group1", "visibility": "public" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$BASE_DOMAIN/api/v4/groups"

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
# Then replace the placeholders
# Then commit and push files
cp -R $FORKED_REPO_NAME/backstagetemplates/* ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$DT_TENANT_LIVE#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_APPS_PLACEHOLDER#$DT_TENANT_APPS#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#BASE_DOMAIN_PLACEHOLDER#$BASE_DOMAIN#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#GEOLOCATION_PLACEHOLDER#$DT_GEOLOCATION#g" {} +

git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git

# Copy files from app template, then replace the placeholders, then commit
cd
cp -R $FORKED_REPO_NAME/apptemplates/* ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_LIVE_PLACEHOLDER#$DT_TENANT_LIVE#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#DT_TENANT_APPS_PLACEHOLDER#$DT_TENANT_APPS#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#BASE_DOMAIN_PLACEHOLDER#$BASE_DOMAIN#g" {} +
find . -type f \( -not -path '*/\.*' -not -iname "README.md" \) -exec sed -i "s#GEOLOCATION_PLACEHOLDER#$DT_GEOLOCATION#g" {} +

git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$BASE_DOMAIN/$GIT_USER/$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME.git
# Done creating "backstage template" repo
# Done creating "applications template" repo
```

## Step 6: Configure Backstage

Configure a secret for Backstage:

This is from the 'alice' user (see [argocd-cm.yml]($FORKED_REPO_GITOPS_CLASSROOMID/manifests/platform/argoconfig/argocd-cm.yml))

The `argocd` CLI utility will be required:
```
# Download the argocd CLI and authenticate
wget -O argocd https://github.com/argoproj/argo-cd/releases/download/v2.9.3/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/bin

# Set the default context to the argocd namespace so 'argocd' CLI works
kubectl config set-context --current --namespace=argocd
# Now authenticate
argocd login argo --core

# Set the default context to the argocd namespace so 'argocd' CLI works
ARGOCD_TOKEN=$(argocd account generate-token --account alice)
# Reset the context to 'default' namespace
kubectl config set-context --current --namespace=default 
kubectl -n backstage create secret generic backstage-secrets --from-literal=GITLAB_TOKEN=$GL_PAT --from-literal=ARGOCD_TOKEN=$ARGOCD_TOKEN --from-literal=DT_TENANT_LIVE=$DT_TENANT_LIVE --from-literal=DT_EVENT_INGEST_TOKEN=$DT_NOTIFICATION_TOKEN
```

`customer-apps` in `argoconfig` is still "degraded". This is an old error. Now that Gitlab is available, it will work. Delete the AppSet now and it will recreate and go green.

### Important: Recycle Argo Application Set Controller
the Argo ApplicationSet controller seems to stop working even after the link to Gitlab is fixed.

Solve this by restarting the controller:

```
kubectl -n argocd scale deploy/argocd-applicationset-controller --replicas=0
kubectl -n argocd scale deploy/argocd-applicationset-controller --replicas=1
```

## Step 7: Recap

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
GITLABURL=https://gitlab.$BASE_DOMAIN
GITLABUSER=root
GITLABPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode)

ARGOCDURL=https://argocd.$BASE_DOMAIN
ARGOCDUSER=admin
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

BACKSTAGEURL=https://backstage.$BASE_DOMAIN

echo "-------------------------------------------------------------"
echo "GitLab:    $GITLABURL"
echo "User:      $GITLABUSER"
echo "Pwd:       $GITLABPWD"
echo "----"
echo "ArgoCD:    $ARGOCDURL"
echo "User:      $ARGOCDUSER"
echo "Pwd:       $ARGOCDPWD"
echo "----"
echo "Backstage: $BACKSTAGEURL"
echo "----"
echo "Dynatrace: $DT_TENANT_APPS"
```

## Step 8: Usage

1. Visit backstage
2. Create a new app based on the default template
3. Fill out all form values eg. `team4`, ...
4. Create the application
5. Visit argocd / backstage to see your app being deployed
6. Visit Dynatrace to see everything being deployed

## Troubleshooting

### Argo is slow to create application
Issue: An app is created in Backstage but is not appearing in Argo
Workaround: Restart the ApplicationSet controller pod

```
kubectl -n argocd scale deploy/argocd-applicationset-controller --replicas=0
kubectl -n argocd scale deploy/argocd-applicationset-controller --replicas=1
```
