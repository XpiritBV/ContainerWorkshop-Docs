#  <a name="start"></a>Lab 1 - Getting started

This lab is going to let you prepare your development environment for the rest of the labs in the workshop. Not all steps are required. The more you can prepare, the better the experience during the workshop.

Goals for this lab: 
- [Get the optional subscriptions](#1)
- [Prepare development laptop](#2)
- [Download required and optional tooling](#3)
- [Clone Git repository for lab code](#4)
- [Run and inspect lab application](#5)
- [Create a Kubernetes cluster](#6)
- [Save time later](#7)
 
## <a name="1"></a>1. Get optional subscriptions
If you want to learn how to work with Azure and Azure DevOps, make sure to get access to (trial) subscriptions.

For [Lab 8 - Azure DevOps pipelines](Lab8-AzDOPipelines.md), you'll need an Azure DevOps subscription. Get one for free here: [dev.azure.com](https://dev.azure.com).

To create a Kubernetes cluster and/or a Container Registry inside Azure, you will need an Azure subscription.
Create a free [trial account here](https://azure.microsoft.com/en-us/free/).

## <a name="2"></a>2. Prepare your development laptop
Make sure that your laptop is up-to-date with the latest security patches. This workshop is specific towards Windows as the operating system for your machine. The labs can also be done on Linux and Mac.

## <a name="3"></a>3. Install tools

### Windows Subsystem for Linux
- On Windows 10, enable WSL, by following the steps described here:
[Enable WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10#manual-installation-steps)
- Add the Ubuntu distro from the [Microsoft Store](https://www.microsoft.com/en-us/p/ubuntu/9nblggh4msv6)

> If you cannot do this, you will use a Linux Virtual Machine to run Linux containers on Windows later.

> Also, you'll need to run [Lab 12 - Working with Istio on Kubernetes](Lab12-Istio.md) in an [Azure Cloud Shell](https://devblogs.microsoft.com/commandline/the-azure-cloud-shell-connector-in-windows-terminal/).

For the best experience, run the entire workshop using Linux based terminals, even on Windows.

### Visual Studio 2019 / VS Code
First, you will need to have a development IDE installed. The most preferable IDE is [Visual Studio 2019](https://www.visualstudio.com/vs/) if you are running the Windows operating system.

You may want to consider installing [Visual Studio Code](https://code.visualstudio.com/) in the following cases:
- Your development machine is running OSX or a Linux distribution.
- You want to have an light-weight IDE or use an alternative to Visual Studio 2019.
- You want to run any of the labs including and above lab 10.

> For Visual Studio Code, also install the [Kubernetes](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools) and [Docker](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker) extensions.

### Docker Desktop (Windows & Mac)
Second, you are going to need the Docker Community Edition tooling on your development machine. Depending on your operating system you need to choose the correct version of the tooling. Instructions for installing the tooling can be found [here](https://docs.docker.com/install/). You can choose either the stable or edge channel.

> Download and install Docker Community Edition (version 3.1.0 or higher):
> - [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
> - [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)

When on Windows, make sure to enable WSL integration, if possible.
![](images/dockerdesktop-wsl.png)

### Azure CLI
If you want to interact with Azure from your local machine, you will also need the [Azure Command Line 2.0 tooling](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) for interaction with Azure resources. 
> Install [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest)

### .NET Framework 5
Download and install [.NET 5](https://download.visualstudio.microsoft.com/download/pr/75483251-b77a-41a9-9ea2-05fb1668e148/2c27ea12ec2c93434c447f4009f2c2d2/dotnet-sdk-5.0.102-win-x64.exe) if needed.

### Git CLI
Download [git](https://git-scm.com/downloads) if needed. Store the file in a location that is part of the PATH variable, e.g. "C:\Program Files".

### Optional tooling
The following optional tools are recommended, but not required.

- [GitHub Desktop](https://desktop.github.com/) for Git Shell and Git repository utilities
- [PuTTY](http://www.putty.org/) for `PuTTY.exe` and `PuTTYgen.exe`

## <a name="4"></a>4. Clone Git repositories with labs and code
The workshop uses an example to get you started with Dockerizing a typical ASP.NET Core application. 

Clone the repository to your development machine:
- Create a folder for the source code, e.g. `C:\Sources\ContainerWorkshop`.
- Open a command prompt (terminal) from that folder
- Clone the Git repositories for the workshop files

### Code
Create a local copy of the [source code](https://github.com/XpiritBV/ContainerWorkshop-Code):

```
git clone https://github.com/XpiritBV/ContainerWorkshop-Code.git
```

### Labs
Create a local copy of the [labs](https://github.com/XpiritBV/ContainerWorkshop-Docs):
```
git clone https://github.com/XpiritBV/ContainerWorkshop-Docs.git
```
- Set an environment variable to the root of the cloned repository from PowerShell:

```powershell
pwsh
$env:workshop = 'C:\Sources\ContainerWorkshop'
```

## <a name="5"></a>5. Compile and inspect demo application
Start Visual Studio and open the solution you cloned in the previous step. 
Build the application and fix any issues that might occur. 
Take a look at the solution and inspect the source code.

## <a name="6"></a>6. Create a Kubernetes cluster

During the labs, you will need admin access to a working Kubernetes cluster. You can choose to create one in Azure, or use Docker Desktop.

### Option 1: Create a Kubernetes cluster in Azure

This part requires you have an active Azure subscription. If you do not, you can create a trial account at [Microsoft Azure](https://azure.microsoft.com/en-us/free/). It will require access to a credit card, even though it will not be charged.

The easiest option to run these scripts, is to use the terminal inside the Azure portal.
![](images/AzurePortalCLI.png)

If you want to run the scripts from your local machine, first login to your Azure subscription using the Azure CLI and switch to the right subscription (in case you have multiple subscriptions). The second command will list your subscriptions. Choose the appropriate GUID to select the subscription you want to use and substitute that in the third command. 

```
az login
az account list -o table
az account set --subscription <your-subscription-guid>
```

After you have successfully logged in, create a resource group for your cluster.
![](images/AzurePortalCLI2.png)

```
az group create --location WestEurope --name ContainerWorkshop
```

If running locally, install the Azure Kubernetes Service Command-Line Interface tools by running and following the instructions from this command:
```
az aks install-cli
```

Make sure that the proper resource providers are enabled:
```
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
```

You can now create the cluster with the `az aks create` command:
```
az aks create --resource-group ContainerWorkshop --name ContainerWorkshopCluster --node-count 1 --enable-addons monitoring --generate-ssh-keys
```

It can take quite a long time for this command to complete. Take a coffee break! The command will show JSON based information about the cluster.
After the cluster has been created we can start interacting with it:

Get admin credentials for the Kubernetes management API:
```
az aks get-credentials --resource-group ContainerWorkshop --name ContainerWorkshopCluster -a
```

Get the portal url of the cluster:
```
az aks browse --resource-group ContainerWorkshop --name ContainerWorkshopCluster
```
This will show output similar to this:

```
To view the Kubernetes resources view, please open https://portal.azure.com/#resource/subscriptions/<your subscriptionid>/resourceGroups/ContainerWorkshop/providers/Microsoft.ContainerService/managedClusters/ContainerWorkshopCluster/workloads in a new tab
```
Open the link, and you should see information about your cluster:

![](images/AzurePortalK8s1.png)


This does not incur any costs other than your Azure resource consumption and should be fit easily within your Azure trial subscription credits.

> Make sure to delete the cluster when you have **finished** with this workshop:
> 
> `az aks delete --resource-group ContainerWorkshop --name ContainerWorkshopCluster`

### Option 2: Create a Kubernetes cluster in Docker Desktop (Windows & Mac)

You can also use Docker Desktop to create a Kubernetes cluster, that runs on your local machine.

![](images/dockerdesktop-wsl.png)

1. Make sure Docker Desktop is running.
1. Open the settings screen, by clicking on the whale-icon in your taskbar.
1. In the 'Resources' tab, select 'WSL INTEGRATION'
1. Check 'Enable integration with my default WSL distro
1. Enable any additional WSL distro's if you like.

After a few minutes, you should be able to run `wsl` and interact with Docker and Kubernetes.
Check if everything works:

1. Open a terminal
1. Run `wsl` to launch your default wsl distro
1. Run `docker run hello-world`
   The output should look very similar to this:
    ```
    Unable to find image 'hello-world:latest' locally
    latest: Pulling from library/hello-world
    0e03bdcc26d7: Pull complete
    Digest: sha256:31b9c7d48790f0d8c50ab433d9c3b7e17666d6993084c002c2ff1ca09b96391d
    Status: Downloaded newer image for hello-world:latest

    Hello from Docker!
    ```
1. Run `kubectl get nodes`
   The output should look similar to this:
   ```
   NAME             STATUS   ROLES    AGE    VERSION
   docker-desktop   Ready    master   8m2s   v1.19.3
   ```

If the output checks out, you are good to go. If not, ask your proctor for some help.

> If Docker Desktop keeps crashing during startup, assign more memory: 
>
> `wsl --shutdown`
>
> `notepad "$env:USERPROFILE/.wslconfig"`
>
> Increase WSL ram to 4GB `memory=4GB`
>
> Restart the Docker Desktop service

## <a name="7"></a> 7. Save some time later
During this workshop we will use a couple of Docker images. You can download these images at home ahead of time, so you don't have to wait for them to download during the workshop:

```
docker pull mcr.microsoft.com/mssql/server:2019-latest
docker pull portainer/portainer-ce
docker pull nginx
docker pull alpine
docker pull busybox
docker pull curlimages/curl
```

## Wrapup
You have prepared your laptop and container environment to be ready for the next labs. Any issues you may have, can probably be resolved during the labs. Ask your fellow attendees or the proctor to help you, if you cannot solve the issues.

Continue with [Lab 2 - Docker101](Lab2-Docker101.md).
