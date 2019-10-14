# Lab 14 Azure Dev Spaces

During this lab, you will become familiar with [Azure Dev Spaces]().

Azure Dev Spaces is a developer assisting technology that allows them to deploy, test and debug software directly on an AKS cluster. 
Similar to Istio, it works by injecting 3 sidecar-containers together with your application inside a Pod. Dev Spaces works inside Namespaces labeled `azds.io/space=true`. 

It works in the following way. Imagine you are working on an application containing a Web Frontend and an API, running on AKS, in a Namespace called 'dev'.
You would first create a personal Dev Space called 'custom'. Then, by using the client-side tooling, you would enable Dev Spaces for your solution. Next, you would deploy the part of the application you are working on. Let's say, the Frontend. Azure Dev Spaces will generate a unique URL for you, and ensures all HTTP calls made to the Frontend will be routed to your personal version of it. However, all HTTP calls made internally, from the Frontend to the API, would still be routed to the version running in the 'dev' Namespace.
So Dev Spaces allow you to replace a Pod with a copy of your own, and use that for testing purposes.


1. devspaces-proxy : Manages all TCP network traffic in and out of the Pod, and route HTTP calls to child spaces if needed. 
2. devspaces-proxy-init: Bootstraps networking rules inside the application container, ensuring all TCP traffic is routed through the devspaces-proxy.
3. devspaces-build container: Compiles software, builds container images, to be run locally.  

Goals for this lab:
- Gain a **basic** understanding Dev Spaces

## <a name='start'></a>Inspect your environment
We will debug an application using Visual Studio. Make sure you installed it, return to [Lab 1 - Getting Started](Lab1-GettingStarted#start) if you do not have it installed. 
You will need an [AKS cluster](Lab1-GettingStarted#5) as well.
Also, make sure you have [this](https://github.com/XpiritBV/ContainerWorkshop2019Docs) repository cloned, so you have a copy of the Kubernetes template files on your machine.

We will enable Dev Spaces for the [demo project](https://github.com/XpiritBV/ContainerWorkshop2018), so make sure you also have cloned that repository, checked out to the 'devspaces' branch.

1. In VS Code, in the terminal, move to the repository directory named 'resources/lab14'.


## <a name='tiller'></a>Deploy Helm with Tiller

> Note that using Helm is simple, but the default settings, as used here, are not secure. In real life, you should use Helm without Tiller. For demo purposes, it works fine.

Create a Tiller ServiceAccount with cluster administrator rights, and deploy Helm with Tiller temporarily:

```
kubectl apply -f 01-TillerSA.yaml
helm init --service-account tiller --wait
```

## <a name='devspac'></a>Deploy Azure Dev Spaces

Run the following command to enable Dev Spaces and install the CLI. Make sure to accept the license terms:

```
az aks use-dev-spaces -g ContainerWorkshop -n ContainerWorkshopCluster --space default --yes

The installed extension 'dev-spaces-preview' is in preview.
Installing Dev Spaces (Preview) commands...
Installing Azure Dev Spaces client components...
The following dependencies will be installed: xdg-utils, unzip, .NET Core Runtime

By continuing, you agree to the Microsoft Software License Terms (https://aka.ms/azds-LicenseTerms) and Microsoft Privacy Statement (https://aka.ms/privacystatement). Do you want to continue? (Y/n): y
```

> Note that this operation takes a while.
> Replace the values for resource group `g` and cluster name `n` with your own cluster details if needed.

## <a name='deploy-workload'></a> Deploying a workload

It is now time to deploy a workload to the cluster. For this demo, we'll use the tool `kompose` to deploy a docker-compose file to Kubernetes without modifications. First, [download](https://kubernetes.io/docs/tasks/configure-pod-container/translate-compose-kubernetes/#install-kompose) the tool.
Next, use the following command to deploy the demo solution:

```
kompose up -f docker-compose.remote.yml
```
> Note that it can take quite some time (several minutes) for SQL Server to start and for the database to be created.

In VS Code, right click on the `gamingwebapp` pod and open up a port-forward, from local port 8080 to remote port 8080.
In your browser, navigate to the url: `http://localhost:8080/`.
Make sure the 'Pacman' high score is displayed; this indicates that all system components (web app, web api and database) are running.

## <a name='enable'></a>Enable Azure Dev Spaces for the GamingWebApp

In Visual Studio 2017 or 2019, open the [ContainerWorkshop](https://github.com/XpiritBV/ContainerWorkshop2018) solution.
Make sure that the GamingWebApp project is configured as the startup project.
Pull down the hosting environments dropdown and select Azure Dev Spaces from the list.

![](images/devspaces-01.png)

This should show a pop-up that allows you to select the cluster you have provisioned for Dev Spaces earlier. 
**Make sure to allow public access.**

If not, you can enable it by using the CLI in VS Code:

```
$ <your repo folder>\ContainerWorkshop2018\src\Applications\GamingWebApp>azds prep --public
```

One of the results, is a new Docker file, named `\ContainerWorkshop2018\src\Applications\GamingWebApp\Dockerfile.develop`
Open this file and on line 5, add an environment variable, that specifies where the Web API can be found:

```
ENV LeaderboardApiOptions__BaseUrl=http://leaderboardwebapi
```

And change the default port to 8080, by replacing the value for `ASPNETCORE_URLS`:

```
ENV ASPNETCORE_URLS=http://+:8080
```

The following command will start Azure Dev Spaces from the CLI:

```
azds space select -n default
azds up
```

## <a name='debug'></a>Debugging the GamingWebApp
Place a breakpoint inside the file `IndexModel.cs` on line 32. Refresh the page. If all works well, you should now see your breakpoint being hit.
You are now debugging code that runs inside AKS, without the need to mock the calls to the Web API.

## <a name='clean'></a>Cleaning up

Remove Azure Dev Spaces support by using the Azure Portal.
Undo pending changes to the 'devspaces' branch.

