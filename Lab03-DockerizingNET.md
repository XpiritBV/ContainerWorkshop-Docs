# Lab 3 - Dockerizing a .NET Core application

During this lab you will take an existing application and port it to use Docker containers.

Goals for this lab:
- [Run existing application](#run)
- [Add Docker support to .NET Core application](#add)
- [Run and debug applications from containers](#debug)
- [Build container images](#build)
- [Running SQL Server in a Docker container composition](#sql)

## Prerequisites
Make sure you have completed [Lab 1 - Getting Started](Lab01-GettingStarted.md).

## <a name="run"></a>Run the application
We will start with running the existing ASP.NET Core application from Visual Studio. Make sure you have cloned the Git repository, or return to [Lab 1 - Getting Started](Lab01-GettingStarted.md) to clone it now if you do not have the sources. 

> The completed solution can be found inside the `finished` folder. So if you need to check whether you missed something, feel free to use this as a reference. We will work in the `start` folder in this Lab.

Open the `start` folder inside the repo:

```cmd
cd /workspaces/ContainerWorkshop/start
```

Take your time to navigate the code and familiarize yourself with the various projects in the solution. You should be able to identify these:

- `GamingWebApp`, an ASP.NET MVC Core frontend 
- `LeaderboardWebAPI`, an ASP.NET Core Web API

For now, the SQL Server for Linux container instance is providing the developer backend for data storage. This will be changed later on. Make sure you run the SQL Server as described in [Lab 2 - Running Microsoft SQL Server on Linux](Lab02-Docker101.md#sql).

> ##### Important
> Update the connectionstring in the appsettings.json file in the `LeaderboardWebAPI` folder, to use the local ip address instead of localhost or 127.0.0.1. We will need this later. 

> Find your ip address using this command in your terminal: `ip addr` (Linux/Mac) or `ipconfig` (Win)
> On Linux/Mac, take the ip address of `eth0`.

```json
{
  "ConnectionStrings": {
    "LeaderboardContext": "Server=tcp:<<your-ip-address>>,5433;Database=Leaderboard;User Id=sa;Password=Pass@word;Trusted_Connection=False;"
  }
```

Launch both the GamingWebApp and LeaderboardWebAPI and start the debugger.
- In VS Code, type CTRL+SHIFT+D to show 'Run and Debug'
- In the dropdown, select 'Launch (start WebAPI)'
- Click the 'play' button to launch the Web API
- Wait until it has started
- Next, in the dropdown, select 'Launch (start Frontend)'
- Click the 'play' button to start the Web Frontend

First, navigate to the web site located at http://localhost:5000/. There should be a single highscore listed. Notice what the operating system is that you are currently running on.

Next, navigate to the Web API endpoint at http://localhost:5002/swagger. Experiment with the GET and POST operations that are offered from the Swagger user interface. Try to retrieve the list of high scores, and add a new high score for one of the registered player names.

Make sure you know how this application is implemented. Set breakpoints if necessary and navigate the flow of the application for the home page.

## <a name="add"></a>Add Docker support

### Docker support
Copy the `Dockerfile` files into your project folders:
1. Copy `ContainerWorkshop\resources\lab03\frontend\Dockerfile` to folder `ContainerWorkshop/start/src/GamingWebApp`
2. Copy `ContainerWorkshop\resources\lab03\frontend\Dockerfile` to folder `ContainerWorkshop/start/src/GamingWebApp`

### Orchestrator support
Copy the `docker-compose` files into your solution folder:
1. Copy `ContainerWorkshop\resources\lab03\docker-compose.yml` and `docker-compose.override.yml` to folder 
`ContainerWorkshop/start/src`.

Inspect the contents of the `docker-compose.yml` and `docker-compose.override.yml` files if you haven't already. The compose file specifies which services (containers), volumes (data) and networks (connectivity) need to be created and run. The `override` file is used for local debugging purposes. Ensure that you understand the meaning of the various entries in the YAML files.

### Running the application

- In VS Code, type CRTL+SHIFT+B to display the Build tasks. 
- Run your application by running the `docker compose up` task.
- Launch and attach a debugger, by pressing F5 and choosing container group `start` and container `gamingwebapp`. Select `Yes` when asked if you want to copy the .NET Core debugger into the container.


> If you encounter the error 'The DOCKER_REGISTRY variable is not set. Defaulting to a blank string.', make sure you started Visual Studio as an administrator

> Does the application still work?

Now that the projects are running from a Docker container, the application is not working anymore. You can try to find what is causing the issue, but do not spend too much time to try to fix it. We will do that next.

> Some things to try if you feel like finding the cause:
> - Inspect the running and stopped containers
> - Try to reach the Web API from http://localhost:5002/swagger.
> - Debug the call from the web page to the API by stepping through the code.
> - Verify application settings for each of the projects. 

The `docker-compose.override.yml` file contains port mappings, defining the ports inside the container. However, there is no mapping to the outside yet. Change the composition file to add the port numbers for the `gamingwebapp` and `leaderboardwebapi` to reflect these mappings:
```
leaderboardwebapi:
  ports:
    - "5002:80"
...
gamingwebapp:
  ports:
    - "5000:80"
```

The setting for `LeaderboardWebApi:BaseUrl` should now point to the new endpoint of the Web API with the internal address `http://leaderboardwebapi`.

> You will learn more on networking later on. For now, notice that the URL is not referring to `localhost` but `leaderboardwebapi`, which is the name of the Docker container service as defined in the `docker-compose.yml` file.

> Make sure you use an HTTP endpoint, because hosting an HTTPS endpoint with self-signed certificates in a cluster does not work by default.

Give some thought to where right place to make that change would be, considering that you are now running from Docker containers.
  
> ##### Hint
> Changing the setting in the `appsettings.json` file will work and you could choose to do so for now. It does mean that the setting for running without container will not work anymore. So, what other place can you think of that might work? Use that instead if you know, or just change `appsettings.json`.

In case you thought of changing the setting via environment variables, you can make this change inside of the `docker.override.yml` file.
```
gamingwebapp:
  environment:
    - ASPNETCORE_ENVIRONMENT=Development
    - LeaderboardApiOptions__BaseUrl=http://leaderboardwebapi
```

Make sure you changed the IP address of the connection string in the application settings for the Web API to be your local IP address (of your LAN) instead of `127.0.0.1` or `localhost`. This is a temporary fix.

Start the solution by pressing `F5`. See if it works correctly. Timebox your efforts to try to fix any errors.

> ##### Tip
> If you get error messages indicating that ports are in use, shut down IIS Express from the tray icon. The switch to a Docker environment with the same port numbers created the conflict. From now on we will not be running the application without Docker anymore.

## <a name="sql"></a>Running SQL Server in a Docker container composition

Now that your application is running two projects in Docker containers, you can also run SQL Server in the same composition. This is convenient for isolated development and testing purposes. It eliminates the need to install SQL Server locally and to start the container for SQL Server manually.

Remember that from the Docker CLI you used many environment variables to bootstrap the container instance. Go back to the previous lab to check what these are.

The new container service requires these same environment variables. Add them to the `docker-compose.override.yml` file under a service entry named `sql.data`:

```
  sql.data:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - SA_PASSWORD=Pass@word
      - MSSQL_PID=Developer
      - ACCEPT_EULA=Y
    ports:
      - "1433"
```

> ##### Which additional changes are needed?
> Stop and think about any other changes that might be required to take into account that the database server is now also running in a container.

You will need to change the connection string for the Web API to reflect the new way of hosting of the database. Add a new environment variable for the connection string of the leaderboard.webapi service in the `docker-compose.override.yml` file:

```
- ConnectionStrings__LeaderboardContext=Server=sql.data;Database=Leaderboard;User Id=sa;Password=Pass@word;Trusted_Connection=False
```

> ##### Strange connection string or not? 
> There are at least two remarkable things in this connection string. Can you spot them and explain why? Don't worry if not, as we will look at this in the [Networking](Lab04-Networking.md) lab.
 
With this change, you should be able to run your applications in containers. Make sure you have stopped any containers related to the application. Give it a try and fix any issues that occur. 

## <a name="debug"></a>Debugging with Docker container instances
One of the nicest features of the Docker support is the debugging support while running container instances. Check out how easy debugging is by stepping through the application like before.

Put a breakpoint at the first statement of the `OnGetAsync` method in the `IndexModel` class in the `GamingWebApp` project. Add another breakpoint in the `Get` method of the LeaderboardController in the Web API project.
If needede, launch and attach a debugger, by pressing F5 and choosing container group `start` and container `gamingwebapp`. Select `Yes` when asked if you want to copy the .NET Core debugger into the container. After that, refresh the web page in your browser. You should be hitting the breakpoints and jump from one container instance to the other.

## <a name="build"></a>Building container images
Start a command prompt and use the Docker CLI to check which container instances are running at the moment. There should be three containers related to the application:
- SQL Server in `sqldocker`.
- SQL Server in `dockercompose<id>_sql.data_1`.
- Web application in `GamingWebApp`.
- Web API in `LeaderboardWebAPI`.

where `<id>` is a random unique integer value.

> ##### New container images
> Which new container images are on your system at the moment? Check your images list with the Docker CLI.

### Remove running containers
- In VS Code, type SHIFT+F5 to detach the debugger.
- In VS Code, type CRTL+SHIFT+B to display the Build tasks. 
- Run your application by running the `docker compose down` task.

> Remember that you can alternatively use `docker rm -f` combined with the first unique part of the container ID or its name to stop and remove containers.

### (Option) Visual Studio users only
If you are using Visual Studio to do this Lab, you will have images tagged `dev` on your machine after using Visual Studio to debug containerized applications.

Try and run the Web application image yourself. Start a container instance.

```cmd
docker run -p 8080:80 -it --name webapp gamingwebapp:dev
```

Check whether the web application is working. It shouldn't work and you'll find that it brings you in a bash shell on Linux.

```cmd
root@65e40486ab0f:/app#
```

Your container image does not contain any of the binaries that make your ASP.NET Core Web application run. Visual Studio uses volume mapping to map the files on your file system into the running container, so it can detect any changes thereby allowing small edits during debug sessions.

> ##### Debug images from Visual Studio
> Remember that Visual Studio creates Debug images that do not work when run from the Docker CLI.

> ##### Asking for help
> Remember that you can ask your proctor for help. Also, working with fellow attendees is highly recommended, as it can be fun and might be faster. Of course, you are free to offer help when asked.

## Wrapup
In this lab you have added Docker support to run both of your projects from Docker containers as well as the SQL Server instance. You enhanced the Docker Compose file that describes the composition of your complete application. In the next lab you will improve the networking part of the composition.

Continue with [Lab 4 - Networking](Lab04-Networking.md).
