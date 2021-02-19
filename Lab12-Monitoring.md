# Lab 12 - Monitoring

During this lab you will use Azure Application Insights and instrument the web application and the Web API to collect telemetry, and logging information. Also, you are going to review the existing implementation of the structured logging and health endpoints. Finally, you will introduce an actual bug and monitor the behavior of the application, and fix the bug afterwards.

Goals for this lab:
- [Create an Application Insights resource](#appinsights)
- [Configure the web application and Web API to gather telemetry and monitoring data](#configure)
- [Add health endpointss](#health)
- [Check readiness and liveliness in Kubernetes cluster](#readiness)
- [Add structured logging](#logging)
- [Introduce, find and fix a bug](#bug)
- [Monitoring with Istio](#istio)

## <a name='appinsights'></a>Create an Application Insights resource

Go to the Azure portal and create a new Application Insights resource in the existing resource group `ContainerWorkshop`. Give it a name such as `ContainerWorkshopAppInsights`. Once created go to the overview and take note of the Application Insights instrumentation key.

Currently, you cannot [easily](https://docs.microsoft.com/en-us/cli/azure/ext/application-insights/monitor/app-insights?view=azure-cli-latest) create the AppInsights resource from the Azure CLI. It is possible to use Azure Resource Management (ARM templates) to automate the provisioning.

## <a name='configure'></a>Configure gathering of telemetry and monitoring data

Open Visual Studio and the solution for the retro gaming application. We need to specify the AppInsights instrumentation key from the previous exercise in the right places. Open the `Startup.cs` file and locate the `ConfigureTelemetry` method. The implementation adds the required services for AppInsights to start collecting telemetry. Find the location from which the instrumentation key is read.

> ##### Questions
>
> Where is the instrumentation key read from?
> Is the key to be considered a secret?
> What would be a good place to specify the key?

Go to the place where you think the instrumentation key should be located and specify it there.

 Depending on the place you chose, use the following syntax:
```json
# appsettings.json (or secrets.json)
  "ApplicationInsights": {
    "InstrumentationKey": "aadb6c95-1234-fcab-bbd3-830bb9473d5a"
  }
```
```yaml
# docker-compose file
ApplicationInsights__InstrumentationKey=aadb6c95-1234-fcab-bbd3-830bb9473d5a
```
```yaml
# Kubernetes deployment manifest
- name: ApplicationInsights__InstrumentationKey
  value: aadb6c95-1234-fcab-bbd3-830bb9473d5a
```
```
# KeyVault secret
ApplicationInsights--InstrumentationKey
```
Repeat this for the Web API project.

Redeploy the solution. If you made changes to files, you will have to commit the code and build and release with the pipelines. If you did not change the code, it might be enough to create only a new release.

Open a browser and navigate to the web application. Refresh the page a number of times. Next, visit the AppInsights resource in the Azure portal again and go to the Application Map. View the statistics there. Also view the Live Metrics and make another set of requests. Observe the behavior of the application under these normal circumstances. You might want to look at the Kubernetes dashboard as well to get a complete impression of how the application behaves.

## <a name='health'></a>Add health endpoints

Being able to monitor the health of your application is important, both from an observability perspective, but also for the container orchestrator. You can easily add health endpoints to your solution.

First, add a reference to the NuGet package `Microsoft.Extensions.Diagnostics.HealthChecks`. Next, open the `Startup.cs` file and look for the calls to `ConfigureTelemetry` and `ConfigureSecurity`. Add a new call with a similar signature `ConfigureHealth`. 
Implement the configuration of health as follows:
```c#
private void ConfigureHealth(IServiceCollection services)
{
   services.AddHealthChecks();

   // Uncomment next two lines for self-host healthchecks UI
   //services.AddHealthChecksUI()
   //    .AddSqliteStorage($"Data Source=sqlite.db");
}
```

This method registers the required services for health monitoring in ASP.NET Core. 

Next, go to the `Configure` method in `Startup` and find to the call to `app.UseEndpoints`. Add a new mapping for the health endpoint, that will be reachable from the relative route `/ping`. 

```c#
app.UseEndpoints(endpoints =>
{
   endpoints.MapHealthChecks("/ping", new HealthCheckOptions() { Predicate = _ => false });
```

You can try the health endpoint by navigating to the correct URL [when running your Docker composition locally: [https://localhost:44369/ping](https://localhost:44369/ping)

## <a name='readiness'></a>Readiness and liveliness

One step beyond a simple health endpoint for availability is using health endpoint that report readiness and liveliness. A service can indicate that it is ready to receive incoming requests and also whether it is still lively enough to continue operating. This information is used by the container orchestrator to start routing traffic to a container or pod, and to terminate and recycle a malfunctioning container that is no longer lively. 

Add two new endpoints to the Leaderboard Web API inside the `Configure` method like before.
```C#
endpoints.MapHealthChecks("/health/ready",
   new HealthCheckOptions()
   {
      Predicate = reg => reg.Tags.Contains("ready"),
      ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
   })
   .RequireHost($"*:{Configuration["ManagementPort"]}");

endpoints.MapHealthChecks("/health/lively",
   new HealthCheckOptions()
   {
      Predicate = _ => true,
      ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
   })
.RequireHost($"*:{Configuration["ManagementPort"]}");
```
The code shows that the two new endpoints will only be available for traffic coming from the management port. Also, the `lively` endpoint will run all health checks, whereas the `ready` endpoint will only run those tagged as `ready`.

To indicate the management port at `8080`, add an environment variable for `ASPNETCORE_MANAGEMENTPORT` to both your `docker-compose.override.yml` file and the deployment manifest. Also, make sure the Kestrel web server for the Web API is also hosting on that same port.
```yaml
# docker-compose.override.yml
- ASPNETCORE_URLS=https://+:443;http://+:80;http://+:8080
- ASPNETCORE_MANAGEMENTPORT=8080
```
```yaml
# deployment manifest
env:
  # existing definitions
- name: ASPNETCORE_MANAGEMENTPORT
   value: "8080"
- name: ASPNETCORE_URLS
   value: http://+:80;http://+:8080
ports:
- containerPort: 80
- containerPort: 8080
- containerPort: 443
```
Finally, you can add a Docker container in your Docker Compose file that offers a health checks user interface:
```yaml
  healthcheckui:
    image: xabarilcoding/healthchecksui:latest
    environment:
      - HealthChecksUI:HealthChecks:0:Name=Readiness checks
      - HealthChecksUI:HealthChecks:0:Uri=http://leaderboardwebapi:8080/health/ready
      - HealthChecksUI:HealthChecks:1:Name=Liveliness checks
      - HealthChecksUI:HealthChecks:1:Uri=http://leaderboardwebapi:8080/health/lively
    ports:
      - 5000:80
    networks:
      - backend
```
Start your composition and navigate to the [http://localhost:5000/healthchecks-ui](http://localhost:5000/healthchecks-ui). You should see a website similar to this:

![](/images/HealthChecksUI.png)
This will help you get quick insights into your health endpoints for development purposes.

Notice how we have not exposed the management ports to outside of the composition or cluster. It can only be reached from within the local cluster network and can therefore be considered safe. It does not show sensitive information, but should not be exposed nevertheless.

Your Kubernetes cluster can use the two health endpoints for readiness and liveliness to know when to use a new pod or when to recycle it. In your manifest change the deployment definition for your Web API to use both ready and lively endpoints:
```yaml
containers:
- name: leaderboardwebapi
   terminationMessagePath: "/tmp/leaderboardwebapi-log"
   image: <your-registry>.azurecr.io/leaderboardwebapi:latest
   imagePullPolicy: Always
   readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
      initialDelaySeconds: 90
      periodSeconds: 10
      timeoutSeconds: 20
      failureThreshold: 5
   livenessProbe:
      httpGet:
        path: /health/lively
        port: 8080
      initialDelaySeconds: 90
      periodSeconds: 10
      timeoutSeconds: 20
      failureThreshold: 3
```

Redeploy your solution with the changed manifest file. Watch how the cluster will wait until the container of the web API indicates ready before it is marked as healthy.
![](images/readiness.png)
![](images/readinessDetail.png)

## <a name='logging'></a>Add structured logging
For the structured (or semantic) logging, you will implement a minimal set of code. Find the constructor of the `LeaderboardController` and add an additional argument:

```c#
public LeaderboardController(LeaderboardContext context, ILoggerFactory loggerFactory)
```
Introduce a field called `logger` of type `ILogger<LeaderboardController>`:

```c#
private readonly ILogger<LeaderboardController> logger;
```

and initialize it in the constructor:

```c#
this.logger = loggerFactory.CreateLogger<LeaderboardController>();
```

In the controller `Get` action, call the `LogInformation` method to log at the Information level:

```c#
logger.LogWarning("Retrieving score list with a limit of {SearchLimit}.", limit);
```

Notice how the name of the log message format does not resemble the name of the argument. For semantic logging, it is not necessary to match by name. Instead, the matching is done positionally.

Two main log providers know how to deal with semantic logging: Azure Application Insights and SeriLog. We will be using AppInsights again.

Finally, open the `Program.cs` file and go to the `CreateHostBuilder` method. Examine the `ConfigureLogging` to see how logging to Application Insights is configured:

```c#
.ConfigureLogging((context, builder) =>
{
   builder.AddApplicationInsights(options =>
   {
      options.IncludeScopes = true;
      options.TrackExceptionsAsExceptionTelemetry = true;
   });
})
```

Go to the Azure Portal and open the blade for the AppInsights resource you created. Look at the following:
- **Application Map** 
- **Live Metrics:** There should be two clients for each web API connected)
- **Log Analytics:** Run a `traces` query for the structured logging.

to see the effects of the logging and telemetry information reaching Application Insights.

## <a name='bug'></a>Introduce, find and fix a bug

With monitoring in place, you can now start to do a full outer cycle to your production cluster from your local development environment.

Create a bug by adding the following method to the `LeaderboardController` class:

```c#
private void AnalyzeLimit(int limit)
{
   // This is a demo bug, supposedly "hard" to find
   do
   {
         limit--;
   }
   while (limit != 0);
}
```
and calling it at the beginning of the `Get` method:
```c#
public async Task<ActionResult<IEnumerable<HighScore>>> Get(int limit = 10)
{
   logger.LogWarning("Retrieving score list with a limit of {SearchLimit}.", limit);
   AnalyzeLimit(limit);
```

Next, we will add some code to make the web front end use the `limit` parameter and be more resilient. 

Go to the `GamingWebApp` project and inspect the `ConfigureTypedClients` method. It will register a typed client that contains an `HttpClient` wrapped with Polly policies for Retry and Timeout. The policy will wait at most 1500 milliseconds and do 3 retries. You can use a such a client to make an HTTP call with these policies by injecting an object of the `ILeaderboardClient` type into the object that uses it. In our case this will be the `IndexModel` class:

```c#
private readonly ILeaderboardClient proxy;

public IndexModel(ILeaderboardClient proxy, IOptionsSnapshot<LeaderboardApiOptions> options,
   ILoggerFactory loggerFactory)
{
   this.logger = loggerFactory.CreateLogger<IndexModel>();
   this.options = options;
   this.proxy = proxy;
}
```

Since our web API now exposes a limit parameter in the `GET` method to `/api/leaderboard`, the interface definition for the proxy changes. Change the signature of the proxy interface `ILeaderboard` in the `Proxy` folder to include the limit parameter:
```c#
public interface ILeaderboardClient
{
   [Get("/api/leaderboard")]
   Task<IEnumerable<HighScore>> GetHighScores(int limit = 10);
}
```

For testing purposes and to exploit the bug, add the option for the index page to specific a querystring parameter called `limit`, allowing the browser to use  [http://localhost/?limit=0](http://localhost/?limit=0). 

Go to `Index.cshtml.cs` in your Gaming Web App and change the code for the try/catch block to be:
```c#
try
{
   // Using injected typed HTTP client instead of locally created proxy
   int limit;
   Scores = await proxy.GetHighScores(
         Int32.TryParse(Request.Query["limit"], out limit) ? limit : 10
   ).ConfigureAwait(false);
}
catch
```

Compile your changes locally. If it compiles, run the Docker composition first to see how the website is behaving. 
Check that there is a bug by visiting the home page of the web application at [http://localhost/?limit=0](http://localhost/?limit=0). The `limit` value of `0` will be passed through the querystring to the proxy class, which will add it to the call to the web API, ending up in the `Get` method of the `LeaderboardController`.

If all is correct, the page should display after a few seconds without any highscores.

Next, perform a build and release into your cluster. After a successful deployment, check how the website is behaving for the same URL. 
You might want to create some load on the cluster from PowerShell to see some bigger effect in Application Insights:

```PowerShell
for ($i = 0 ; $i -lt 100; $i++)
{
   Invoke-WebRequest -uri http://<yourclusterip>/?limit=0
}
```

Use the Kubernetes dashboard, the telemetry data and the logging information to investigate what is happening. Also, trace back from the current Docker images running in production to the commits that were made in this particular release.

Fix the bug (by removing the code you added previously) by following a proper DevOps workflow:

- Create a bug work item
- Create a branch
- Fix the bug by making code changes and commiting
- Make a pull request to master
- Perform a build and release to your Kubernetes cluster
- Verify everything works and close the work item

## <a name='istio'></a>Monitoring Kubernetes pods with Istio
In this chapter we will use Istio addons to visualize your Kubernetes environment.

### Getting started
1. Install Istio by following the steps outlined in chapter 'Deploying Istio' of [Lab 10 - Working with Istio on Kubernetes](Lab10-Istio.md).
2. Deploy an Istio enabled **buggy** workload. This is a .NET API that returns a color string) as described in chapter 'Deploying a workload' of [Lab 11 Retry and Circuit breaker with Istio](Lab11-IstioRetry-CircuitBreaker). Stop after deploying Fortio and return here.
3. Generate some traffic to the workload, by running `fortio`:
   ```
   kubectl exec -it fortio-deploy-6dc9b4d7d9-p68rg -- fortio load -c 100 -qps 10  http://blue/api/color
   ```

### Prometheus
Prometheus is an open source monitoring system and time series database. You can use Prometheus with Istio to record metrics that track the health of Istio and of applications within the service mesh. You can visualize metrics using tools like Grafana and Kiali.

Prometheus will gather telemetry from the platform and store it in a database. We can query the data using a built-in web portal. 

First, deploy Prometheus to Istio:

```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/prometheus.yaml
```

Create a port forwarding from your machine to the cluster using `istioctl dashboard` and passing the name `prometheus`. This command will block the terminal, until you press `Ctrl+C`:

```
istioctl dashboard prometheus
```

In your browser, navigate to http://localhost:9090

![](images/prometheus01.png)

Click on the 'Graph' tab and execute the query 'istio_requests_total'. Depending on how much load you generated with Fortio, you should see some statistics about the total amount of requests processed by Istio. Try to find out why you can see two lines, while we are running just a single Pod. (It's not the sidecar...)

Run the `fortio` tool a couple of times in a different terminal, to generate some more data. 

Let's zoom in on the failed responses returned by the Service named 'blue', by filtering out the successful calls. Run the following query:

```
istio_requests_total{destination_service=~"blue.*", response_code="503"}
```
You should see one line that indicates the total amount of failed requests. It should look similar to the image below, try to zoom in a little if needed, by changing the time scale to 15m:

![](images/prometheus02.png)

Press `Ctrl+C` to stop the `istioctl` port forward.

### Grafana

Grafana is an open source monitoring solution that can be used to configure dashboards for Istio. You can use Grafana to monitor the health of Istio and of applications within the service mesh. Grafana will query the data that was gathered by Prometheus.

Generate some more test data:
```
kubectl exec -it fortio-deploy-6dc9b4d7d9-p68rg -- fortio load -c 100 -qps 10  http://blue/api/color
```

Add the Grafana (visualization tooling) addon to Istio:

```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/grafana.yaml
```

Just like Prometheus, Grafana comes with a built-in Portal. Create a port forward to Grafana by using the `istioctl dashboard` command again, but passing `grafana` as the name:
```
istioctl dashboard grafana
```

In your browser, navigate to the Grafana portal. We will open the 'Data sources' tab, to check if the connection to Prometheus works:

```
http://localhost:3000/datasources
```
![](images/grafana01.png)

Let's see if we can query the request totals again:
Navigate to the 'Explore' tab:

```
http://localhost:3000/explore
```

Enter the following query:

```
istio_requests_total{destination_service=~"blue.*", response_code="503"}
```

It should show the same chart, as Prometheus:
![](images/grafana02.png)

The added benefit of Grafana is that you can combine data from multiple data sources. Another great thing about the Grafana addon is that it comes with a couple of built-in Istio dashboards. Also, Grafana has an auto-refresh option, so it will regularly update the charts for you.
(Grafana charts also look a lot nicer.)

In your browser, navigate to:
```
http://localhost:3000/dashboards
```
It should show you a 'folder' named Istio.

With your mouse, hover over the folder and click on 'Go to folder'

![](images/grafana03.png)

Select the dashboard named 'Istio Service Dashboard' and open the tab 'Service Workloads'. It will show information about incoming requests. Use this dashboard to see current usage of your Services in near-real time.

![](images/grafana05.png)

Go back and open the dashboard named 'Istio Performance Dashboard'. It will show information about Istio's resource consumption. Return here to investigate performance issues.

![](images/grafana04.png)

Look around in the Istio dashboards for a few minutes. See if you can find more useful charts.

Break the port forward by pressing `Ctrl+C`.

## Wrapup

In this lab you have added the first monitoring support to the application and Web API. You used Application Insights to capture telemetry of multiple Azure resources and introduced semantic logging to create rich log information.

Continue with [Lab 13 - Azure DevOps Pipelines](Lab13-AzDOPipelines.md).