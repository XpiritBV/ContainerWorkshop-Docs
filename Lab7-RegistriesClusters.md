# Lab 7 - Container registries and clusters

In this lab you are going to learn about registries and clusters. This includes pushing images to the registry and deploying compositions to a running cluster.

Goals for this lab:

- [Push images to a container registry](#push)
- [Connecting to your cluster](#connect)
- [Create and enhance cluster composition for Docker Swarm](#create)
- [Deploy images to cluster](#deploy)
- [Run and manage composition in cluster](#run)
- [(Optional) Switch to Azure SQL Database](#sql)

> ##### Important
> Make sure you have:
>
> - Checked out the `start` from the repository.
> - Completed previous labs.
> - Configured 'Docker Desktop' to run Linux containers.
> - Changed terminal working directory to `resources/lab07`

## <a name="push"></a>Pushing images to a registry

Docker registries are to Docker container images what NuGet feeds are to NuGet packages. They allow access to existing images that have been published by the owner. They can be private or publicly accessible.

First, you will create an Azure Container Registry which allows (multiple) private repositories inside your registry. Run the following command from the command-line to create it:
Find a unique name for your container registry, e.g. `containerworkshopregistry` plus your last name. It is best to use lower-casing.

```cmd
az group create --name ContainerWorkshop --location WestEurope
az acr create --name <registry-name> --resource-group ContainerWorkshop --sku Basic --admin-enabled true --location WestEurope
```

After creation, check if the registry is created successfully:

```cmd
az acr list --resource-group containerworkshop --output table
```

Notice the `LOGIN SERVER` name.

If you want to create a Docker Hub registry, follow the steps [documented here](https://docs.docker.com/docker-hub/repos/)

Now that we have a registry, you should try to create working images for our application and push the images to the registry. First, create a `Release` build of the solution. Run the build to check whether it is working correctly. With a successful build run `docker images` and verify that you have new images that are not tagged as `:dev`. Output should be similar to this:

```
REPOSITORY                        TAG                 IMAGE ID            CREATED             SIZE
gamingwebapp                      latest              52ca01b894b7        26 minutes ago      302MB
leaderboardwebapi                 latest              388e4e4f4abd        26 minutes ago      303MB
gamingwebapp                      dev                 838b58f6e96d        2 days ago          299MB
leaderboardwebapi                 dev                 86c3b70e7efa        2 days ago          299MB
```

The images for the release build are tagged with `latest`. Make sure you understand why a `Debug` build creates images that are tagged `:dev`.

> ##### Hint
> You may want to look in the special folder `obj/Docker` at the solution level again.

The current images are not suitable to be pushed to the registry, since their name does not include the name of the registry you created a moment ago. That format is `registry/repository` with the repository representing the name of the container image as it is at the moment, e.g. `containerworkshop/gamingwebapp`.

Tag the current images again to include the registry name. This will not create a new image, but it does appear as a separate entry in your local images list.

```
docker tag gamingwebapp:latest <full-registry-name>/gamingwebapp:latest
```
> Note: use lower case strings only

Make sure you replace the name `<full-registry-name>` with your registry name. For Azure Container Registry, use the value of `LOGIN SERVER` as the registry name, e.g. `containerworkshopregistry.azurecr.io`. For Docker Hub it is the simple name, like `containerworkshop`.

Perform the tagging for the Web API image as well. Verify that the images are tagged and have the same image ID as the ones without registry name.

Login to the registry. For example, for Docker Hub this will be:

```cmd
docker login
```

and for ACR, get the credentials first, by using:

```cmd
az acr credential show --resource-group ContainerWorkshop --name <registry>
```

Next, you can login with:

```cmd
az acr login --name <registry> -u <username>
```

Replace the name with your unique registry's name and `<username>` with the one listed at the bottom of the output for `az acr credential show` and supply the one of the two passwords that were displayed.

When you have successfully logged in, push both images to the their respective repositories in the registry:

```
docker push <registry.azurecr.io>/gamingwebapp:latest
```
Again remember to replace the registry name, with yours.
The output of the push will resemble something like this:
```
The push refers to repository [containerregistry.azurecr.io/gamingwebapp]
d3dd2499dbb1: Pushed
0506db78f43c: Pushed
55e0e17f207d: Pushed
f689d872fdfe: Pushed
cf5b3c6798f7: Pushed
latest: digest: sha256:05d2b2ceea30bbaa1fd0f37ac88d1185e66f055a29b85bf6438ce4658e379da6 size: 1791
```

Verify that there is now a new repository in your registry by running:
```
az acr repository list --name <registry>
```

Remove your local images for the web application release build from the Docker CLI by calling:
```
docker rmi <full-registry-name>/gamingwebapp:latest
docker rmi gamingwebapp:latest
docker rmi gamingwebapp:dev
```

Verify that the `gamingwebapp` images are no longer on your machine.

When using DockerHub, visit your registry at https://hub.docker.com/r/<registry>/gamingwebapp/ to check whether the image is actually in the repository.

When using ACR, use this command:
```cmd
az acr repository list --name <registry>
az acr repository show-tags --name <registry> --repository gamingwebapp
```

Then, try to pull the image from the registry with:
```
docker pull <full-registry-name>/gamingwebapp:latest
```
This process can be automated by a build and release pipeline. You will learn how to do that in a later lab.

**Repeat the procedure for the Leaderboard Web API.**

## Connecting to your cluster

At this point you will need to have access to a Docker cluster. You can use your local cluster running in Docker Desktop and Azure Kubernetes Service. If you haven't done so already, create an Azure Kubernetes Service cluster in Azure. [Lab 1](Lab1-GettingStarted.md) describes how you can create one.

First, connect to your local cluster in Docker Desktop. There are several ways to connect to it:

The easiest way is to use Visual Studio Code and the Kubernetes extension. Navigate to the Kubernetes pane on the left and find your local cluster listed as `docker-desktop`. Right-click it and use `Set as current cluster` if you have more than one cluster and yours is not selected yet. The `>` glyph in front of the cluster node indicates the current cluster.  
![](images/VSCodeKubernetesExtension.png)

You can also deploy a Kubernetes hosted dashboard using this command:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
```
You can reach the dashboard by running a proxy:
```
kubectl proxy
```
The dashboard can be found at this endpoint:
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```
You will reach a login screen where you need to provide a token (or kubeconfig file).
![](images/KubernetesDashboardLogin.png)
The token can be found in two steps. First run this command:
```
kubectl -n kube-system get secret
```
This will list all registered system-specific secrets in Kubernetes. Find the name for the `default-token` in the list. It is similar to `default-token-v9rxc`, but the last part will differ for your installation. 

```
kubectl -n kube-system describe secret default-token-v9rxc
```
The command gives output similar to:
```
Name:         default-token-v9rxc
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: default
              kubernetes.io/service-account.uid: 08a100bd-df9a-4f3f-b11a-106fe92d2871

Type:  kubernetes.io/service-account-token

Data
====
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6InI0U29nakdwNmR1T3RLVzBRTVBUZUxGSWhtYl9ZRExsNXpBYmNvdjl0MWcifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLXY5cnhjIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIwOGExMDBiZC1kZjlhLTRmM2YtYjExYS0xMDZmZTkyZDI4NzEiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06ZGVmYXVsdCJ9.lNaY8rnoZv0BTNoI-F7fj-CtxtWF_fulymFL1k2y0BpgvPRfojsKy7HBzBi9qnUwipLK46AksCOzgg0Z3DbpF9BN_4VIBQmfJ4_yH1v8TYqC7LSriyIYEST_hJIRCQbJ919CXxSxW-Teo8mJ3mZo9PheBiARLas3P-e2e_xu14_Q5DnvjCcmgxTpPBEBhi5G-4O7fDybVljZxgeBQM65ODCd5pTjPp_SPrFykw2qWCHnEl28q5wUvtGYlXle9aAN1arZq1O2_h98LAYUUryYzGNEp4Ma7CIdytf1nwwpSaAmRUAC4RYWL41DDp3oeD9-hiQsZ-hLYWxZlQ8A
ca.crt:     1066 bytes
namespace:  11 bytes
```
Copy and paste the line for `token` into the login field that reads `Enter token` and click `Sign in`. You should see the dashboard appear.

![](images/KubernetesDashboard.png)

> ****Important****
>
> If you get any errors in the Kubernetes dashboard, revisit [Module 1](Lab1-GettingStarted.md) and fix the dashboard by changing the RBAC configuration.

You can also set your cluster as the active context and interact with it using kubectl commands. First, retrieve a list of the current available clusters and contexts with `kubectl` commands and then set your cluster as active. All `kubectl` will be executed against that context from now.
```
kubectl cluster-info
kubectl config get-clusters
kubectl config get-contexts
kubectl config use-context ContainerWorkshopCluster-admin
```

Open the [Azure Portal](https://portal.azure.com). Find the resource for your cluster in the resource group `ContainerWorkshop`. Make a note of the property `API server address`.

> ****Question****
>
> Which two important actions can be performed on your cluster from the Azure portal?

Open the resource group that is prefixed `MC_ContainerWorkshop_ContainerWorkshopCluster...`
Inside this resource group you will find the underlying resources of your AKS cluster. 

> What resources are part of a AKS cluster? What is the purpose of each of these?

## Deploy your Docker composition to a cluster

Kubernetes does not use Docker Compose files for its deployments. Instead, it uses deployment manifests. The resources files under Lab 6  has a file called `01-gamingwebapp.k8s-static.yaml`. Create a folder `deployment` in the root of your code repository and copy the file into it. Right-click your Visual Studio solution and add the YAML file as an existing file. The manifest file should appear in `Solution items` in the Solution Explorer. Open the file and examine the contents.

You need to make a few changes to the manifest for it to be useable. In particular, make sure you change the following marker
`__containerregistry__`
	
Execute the command `az acr show -n <registry> --query loginServer` to get the fully qualified name of the registry and replace the marker with its value.

In order to be able to pull images from your registry into the cluster, you will need to authenticate against a private registry. This is not required, if you are using the public Docker Hub.

For Azure Container Registry, you can create another service principal that will be allowed access to the registry. Execute the following command after having replaced the placeholders with your specific details.

```
az ad sp create-for-rbac --scopes /subscriptions/<your-subscription-id>/resourcegroups/ContainerWorkshop/providers/Microsoft.ContainerRegistry/registries/<your-registry-name> --role Contributor --name ContainerWorkshopRegistryPrincipal
```
This command creates a principal that has the Contributor role in the ACR. Take a note of the password that is generated in the output.

> Note: if you cannot create this service principal, you can use the admin credentials you used for `docker login` earlier.

Next, you are going to create a secret named `pullkey` in the cluster to hold the credentials for this principal. The secret is specific to container registries and allows the manifest deployment to use the credentials to pull images for the Kubernetes services.

```
kubectl create secret docker-registry pullkey --docker-server <your-registry-name>.azurecr.io --docker-email <your-email> --docker-username=<your-principal-appid> --docker-password <generated-password>
```

Later, secrets will be covered in more detail. Execute the next command, again replacing the necessary items.

Save your work and go to the command prompt. Run the command:
```
kubectl config use-context docker-desktop
kubectl apply -f .\gamingwebapp.k8s-static.yaml
```
and watch the results from the dashboard (assuming the proxy is still running). This deployment could take some time to complete as container images must be downloaded to your local cluster. 

> Note that consecutive deployments of the same application, but with newer images, will go a lot faster.

Visit the gaming web app by going to `http://localhost`. You should see the page named 'All time highscore hall of fame'. 

> If you get  collisions on port 80, it is probably already in use on your development machine. You will need to shut down your local W3SVC service by running `net stop w3svc`, or change the `port` mapping in your deployment manifest.

If all is working well, try to deploy the solution to your AKS cluster as well. Switch the context to AKS and deploy the manifest:
```
kubectl config use-context ContainerWorkshopCluster-admin
kubectl apply -f .\gamingwebapp.k8s-static.yaml
```

Find the external IP address of the `gamingwebapp` pod by running this command:

```cmd
kubectl get service svc-gamingwebapp
```

Open a browser and navigate to the IP address listed under EXTERNAL-IP

> Note:
> The external IP address of the pod is exposed. All traffic to this IP address will be routed to that particular pod. Normally you would use HTTP Application Routing (a feature of Azure AKS) or a service mesh to split traffic based on parts of a DNS name for the same IP address.

If there are any errors, troubleshoot your setup and fix these.

> ##### Using containerized SQL Server in production
> It is not recommended to use SQL Server in a production scenario in this way. You will loose data, unless you take special measures, such as mounting volumes.
> However, for now you will keep the SQL Service instance in a Docker container.
>
> Make sure that you change the environment name to **Development** to provision the database `Leaderboard` and seed it using Entity Framework's `DbInitialize()`.
>
> If you have time left, try the stretch exercise below to switch to an Azure SQL Database.

## <a name="sql"></a>(Optional) Switch to Azure SQL Database

If you have time left, you can remove the SQL Server container altogether and switch to Azure SQL Database.
The steps you need to do are:
- Provision an Azure SQL Server database called `Leaderboard`, and an Azure SQL Server if necessary.

![](images/AzureSQLDatabase.png)

  You might have change the server name to be unique.

- Add a firewall rule to the Azure SQL Server to allow traffic coming in from the cluster. You can find the IP address of the cluster in the external load balancer NAT rules. As an alternative, you can give Azure resources access to the database server. Pay attention to the highlighted area in the firewall settings of your Azure SQL server resource.

![](images/AzureSQLFirewall.png)

- Connect with SQL Server Management Studio or any other query tool to execute a couple of SQL scripts to the server and database. 
> **Tip**: Visual Studio has a Server Explorer that also allows easy connections to local and Azure hosted databases.

Execute the following script to create the new `Leaderboard` database:
```sql
CREATE DATABASE [Leaderboard]
GO
```

Open the provided `02-createdatabase.sql` file in the lab resources. This SQL script adds two tables in your SQL Server `Leaderboard` database. Run it to create the tables and some initial test data. 

Next, run this following script on the database:
```sql
USE [master]
GO
CREATE LOGIN retrogamer WITH PASSWORD='abc123!@'

USE Leaderboard
GO

CREATE USER retrogamer
   FOR LOGIN retrogamer
   WITH DEFAULT_SCHEMA = dbo
GO
-- Add user to the database owner role
EXEC sp_addrolemember N'db_owner', N'retrogamer'
GO
```

- Change the connection string in the manifest file `gamingwebapp.k8s-static.yaml`. It should resemble the following, with the placeholder replaced with your server name:

```yaml
- ConnectionStrings:LeaderboardContext=Server=tcp:<your-sql-server>.database.windows.net,1433;Initial Catalog=Leaderboard;Persist Security Info=False;User ID=retrogamer;Password=abc123!@;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
```

Try to deploy the manifest again using Azure SQL Database now instead of the containerized version.

## Using Azure Managed Identity with ACR and AKS
In this chapter we will use a Managed Identity to connect Kubernetes to an Azure Container Registry.

### Introduction

If you want to store container images in a private repository and allow Kubernetes to use it, without managing credentials, you can use Azure Container Registry combined with [Azure Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview).
To do this, we will configure the cluster to integate with a container registry.

### Creating a Container Registry (if needed)
If you do not have one yet, create an Azure Container Registry. Run the following command from the command-line to create it:
Use a unique name for your container registry, e.g. `ContainerWorkshopContainerRegistry` plus your last name or initials.

```cmd
registryName=ContainerWorkshopContainerRegistry
az group create --name ContainerWorkshop --location WestEurope
az acr create --name $registryName --resource-group ContainerWorkshop --sku Basic --admin-enabled true --location WestEurope
```

Get the resource ID `id` value from the output. It should be similar to this:
```  
"id": "/subscriptions/<subscriptionid>/resourceGroups/ContainerWorkshop/providers/Microsoft.ContainerRegistry/registries/<registryName>"
```

### Connecting AKS to the registry
Run the `az aks update` command to connect an existing AKS cluster to an existing Azure Container Registry, passing in the resource Id of the registry:
```
registryResourceId=/subscriptions/<subscriptionid>/resourceGroups/ContainerWorkshop/providers/Microsoft.ContainerRegistry/registries/$registryName

az aks update --name ContainerWorkshopCluster --resource-group ContainerWorkshop --attach-acr $registryResourceId
```

This operation takes a few seconds to complete.

### Test the connection
To test the connection, we will import the nginx image into our private registry. 
```
az acr import  -n $registryName --source docker.io/library/nginx:latest --image nginx:v1
```

We will now create a Deployment that uses the nginx image from the private registry. We must first update the template to specify the registry name.
Open the file `00-nginx-from-acr.yaml` and replace the `image` value with your registry name. (e.g. `containerworkshopcontainerregistry.azurecr.io/nginx:v1`)

Now create the deployment using `kubectl apply`:
```
kubectl apply -f 00-nginx-from-acr.yaml
```

Assert that your Pod runs well by using `kubectl get pod `:
```
kubectl get pods

NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-fc9fcfdd8-584xq   1/1     Running   0          29s
nginx-deployment-fc9fcfdd8-c9x7v   1/1     Running   0          17s
```

If the status equals 'Running', everything works correctly.

## Cleanup

Remove the nginx pod:
```
kubectl delete -f 00-nginx-from-acr.yaml
```

Remove the Container Registry integration:
```cmd
az aks update --name ContainerWorkshopCluster --resource-group ContainerWorkshop --detach-acr $registryResourceId
```

## Wrapup

In this lab you have created a composition that is able to deploy a stack of services to a cluster. Necessary changes to the environment variables were made and perhaps you even got to use an Azure SQL Database.

Continue with [Lab 8 - Security](Lab8-Security.md).
