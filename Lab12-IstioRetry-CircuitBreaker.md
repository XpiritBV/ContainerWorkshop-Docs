# Lab 12 Retry and Circuit breaker with Istio

During this lab, you will become familiar with the [Istio](https://istio.io/docs/concepts/what-is-istio/) concepts 'retry' and 'circuit breaker'.

Goals for this lab:
- Gain a **basic** understanding of Istio retry and circuit breaker. To learn why they are useful.
- Understand how the built-in capability to retry HTTP calls can be helpful when calling Services.

## <a name='start'></a>Inspect your Kubernetes environment
We will deploy and call an application using Visual Studio Code. Make sure you installed it, return to [Lab 1 - Getting Started](Lab1-GettingStarted#start.md) if you do not have it installed. Also, make sure you have [this](https://github.com/XpiritBV/ContainerWorkshop2019Docs) repository cloned, so you have a copy of the Kubernetes template files on your machine.


1. If you did not do so already, unzip the file 'istio-1.2.5.zip' in the folder 'resources/lab11'.
2. Install Istio by following the steps from Lab 11 [here](Lab11-Istio.md#deploy-istio)
3. In VS Code, in the terminal, move to the repository directory named 'resources/lab12'

## <a name='deploy-workload'></a> Deploying a workload

It is now time to deploy a workload to the cluster. This time, we will use the tool `istioctl` to modify a regular deployment to become 'Istio-enabled'.
The template file will create a Namespace 'blue', which will not be labeled for automatic sidecar injection.
The Deployment needs to be modified to include an additional container, the 'istio-proxy'.

Modify the regular Kubernetes template by using the `isioctl `

```
..\lab11\istio-1.2.5\bin\istioctl.exe kube-inject --filename 01-CircuitBreaker.yaml  --output 01-CircuitBreaker-mod.yaml
```

Use the following command to deploy the API returning 'blue', the sidecar proxy, together with a Service named 'blue', to expose it to cluster-based consumers and a DestinationRule that restricts the amount of allowed concurrent calls to the Service to 1;

```
kubectl apply -f 01-CircuitBreaker-mod.yaml
```

And select the new 'blue' namespace as the default for this session:

```
kubectl config set-context --current --namespace=blue
```

Instead of using *curl*, we will use the tool *Fortio* to call the Service, as it allows for concurrent calls to be made to the blue Service later.

First, deploy Fortio:
```
kubectl apply -f ..\lab11\istio-1.2.5\samples\httpbin\sample-client\fortio-deploy.yaml
```

Next, get the Pod name;
```
kubectl get pod -n blue

NAME                            READY   STATUS    RESTARTS   AGE
blue-554f964ff8-lm8w7           2/2     Running   0          8m29s
fortio-deploy-cd48fb5db-rvhxw   1/1     Running   0          85s
```
> Note that in your environment, the name of the fortio Pod will be different.

Use the Fortio Pod to call the 'blue' service and verify the output:

```
kubectl exec -it fortio-deploy-cd48fb5db-rvhxw  -c fortio /usr/bin/fortio -- load -curl  http://blue/api/color

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
A single call to the Service works fine.

## <a name='cb'></a>Circuit breaker

The 'Circuit breaker' is a design pattern that helps creating resilient applications. It allows you to write applications that limit the impact of failures, by letting callers to a back-end service know that it is unavailable. By storing information about issues and quickly failing the call, the calling application is saved the wait time and overhead that would otherwise be required to find out. It allows the back-end service to recover without continuously being overloaded by waiting callers.

Remember that the DestinationRule specifies that the Service can only process 1 call at a time.
To trip the Circuit breaker, use the following command to call the service 20 times, using 4 concurrent connections and verify the output:

```
kubectl exec -it fortio-deploy-cd48fb5db-rvhxw  -c fortio /usr/bin/fortio -- load -c 4 -qps 0 -n 20  http://blue/api/color

Fortio 1.3.1 running at 0 queries per second, 2->2 procs, for 20 calls: http://blue/api/color
13:35:33 I httprunner.go:82> Starting http test for http://blue/api/color with 4 threads at -1.0 qps
Starting at max qps with 4 thread(s) [gomax 2] for exactly 20 calls (5 per thread + 0)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 I periodic.go:533> T002 ended after 19.854706ms : 5 calls. qps=251.8294655181497
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 W http_client.go:679> Parsed non ok code 503 (HTTP/1.1 503)
13:35:33 I periodic.go:533> T000 ended after 26.00767ms : 5 calls. qps=192.25097826910292
13:35:33 I periodic.go:533> T001 ended after 26.624777ms : 5 calls. qps=187.79500012338133
13:35:33 I periodic.go:533> T003 ended after 28.038191ms : 5 calls. qps=178.32819528192815
Ended after 28.560397ms : 20 calls. qps=700.27
Aggregated Function Time : count 20 avg 0.0045609072 +/- 0.003741 min 0.00099431 max 0.012436529 sum 0.091218145
# range, mid point, percentile, count
>= 0.00099431 <= 0.001 , 0.000997155 , 5.00, 1
> 0.001 <= 0.002 , 0.0015 , 30.00, 5
> 0.002 <= 0.003 , 0.0025 , 60.00, 6
> 0.003 <= 0.004 , 0.0035 , 65.00, 1
> 0.005 <= 0.006 , 0.0055 , 70.00, 1
> 0.007 <= 0.008 , 0.0075 , 75.00, 1
> 0.008 <= 0.009 , 0.0085 , 85.00, 2
> 0.011 <= 0.012 , 0.0115 , 95.00, 2
> 0.012 <= 0.0124365 , 0.0122183 , 100.00, 1
# target 50% 0.00266667
# target 75% 0.008
# target 90% 0.0115
# target 99% 0.0123492
# target 99.9% 0.0124278
Sockets used: 11 (for perfect keepalive, would be 4)
Code 200 : 12 (60.0 %)
Code 503 : 8 (40.0 %)
Response Header Sizes : count 20 avg 145.8 +/- 119 min 0 max 243 sum 2916
Response Body/Total Sizes : count 20 avg 278.2 +/- 25.96 min 257 max 310 sum 5564
All done 20 calls (plus 0 warmup) 4.561 ms avg, 700.3 qps
```

In the output, you should see that around 40% of the calls have failed. This is not exactly what we expected; around 75% or 3 out of 4 concurrent calls should fail. This is caused by the fact that Istio allows some leeway.

### Cleaning up

Delete the namespace 'blue'.

```
kubectl delete ns blue
```

## <a name='retry'></a>Retry

Now it's time to have a look at how Istio can help your services to retry calls on transient errors. This is useful for when there is a temporary issue in the called system. For example, it can make sense to retry a web request, if there was a temporary issue with the web server.


### Deploy a workload.

To demonstrate the retry behavior, deploy the first template:

```
kubectl apply -f 02-NoRetry.yaml
```

Select the new 'buggygreen' namespace as the default for this session:

```
kubectl config set-context --current --namespace=buggygreen
```

You have deployed two Pods, exposed by one Service. One of the Pods has an issue; 25% of all web requests made to the API will fail.

### Deploy the Fortio test tool

Deploy the Fortio Pod:

```
kubectl apply -f 03-Fortio.yaml
```

Make a note of the fortio Pod name, it should resemble this: `fortio-deploy-cd48fb5db-nh5np`

```
kubectl get pod

NAME                            READY   STATUS    RESTARTS   AGE
blue-84cf4bd954-58sjf           2/2     Running   0          1m
fortio-deploy-cd48fb5db-nh5np   2/2     Running   0          1m
green-7d9597d457-7dkhm          2/2     Running   0          1m
```

Make 20 calls to the 'buggygreen' service, by using Fortio. Replace the Pod name in the command, with the value you noted earlier.

```
kubectl exec -it fortio-deploy-cd48fb5db-nh5np -c fortio /usr/bin/fortio -- load -c 4 -qps 0 -n 20 http://buggygreen/api/color

Fortio 1.3.1 running at 0 queries per second, 2->2 procs, for 20 calls: http://buggygreen/api/color
12:20:28 I httprunner.go:82> Starting http test for http://buggygreen/api/color with 4 threads at -1.0 qps
Starting at max qps with 4 thread(s) [gomax 2] for exactly 20 calls (5 per thread + 0)
12:20:28 I periodic.go:533> T002 ended after 31.074391ms : 5 calls. qps=160.90419921664756
12:20:28 W http_client.go:679> Parsed non ok code 502 (HTTP/1.1 502)
12:20:28 I periodic.go:533> T000 ended after 36.212906ms : 5 calls. qps=138.0723215088013
12:20:28 I periodic.go:533> T001 ended after 45.639533ms : 5 calls. qps=109.55414464911374
12:20:28 I periodic.go:533> T003 ended after 45.671133ms : 5 calls. qps=109.47834379322273
Ended after 45.686033ms : 20 calls. qps=437.77
Aggregated Function Time : count 20 avg 0.0078262177 +/- 0.005031 min 0.001900605 max 0.023257468 sum 0.156524355
# range, mid point, percentile, count
>= 0.00190061 <= 0.002 , 0.0019503 , 5.00, 1
> 0.002 <= 0.003 , 0.0025 , 15.00, 2
> 0.003 <= 0.004 , 0.0035 , 20.00, 1
> 0.004 <= 0.005 , 0.0045 , 35.00, 3
> 0.005 <= 0.006 , 0.0055 , 40.00, 1
> 0.006 <= 0.007 , 0.0065 , 45.00, 1
> 0.007 <= 0.008 , 0.0075 , 60.00, 3
> 0.008 <= 0.009 , 0.0085 , 80.00, 4
> 0.011 <= 0.012 , 0.0115 , 85.00, 1
> 0.014 <= 0.016 , 0.015 , 95.00, 2
> 0.02 <= 0.0232575 , 0.0216287 , 100.00, 1
# target 50% 0.00733333
# target 75% 0.00875
# target 90% 0.015
# target 99% 0.022606
# target 99.9% 0.0231923
Sockets used: 5 (for perfect keepalive, would be 4)
Code 200 : 17 (85.0 %)
Code 502 : 3 (15.0 %)
Response Header Sizes : count 20 avg 165.35 +/- 37.93 min 0 max 175 sum 3307
Response Body/Total Sizes : count 20 avg 191.05 +/- 11.96 min 187 max 243 sum 3821
All done 20 calls (plus 0 warmup) 7.826 ms avg, 437.8 qps

```
In the output generated by Fortio, you should see that around 15% of the calls to the Service 'buggygreen' are failing. This is because the 'buggy' Pod is configured to return a Server Error (HTTP Status code 503) for 25% of all incoming requests. Istio is balancing the load across the 'blue' and 'buggy' Pods equally. Therefore, around half of 25% (= 12.5%) of all calls to the Service will fail.
In real life, this can be compared with the deployment of a bug inside a new software version which causes intermittent failures. 

Istio can help you with such issues, by automatically retrying HTTP calls upon failures.

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
kubectl exec -n bluegreen -it fortio-deploy-cd48fb5db-nh5np -c fortio /usr/bin/fortio -- load -c 4 -qps 0 -n 20 http://buggygreen/api/color
Fortio 1.3.1 running at 0 queries per second, 2->2 procs, for 20 calls: http://buggygreen/api/color
12:20:40 I httprunner.go:82> Starting http test for http://buggygreen/api/color with 4 threads at -1.0 qps
Starting at max qps with 4 thread(s) [gomax 2] for exactly 20 calls (5 per thread + 0)
12:20:40 I periodic.go:533> T003 ended after 17.021449ms : 5 calls. qps=293.74702470982345
12:20:40 I periodic.go:533> T002 ended after 19.253156ms : 5 calls. qps=259.6976828110674
12:20:40 I periodic.go:533> T001 ended after 35.054401ms : 5 calls. qps=142.63544255113646
12:20:40 I periodic.go:533> T000 ended after 63.188583ms : 5 calls. qps=79.12821846313597
Ended after 63.321284ms : 20 calls. qps=315.85
Aggregated Function Time : count 20 avg 0.0066840194 +/- 0.007733 min 0.001303603 max 0.026570978 sum 0.133680388
# range, mid point, percentile, count
>= 0.0013036 <= 0.002 , 0.0016518 , 30.00, 6
> 0.002 <= 0.003 , 0.0025 , 60.00, 6
> 0.003 <= 0.004 , 0.0035 , 65.00, 1
> 0.005 <= 0.006 , 0.0055 , 70.00, 1
> 0.006 <= 0.007 , 0.0065 , 80.00, 2
> 0.018 <= 0.02 , 0.019 , 90.00, 2
> 0.02 <= 0.025 , 0.0225 , 95.00, 1
> 0.025 <= 0.026571 , 0.0257855 , 100.00, 1
# target 50% 0.00266667
# target 75% 0.0065
# target 90% 0.02
# target 99% 0.0262568
# target 99.9% 0.0265396
Sockets used: 4 (for perfect keepalive, would be 4)
Code 200 : 20 (100.0 %)
Response Header Sizes : count 20 avg 174.2 +/- 0.4 min 174 max 175 sum 3484
Response Body/Total Sizes : count 20 avg 188.5 +/- 0.7416 min 187 max 189 sum 3770
All done 20 calls (plus 0 warmup) 6.684 ms avg, 315.8 qps
```

> Note that in real life, retrying HTTP calls could lead to issues, when processing write-operations. A call may have been successfully processed, but failed due to a network glitch while sending the response. Processing the same write operation multiple times, could lead to data corruption. Build your software in such a way, that it is able to deal with duplicate requests before enabling the retry feature.

## <a name='clean'></a>Cleaning up

Delete the namespace 'buggygreen' to clean your workspace.

```
kubectl delete ns buggygreen
```

Please visit [Cleaning up](Lab11-Istio#clean) from Lab 11 to remove Istio, if you are not continuing to Lab 13.