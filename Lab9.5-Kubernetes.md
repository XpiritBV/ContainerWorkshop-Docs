# Lab 9.5 How to use Kubernetes

During this lab, you will become familiar with Kubernetes concepts, showing you how to deploy a container, scale the number of instances and see the output of a running application.

Goals for this lab:
- Gain a basic understanding of the tooling Kubernetes.

## <a name='start'></a>Use your Kubernetes environment
Make sure you have a Kubernetes cluster available, either by running this in the form of AKS or use the mini cluster. See [Lab 1 - Getting Started](Lab1-GettingStarted.md) if you do not have it installed. 
You can deploy the mini-cluster by right clicking on the icon in the tool bar. 

![tray](images/dockertray.png)

On the Kubernetes tab, check 'Enable Kubernetes' and click 'Apply'.

![dd](images/dockerdesktop.png)

Wait a few minutes until the indicator in the bottom-left of the screen indicates that both Docker and Kubernetes are running.

If you already installed the mini-cluster, please open the tab named 'Reset' and select 'Reset Kubernetes Cluster..' to reset the local mini-cluster to its defaults.

![dd](images/vscode-k8s.png)

Now, in VS Code, open the Kubernetes extension, make sure the cluster named 'docker-desktop' is the current cluster, or right click on it to select it as the current cluster.

## <a name='inspect-cluster'></a>Inspecting the cluster
To interact with the Kubernetes cluster, you will need to use the 'kubectl' tool. This allows you to issue commands and queries to the selected Kubernetes cluster. 

Type the following command to inspect the cluster:

```
kubectl cluster-info
```

This command will show you the where the master node is running. To see the cluster version, use the following command as it will return the client and server version numbers.

```
kubectl version
```

## <a name='nodes'></a>Information about the nodes
A cluster has one or more nodes which are responsible for running the actual pods. To see which nodes are available, we can use the 'describe' command of `kubectl`.

```
kubectl describe nodes
```

Each node is listed with not only the technical details, but also the actual pods running on the specific node.

## <a name='deployment'></a>Deploy an application
When you actually want to run a containerized application inside the cluster you will use a deployment configuration to schedule a Pod.

This describes how your application runs and its configuration as well as validating and managing the health of your pod. 

Start a new deployment using `kubectl` by creating a pod running the busybox container:

```
kubectl create deployment hello-busybox --image=busybox
```

Verify that the deployment is working, by using the describe functionality again, this time by querying the deployments:

```
kubectl describe deployments
```

You will get a listing of all deployments with details. For a quick overview, use the _get_ method.

```
kubectl get deployments
```

Which will output something like below:

```
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
hello-busybox   1/1     1            0           1m
```

