# Lab 8 - Azure DevOps Build and release pipelines

Goals for this lab:
- Create build pipeline to build images
- Create release pipeline for deploying images to registry
- Deploy images to cluster

## <a name="run"></a>Get existing application
We will start with or continue running the existing ASP.NET Core application from Visual Studio. Make sure you have cloned the Git repository, or return to [Lab 1 - Getting Started](Lab1-GettingStarted.md) to clone it now if you do not have the sources. Switch to the `master` branch by using this command :

```
git checkout master
```

> ##### Important
> Make sure you have switched to the `master` branch to use the right .NET solution.

## Working with Azure DevOps

Before you can get started with building pipelines, you need a Azure DevOps (AZDO) account and a team project. You can use an existing AZDO account, or create a new one at [dev.azure.Com ](https://dev.azure.com).

Also, your cloned Git repository needs to be pushed to the AzDO project. Assuming you have your current work branch checked out, you can change the URL for the origin to point to the Git repo in your Team Project.

```cmd
git remote set-url origin https://dev.azure.com/<your-vsts-account>/<your-teamproject>/_git/containerworkshop
git push -u origin --all
```

## Create build pipelines

Login to your AZDO account and switch to the correct team project. Go to `Repos, Files` and check that your source code is there. Switch to `Pipelines, Build` and create a new definition for a Build pipeline. Select the link for Visual Designer at the start. Pick `Azure Repos Git` and the master branch of your Git repo.

From the available templates select the `ASP.NET Application with containers` template to give yourself a head start.

<img src="images/ASPNETWithContainersVSTSBuildTemplate.png" width="400" />

Under the `Pipeline` properties for the build process, select `Hosted Ubuntu 1604` as the Agent pool:

<img src="images/BuildProcessVSTS.png" width="600" />

Inspect the tasks in the pipeline. You can see that there are three tasks related to building the source code. Additionally, there are tasks for creating container images, and pushing these to your registry. The final two steps will place build items in a staging directory and publish these as part of the build artifacts.

Remove the first 3 tasks from the pipeline, as those are meant for ASP.NET, not ASP.NET Core. You will build your application code using containers with the Docker composition file.
Add a new `Docker Compose` task and name it `Compile assemblies`.

Click the little exclamation mark next to the properties:

- Container Registry Type
- Azure subscription
- Azure Container Registry
- Docker Compose File
- Environment Variables
and choose `Link` from the popup window.

Enter `build` as the Command that will execute for `Run a Docker Compose command`.

Select the pipeline at the top again to fill in all linked properties, as described below.

Notice that this template assumes that you will use an Azure Container Registry. You can use one if you created it before. If not, refer back to [Lab 6](Lab6-RegistriesClusters.md) to read how to create the container registry.

You need to create a connection between Azure DevOps and your Azure subscription. Open the details of the first task, locate the property for the `Azure subscription` and add your subscription details.

<img src="images/NewVSTSConnection.png" width="600" />

After the registration of your subscription is completed, select your container registry from the dropdown below.

Notice how the Docker Compose file is already preselected to be `docker-compose.yml`. This aligns with the previous design decision to only include actual images relevant to the application components to be in this Docker Compose file.

Further down, specify an environment variable for the registry, so the created images have the correct fully qualified name:

```cmd
DOCKER_REGISTRY=<registry>.azurecr.io/
```

You can specify additional Docker Compose files. Remove the reference to file `docker-compose.ci.yml` from the other three Docker Compose tasks.

Link the environment variables for all four Docker Compose tasks.

This completes your first task to build your sources. The other 3 tasks 

In the `Copy Files` task set the `Contents` property to this file:
```
**/gamingwebapp.k8s-dep.yaml
```
In the last task for `Publish Artifacts`, specify `artifacts` as the Artifact name.

Save the build definition and queue a new build. Check whether the build completes successfully and fix any errors that might occur. Inspect the build artifacts, notice that there are 2 artifacts there, the Kubernetes manifest and a modified Docker compose file. Download the `docker-compose.yml` file and open it. It should resemble this:

```yaml
services:
  gamingwebapp:
    build:
      context: ./src/RetroGaming2017/src/Applications/GamingWebApp
      dockerfile: Dockerfile
    image: <your-registry>.azurecr.io/gamingwebapp@sha256:e198caef40f1e886c3a70db008a69aa9995dc00301a035867757aad9560d9088
  leaderboard.webapi:
    build:
      context: ./src/RetroGaming2017/src/Services/Leaderboard.WebAPI
      dockerfile: Dockerfile
    image: <your-registry>.azurecr.io/leaderboard.webapi@sha256:40b83b74b7e6c5a06da2adbaf5d99aec64cde63c16a66956091cbddb93349f86
version: '3.0'
```

Notice how the image names have an appended SHA256 digest value to confirm their identity in the registry. This file could be used to release the images into the cluster later on.

When your build has completed without errors, you should find that your container registry has a new image that is tagged with the build number. Verify this at your registry from the Azure portal.

If this all is working correctly you are ready to release the new image to the cluster.

## Release new images to cluster

With the Docker images located in the registry, you can release these to your cluster by instructing it deploy the composition defined in the Kubernetes manifest file. This file `gamingwebapp.k8s-dep.yaml` is now part of the build artifacts. This file contains various tokens that need to be replaced by actual values, such as the build ID and sensitive data.

Create a new release definition from the Releases tab in AZDO. Choose an `Deploy to a Kubernetes cluster` and name the first stage `Production`.
Add a new artifact and select the previously made pipeline as the `Source`.

Select the tasks in the Production environment from the link `1 job, 1 task` link. Navigate to its empty task list and set the Agent selection to `Hosted VS2017` under the Agent job.

Next, select the `Deploy to Kubernetes` task and create a connection to your cluster with the `+ New` button. A modal dialog pops up. Give the connection a name, such as `ContainerWorkshopCluster`.
Finally, you need to get the KubeConfig from your Kubernetes cluster. Run the command:
```
az aks get-credentials --name ContainerWorkshopCluster --resource-group ContainerWorkshop -a --file -
```
This will dump the configuration to the output window. Copy it in the dialog of AZDO. Check the checkbox for `Accept untrusted certificates`. Verify the connection. If all is well, close the dialog by clicking `OK`.

Set the property for Namespace to `$(namespace)`.

Check the checkbox Use Configuration Files and choose the `gamingwebapp.k8s-dep.yaml` file from the artifacts.

Finally, you are going to add a number of pipeline variables to serve as the replacement values in the deployment manifest and the namespace in the cluster to which will be deployed.

Add a `Replace Tokens` task as the first task of the release pipeline. You might have to download it from the Marketplace first. It is a task by Guillaume Rouchon and you can find more information [here](https://github.com/qetza/vsts-replacetokens-task#readme).

Name the new task `Replace tokens in manifest` and set the root directory to `$(System.DefaultWorkingDirectory)/_RetroGaming2019CIBuild/docker-compose`. Specify `deployment/gamingwebapp.k8s-dep.yaml` as the Target Files property. Set the Prefix and Suffix to __.

Here is the list of variables you need to create:

Name | Value (example)
--- | ---
containerregistry | containerworkshopregistry.azurecr.io
dns | imworld.5a79006cd4b54431acb1.westeurope.aksapp.io
keyvaultclientid | ca5a0aeb-0eec-49a3-a527-a29e2524fa5b
keyvaultclientsecret | 45gSC1AZ3lkaSUHpsqFfL/+vddtbshVs1umC0IZWsVY=
keyvaulturl | https://Containerworkshop.vault.azure.net
namespace | workshop
aikey | (empty)

Each of these variable names should be familiar and known to you (except the `aikey`, which remains empty for now). For the key vault related values (e.g. keyvaultclientid), use the values from the [Security Lab](Lab7-Security.md#adding-support-for-azure-key-vault).
Some of these will be used later.

You can remove the `volumeMounts` and `spec` from the `dep-leaderboardwebapi` deployment, now that the values in it are coming from the pipeline variables and the environment variables. 

Try your release pipeline by creating a new release. Check whether the release is successful and fix any errors. You might want to check the Kubernetes dashboard to see if the cluster deployment succeeded as well. If all is well, you should be able to access the DNS host endpoint of your HTTP application route to view the web application.

## Wrapup

In this lab you have created a build pipeline to build and push the container images for your .NET solution. You used a release pipeline to deploy the composition to a cluster in Azure.

Continue with [Lab 9 - Monitoring](Lab9-Monitoring.md).
