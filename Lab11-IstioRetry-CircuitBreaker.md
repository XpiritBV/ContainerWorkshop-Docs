# Lab 13 Retry and Circuit breaker with Istio

During this lab, you will become familiar with the [Istio](https://istio.io/docs/concepts/what-is-istio/) concepts 'retry' and 'circuit breaker'.

Goals for this lab:
- Gain a **basic** understanding of Istio retry and circuit breaker. To learn why they are useful.
- Understand how the built-in capability to retry HTTP calls can be helpful when calling Services.

## Prerequisites
Make sure you have completed [Lab 1 - Getting Started](Lab1-GettingStarted.md#6). Doublecheck that you have completed chapter 'Create a Kubernetes cluster'
Also, make sure you have installed Istio as described in [Lab 12 - Working with Istio on Kubernetes](Lab12-Istio.md##deploy-istio) chapter 'Deploying Istio'. 

>Make sure to complete the entire chapter.

## Getting started
![](images/kubernetes01.png)
Launch VS Code, open the Kubernetes extension, make sure the cluster named 'docker-desktop' or 'ContainerWorkshopCluster-admin' is the current cluster, or right click on it to select it as the current cluster.
Click on the 'Install dependencies' button if needed.

> Regularly switch to VS Code to examine the resources of your cluster. It will help you understand this lab.

Also, in the terminal, change directories to the Docs repository directory named 'resources/lab13':
```
user@machine:/mnt/c/Sources/ContainerWorkshop-Docs/resources/lab13/$ 
```

## Important

The local Istio tooling uses a Linux based executable. Make sure to run this lab on:
- WSL on Windows (like Ubuntu)
- Azure Cloud Shell (in the Terminal) on Windows 
- Any Linux distro that supports the `az` CLI
- Mac also works fine

## <a name='deploy-workload'></a> Deploying a workload

In the previous lab, we deployed Istio to Kubernetes by using `istioctl`. It can do more! It is now time to deploy a workload to the cluster. We will use the tool `istioctl` to modify a regular deployment to become 'Istio-enabled'.
The template file will create a Namespace 'blue', which will not be labeled for automatic sidecar injection.
The Deployment needs to be modified to include an additional container, the 'istio-proxy'.

Examine the file '01-CircuitBreaker.yaml', if you have completed Lab 10 and 12, it should look very familiar. Except maybe for the DestinationRule `trafficPolicy`, but we will come back to that.
The file creates a Deployment for a Pod with a container based on the 'blue' image. It exposes the Pod using a Service resource. Finally, it creates an Istio DeploymentRule as a proxy around the Service.

### Modify an existing Kubernetes template file

To enable Istio sidecar injection for the Deployment, we can modify the regular Kubernetes template by using `isioctl`:

```
istioctl kube-inject --filename 01-CircuitBreaker.yaml  --output 01-CircuitBreaker-mod.yaml
```
This creates a copy (`01-CircuitBreaker-mod.yaml`) of the file (`01-CircuitBreaker.yaml`), with additional Istio resources.

Go ahead and examine that file. It has become quite a bit larger. See if you can find the sidecar container based on the 'docker.io/istio/proxyv2' image.

### Deploy

Use the following command to deploy the API returning 'blue', the sidecar proxy, together with a Service named 'blue', to expose it to cluster-based consumers and a DestinationRule that restricts the amount of allowed concurrent calls to the Service to 1;

```
kubectl apply -f 01-CircuitBreaker-mod.yaml
```

And select the new 'blue' namespace as the default for this session:

```
kubectl config set-context --current --namespace=blue
```

Instead of using *curl*, we will use the tool *Fortio* to call the Service, as it allows for concurrent calls to be made to the blue Service later. Read more about the [Fortio tool here](https://github.com/fortio/fortio). Fortio will run as a CLI, which you can use to perform load tests on a Web Server.

Deploy Fortio:
```
kubectl apply -f ../lab12/istio-1.8.2/samples/httpbin/sample-client/fortio-deploy.yaml

service/fortio created
deployment.apps/fortio-deploy created
```
> Note that your version of Istio may be different. Change the path accordingly.

Next, get the Pod name;
```
kubectl get pod -n blue

NAME                            READY   STATUS    RESTARTS   AGE
blue-554f964ff8-lm8w7           2/2     Running   0          8m29s
fortio-deploy-576dbdfbc4-f6nfh   1/1     Running   0          85s
```
> Note that in your environment, the name of the fortio Pod will be different.

Use the Fortio web load testing Pod to call the 'blue' Service once by using its name, and verify the output:

```
kubectl exec -it fortio-deploy-576dbdfbc4-f6nfh -- fortio load -curl http://blue/api/color

HTTP/1.1 200 OK
date: Mon, 23 Sep 2019 13:29:54 GMT
content-type: text/plain; charset=utf-8
server: istio-envoy
x-envoy-upstream-service-time: 178
x-envoy-decorator-operation: blue.blue.svc.cluster.local:80/*
transfer-encoding: chunked

4
blue
0
```
You can see that a single call to the Service works fine.

## <a name='cb'></a>Circuit breaker

The 'Circuit breaker' is a design pattern that helps creating resilient applications. It allows you to write applications that limit the impact of failures, by letting callers to a back-end service know that it is unavailable. By storing information about issues and quickly failing the call, the calling application is saved the wait time and overhead that would otherwise be required to find out. It allows the back-end service to recover without continuously being overloaded by waiting callers.

Remember that the DestinationRule specifies that the Service can only process 1 call at a time.
To trip the Circuit breaker, use the following command to call the service concurrently and verify the output:

```
kubectl exec -it fortio-deploy-576dbdfbc4-f6nfh -- fortio load http://blue/api/color

Fortio 1.11.3 running at 8 queries per second, 2->2 procs, for 5s: http://blue/api/color
13:59:00 I httprunner.go:82> Starting http test for http://blue/api/color with 4 threads at 8.0 qps
Starting at 8 qps with 4 thread(s) [gomax 2] for 5s : 10 calls each (total 40)
13:59:00 W http_client.go:693> Parsed non ok code 503 (HTTP/1.1 503)
13:59:00 W http_client.go:693> Parsed non ok code 503 (HTTP/1.1 503)
..
13:59:05 I periodic.go:558> T000 ended after 5.0055601s : 10 calls. qps=1.9977784304297934
13:59:05 I periodic.go:558> T001 ended after 5.0056835s : 10 calls. qps=1.997729181239685 
13:59:05 I periodic.go:558> T003 ended after 5.0057639s : 10 calls. qps=1.997697094743122 
13:59:05 W http_client.go:693> Parsed non ok code 503 (HTTP/1.1 503)
13:59:05 I periodic.go:558> T002 ended after 5.0087094s : 10 calls. qps=1.9965222977400128
Ended after 5.008943s : 40 calls. qps=7.9857
Sleep times : count 36 avg 0.55218823 +/- 0.002078 min 0.546221533 max 0.554435755 sum 19.8787762
Aggregated Function Time : count 40 avg 0.0030588875 +/- 0.002051 min 0.0005581 max 0.0078341 sum 0.1223555
# range, mid point, percentile, count
>= 0.0005581 <= 0.001 , 0.00077905 , 5.00, 2
> 0.001 <= 0.002 , 0.0015 , 47.50, 17
> 0.002 <= 0.003 , 0.0025 , 60.00, 5
> 0.003 <= 0.004 , 0.0035 , 72.50, 5
> 0.004 <= 0.005 , 0.0045 , 75.00, 1
> 0.005 <= 0.006 , 0.0055 , 87.50, 5
> 0.006 <= 0.007 , 0.0065 , 92.50, 2
> 0.007 <= 0.0078341 , 0.00741705 , 100.00, 3
# target 50% 0.0022
# target 75% 0.005
# target 90% 0.0065
# target 99% 0.00772289
# target 99.9% 0.00782298
Sockets used: 14 (for perfect keepalive, would be 4)
Jitter: false
Code 200 : 28 (70.0 %)
Code 503 : 12 (30.0 %)
Response Header Sizes : count 40 avg 170.1 +/- 111.4 min 0 max 243 sum 6804
Response Body/Total Sizes : count 40 avg 272.9 +/- 24.29 min 257 max 310 sum 10916
All done 40 calls (plus 4 warmup) 3.059 ms avg, 8.0 qps
```

In the output, you should see that around 30% of the calls have failed with Code 503, which is 'Server Unavailable'. This is not exactly what we expected; around 75% or 3 out of 4 concurrent calls should fail. This is caused by the fact that Istio allows some leeway.

You can see that the Istio sidecar proxy can be used for more than load balancing, it can also be used to protect a legacy resource from too many concurrent clients, by blocking access.

### Cleaning up

Delete the namespace 'blue'.

```
kubectl delete ns blue
```

## <a name='retry'></a>Retry

Now it's time to have a look at how Istio can help clients of your API's by retrying calls on transient errors (like the 503 errors we saw earlier). This is useful for when there is a transient issue in the called system. For example, it can make sense to retry a web request, if there was a temporary issue with the web server, or mabye a dead-lock in its database. Chances are, that another attempt to call the API will work.


### Deploy a workload.

To demonstrate the retry behavior, deploy the first template:

```
kubectl apply -f 02-NoRetry.yaml
```

Select the new 'buggygreen' namespace as the default for this session:

```
kubectl config set-context --current --namespace=buggygreen
```

You have deployed two Pods; one named 'green' and one named 'buggy'. The Pods are exposed by one Service. One of the Pods (guess which one) has an issue; 25% of all web requests made to the API will fail.

### Deploy the Fortio test tool

Deploy the Fortio Pod again:

```
kubectl apply -f ../lab12/istio-1.8.2/samples/httpbin/sample-client/fortio-deploy.yaml
```

Make a note of the fortio Pod name, it should resemble this: `fortio-deploy-576dbdfbc4-284kk`

```
kubectl get pod

NAME                            READY   STATUS    RESTARTS   AGE
blue-84cf4bd954-58sjf           2/2     Running   0          1m
fortio-deploy-576dbdfbc4-284kk   2/2     Running   0          1m
green-7d9597d457-7dkhm          2/2     Running   0          1m
```

Make 20 calls to the 'buggygreen' service, by using Fortio. Replace the Pod name in the command, with the value you noted earlier.

```
kubectl exec -it fortio-deploy-576dbdfbc4-284kk -- fortio load -c 4 -qps 0 -n 20 http://buggygreen/api/color

Defaulting container name to fortio.
Use 'kubectl describe pod/fortio-deploy-576dbdfbc4-284kk -n buggygreen' to see all of the containers in this pod.
Fortio 1.11.3 running at 0 queries per second, 2->2 procs, for 20 calls: http://buggygreen/api/color
14:19:58 I httprunner.go:82> Starting http test for http://buggygreen/api/color with 4 threads at -1.0 qps
Starting at max qps with 4 thread(s) [gomax 2] for exactly 20 calls (5 per thread + 0)
14:19:58 W http_client.go:693> Parsed non ok code 502 (HTTP/1.1 502)
14:19:58 I periodic.go:558> T002 ended after 47.3599ms : 5 calls. qps=105.57454724355414
14:19:58 W http_client.go:693> Parsed non ok code 502 (HTTP/1.1 502)
14:19:58 I periodic.go:558> T001 ended after 65.1698ms : 5 calls. qps=76.72265374452584
14:19:58 W http_client.go:693> Parsed non ok code 502 (HTTP/1.1 502)
14:19:58 I periodic.go:558> T000 ended after 68.6ms : 5 calls. qps=72.8862973760933
14:19:58 I periodic.go:558> T003 ended after 73.5768ms : 5 calls. qps=67.95620358591296
Ended after 73.612ms : 20 calls. qps=271.69
Aggregated Function Time : count 20 avg 0.01266718 +/- 0.0107 min 0.0024216 max 0.0419618 sum 0.2533436
# range, mid point, percentile, count
>= 0.0024216 <= 0.003 , 0.0027108 , 15.00, 3
> 0.005 <= 0.006 , 0.0055 , 35.00, 4
> 0.006 <= 0.007 , 0.0065 , 40.00, 1
> 0.007 <= 0.008 , 0.0075 , 50.00, 2
> 0.008 <= 0.009 , 0.0085 , 55.00, 1
> 0.009 <= 0.01 , 0.0095 , 60.00, 1
> 0.01 <= 0.011 , 0.0105 , 65.00, 1
> 0.014 <= 0.016 , 0.015 , 75.00, 2
> 0.016 <= 0.018 , 0.017 , 80.00, 1
> 0.02 <= 0.025 , 0.0225 , 85.00, 1
> 0.03 <= 0.035 , 0.0325 , 95.00, 2
> 0.04 <= 0.0419618 , 0.0409809 , 100.00, 1
# target 50% 0.008
# target 75% 0.016
# target 90% 0.0325
# target 99% 0.0415694
# target 99.9% 0.0419226
Sockets used: 6 (for perfect keepalive, would be 4)
Jitter: false
Code 200 : 17 (85.0 %)
Code 502 : 3 (15.0 %)
Response Header Sizes : count 20 avg 148.15 +/- 62.24 min 0 max 175 sum 2963
Response Body/Total Sizes : count 20 avg 199.7 +/- 26.47 min 187 max 263 sum 3994
All done 20 calls (plus 0 warmup) 12.667 ms avg, 271.7 qps

```
In the output generated by Fortio, you should see that around 15% of the calls to the Service 'buggygreen' are failing. This is because the 'buggy' Pod is configured to return a Server Error (HTTP Status code 503) for 25% of all incoming requests. Istio is evenly balancing the load across the 'blue' and 'buggy' Pods. Therefore, around half of 25% (= 12.5%) of all calls to the Service will fail.
In real life, this can be compared with the deployment of a bug inside a new software version which causes intermittent failures. 

If you cannot fix the software itself, Istio can help you mitigate such issues, by automatically retrying HTTP calls upon failures for you.
Let's see how that works.

### Configure the Virtual Service for automatic retry.

Reconfigure the VirtualService resource (which configures network rules for the Service 'buggygreen'), to automatically perform retries, when incoming HTTP requests fail:

```
kubectl apply -f 04-Retry.yaml
```

Examine the yaml fragment below:

``` yaml
    retries:
      attempts: 40
      perTryTimeout: 1s
      retryOn: gateway-error
```

This configures HTTP retry, whenever a 'gateway error' occurs: retry requests that result in HTTP Status code 502, 503, or 504. Other options can be found on the Envoy Proxy documentation page [here](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#config-http-filters-router-x-envoy-retry-on).

If you now use Fortio to call the Service again, you should see that (around) 100% of the calls are now succeeding:

```
kubectl exec -it fortio-deploy-576dbdfbc4-284kk -- fortio load -c 4 -qps 0 -n 20 http://buggygreen/api/color

Defaulting container name to fortio.
Use 'kubectl describe pod/fortio-deploy-576dbdfbc4-284kk -n buggygreen' to see all of the containers in this pod.
Fortio 1.11.3 running at 0 queries per second, 2->2 procs, for 20 calls: http://buggygreen/api/color
14:22:18 I httprunner.go:82> Starting http test for http://buggygreen/api/color with 4 threads at -1.0 qps
Starting at max qps with 4 thread(s) [gomax 2] for exactly 20 calls (5 per thread + 0)
14:22:18 I periodic.go:558> T001 ended after 94.8375ms : 5 calls. qps=52.72176090681428
14:22:18 I periodic.go:558> T002 ended after 115.1183ms : 5 calls. qps=43.43358093370038
14:22:18 I periodic.go:558> T000 ended after 125.9479ms : 5 calls. qps=39.69895488531369
14:22:18 I periodic.go:558> T003 ended after 158.8812ms : 5 calls. qps=31.47005435507788
Ended after 158.9469ms : 20 calls. qps=125.83
Aggregated Function Time : count 20 avg 0.024706695 +/- 0.02845 min 0.0021345 max 0.1031332 sum 0.4941339
# range, mid point, percentile, count
>= 0.0021345 <= 0.003 , 0.00256725 , 25.00, 5
> 0.005 <= 0.006 , 0.0055 , 30.00, 1
> 0.008 <= 0.009 , 0.0085 , 35.00, 1
> 0.011 <= 0.012 , 0.0115 , 40.00, 1
> 0.012 <= 0.014 , 0.013 , 50.00, 2
> 0.016 <= 0.018 , 0.017 , 55.00, 1
> 0.018 <= 0.02 , 0.019 , 60.00, 1
> 0.02 <= 0.025 , 0.0225 , 65.00, 1
> 0.025 <= 0.03 , 0.0275 , 75.00, 2
> 0.03 <= 0.035 , 0.0325 , 80.00, 1
> 0.04 <= 0.045 , 0.0425 , 90.00, 2
> 0.1 <= 0.103133 , 0.101567 , 100.00, 2
# target 50% 0.014
# target 75% 0.03
# target 90% 0.045
# target 99% 0.10282
# target 99.9% 0.103102
Sockets used: 4 (for perfect keepalive, would be 4)
Jitter: false
Code 200 : 20 (100.0 %)
Response Header Sizes : count 20 avg 174.6 +/- 0.4899 min 174 max 175 sum 3492
Response Body/Total Sizes : count 20 avg 188.6 +/- 0.8 min 187 max 190 sum 3772
All done 20 calls (plus 0 warmup) 24.707 ms avg, 125.8 qps
```

As you can see, all service calls (eventually) resulted in a response with 'Code 200', which is 'OK'.

To get a feeling about how many times the 'buggy' API was really called, we can examine the log output of the proxy container by using `kubectl logs` and provide both the Pod name and the proxy container name:
```
kubectl logs buggy-68f5b98cd4-58fwn istio-proxy

..
[2021-02-05T14:22:18.313Z] "GET /api/color HTTP/1.1" 200 - "-" 0 3 0 0 "-" "fortio.org/fortio-1.11.3" "2d879340-62c2-9067-ba88-7dcb3b88626d" "buggygreen" "127.0.0.1:8080" inbound|8080|| 127.0.0.1:42000 10.1.0.42:8080 10.1.0.43:42232 outbound_.80_.v2_.buggygreen.buggygreen.svc.cluster.local default  
a
```

Run Fortio again a couple of times, to make sure the 'buggy' Pod gets called a few times, and examine the log output to see new responses in the log (since 2 minutes).
```
kubectl exec -it fortio-deploy-576dbdfbc4-284kk -- fortio load -c 4 -qps 0 -n 200 http://buggygreen/api/color

kubectl logs buggy-68f5b98cd4-58fwn istio-proxy --since 2m
```
In the output, you should see both succeeded (200) and failed calls (502).

> Note that in real life, retrying HTTP calls could lead to issues, when processing write-operations. A call may have been successfully processed, but failed due to a network glitch while sending the response. Processing the same write operation multiple times, could lead to data corruption. Build your software in such a way, that it is able to deal with duplicate requests before enabling the retry feature.

## <a name='clean'></a>Cleaning up

Delete the namespace 'buggygreen' to clean your workspace.

```
kubectl delete ns buggygreen
```

## Wrapup

In this lab you experimented with network traffic blocking using Istio, from the command line. You have learned how to protect a legacy resource from being overwhelmed by clients, and how to implement retry behavior on behalf of the client to deal with transient errors.

Continue with [Lab 12 - Monitoring](Lab12-Monitoring.md).
