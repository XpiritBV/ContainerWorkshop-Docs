# Lab 4 - Networking

This lab will give you time to work with the various networking features of the Docker stack and implement a network design in your current application.

Goals for this lab:
- [Experiment with networking](#experiment)
- [Create networks for application from CLI](#create)
- [Define multiple networks in composition](#define)

> Make sure to configure Docker Desktop to run Linux containers.

## Prerequisites
Make sure you have completed [Lab 1 - Getting Started](Lab01-GettingStarted.md).


## Getting started

In the terminal, change directories to the Docs repository directory named 'resources/lab04'
```
C:\Sources\ContainerWorkshop\ContainerWorkshop-Docs\resources\lab04>
```

## <a name="experiment"></a>Experimenting with networking

To start out, you are going to experiment a little with the networking stack of Docker.
Run a couple of commands from the Docker CLI to investigate the existing networks:

```
docker network ls

NETWORK ID     NAME      DRIVER    SCOPE
8faa3d52c15d   bridge    bridge    local
a6fdb0c8ba7d   host      host      local
f361f3548adb   none      null      local
```

You should see a number of networks, amongst which the default networks `host`, `bridge` and `none`. There might be some additional networks from the Docker composition you created in the previous lab. 

Pick a couple of the available networks by running:
``` 
docker inspect bridge

[
    {
        "Name": "bridge",
        "Id": "8faa3d52c15d5e77d94bdac3607f5d12268660638f30ac12d7e9f09",
        "Created": "2021-02-02T06:29:51.5602354Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "2f82864cdfc9115419a1c0a14b1c427aa5a651a2103d195f": {
                "Name": "portainer",
                "EndpointID": "f51d75f4a011249a1289f6dc3856cf09d4ad9bc4ff5cb0c1d2",
                "MacAddress": "aa:bb:cc:dd:ee:ff",
                "IPv4Address": "172.17.0.2/16",
                "IPv6Address": ""
            },
            "37b2c929faccb00244e8662862c7ca9093473c66a04e5927": {
                "Name": "sqldocker",
                "EndpointID": "1d8abbdf919925762e7e6b81df4d8336d6fdc873e234cabec0",
                "MacAddress": "aa:bb:cc:dd:ee:ff",
                "IPv4Address": "172.17.0.4/16",
                "IPv6Address": ""
            }
        },
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
```
Use the name of the network listed in `docker network ls` earlier. 
Read each of the JSON fragments. Pay special attention to the `Config` object in the `IPAM` section and the `Containers` array, which defines a Subnet address block for your containers. 

### Types of networks
- **bridge**: The default network driver. Mostly used when standalone containers need to communicate with each other. It allows communication between containers on the same host inside the same bridge network, but isolates them from other containers. Custom bridge networks allow containers to find each other by using DNS. The container name can be used to find its IP address.
- **host**: Used for standalone containers. This network removes isolation between the container and host, and uses the host's network directly. A container can access services running on the host, by calling them on `localhost` and using a port number.
- **none**: Using this option, disables networking for a container.

> ##### Different configurations
> Why are the config sections for networks `host` & `none` empty?
> Which IP addresses will be assigned to the containers when they are inside a bridge network?

Shut down any running compositions, by stopping your Visual Studio debugging session and any manually started containers of the demo application.

### <a name="clean"></a> Cleanup running containers
Run `docker ps -a` to see if you need to stop any running containers:
```
docker ps -a
```
and remove them if needed:
```
docker rm -f <containerid>
```

> Tip: if you want to stop and remove all running containers in one go, you can also use:
>```cmd
>docker rm -f $(docker ps -a -q)
>```

## <a name="create"></a>Manually create a docker network

Let's create a new container network and run a couple of containers in them:

```
docker network create workshop_network --driver bridge
```
Use `docker inspect` on the new network. Note the network address range that it will use.
Run a simple container named "c1" with a Bash shell in attached mode:
```
docker run -it --name c1 --network workshop_network alpine sh
```
You should see a Bash command prompt `/ # `. You can check the IP address that this container has by using the command `ip address` or `ip a` for short. There should be information showing an address in the range you saw before, resembling this:
```
29: eth0@if30: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
```
Also check the network configuration by running `ifconfig` from the Bash prompt. It will probably list two networks `lo` for the loopback and eth0 as an Ethernet adapter controlling the inbound and outbound traffic in the address range for any containers running in this network.

Finally, check internet connectivity by running `nslookup`:
```
nslookup xpirit.com

Server:         127.0.0.11
Address:        127.0.0.11:53

Non-authoritative answer:
Name:   xpirit.com
Address: 34.66.143.219
```
Exit the container terminal by running `exit`:
```
exit
```

### Running a container without network specification

Repeat this for a container named "c2", without explicitly specifying the network the container should run in:

```cmd
docker run -it --name c2 alpine sh
```

Detach the terminal and leave the container running, by pressing `Ctrl+P` followed by `Ctlr+Q`.

Try to figure out in which network this container ended up. 
> Hint: Remember `docker network inspect`?

### More advanced networking

Experiment some more with manually created networks. For example, use a specific address range when creating the network and add two containers with specified IP addresses in the range and a network alias (DNS name), keep them alive by running a never-ending `ping` command:

```cmd
docker network create -d bridge --subnet 10.0.0.0/24 workshop_specific

docker run -d --name c3 --ip 10.0.0.3 --net workshop_specific --network-alias c3.containerworkshop.local alpine ping localhost

docker run -d --name c4 --ip 10.0.0.4 --net workshop_specific --network-alias c4.containerworkshop.local alpine ping localhost
```

Create a shell process within the "c3" container, and attach your terminal by using `docker exec -it`:

```cmd
docker exec -it c3 sh
```


From within the terminal of container "c3", you should be able to ping container itself `c3` using the `ping` command:

```cmd
ping c3.containerworkshop.local

PING c3.containerworkshop.local (10.0.0.3): 56 data bytes
64 bytes from 10.0.0.3: seq=0 ttl=64 time=0.016 ms
64 bytes from 10.0.0.3: seq=1 ttl=64 time=0.039 ms
^C
```

Also, because you added container "c4" to the same network as container "c3", you should also be able to ping it:

```cmd
ping c4.containerworkshop.local

PING c4.containerworkshop.local (10.0.0.4): 56 data bytes
64 bytes from 10.0.0.4: seq=0 ttl=64 time=0.075 ms
64 bytes from 10.0.0.4: seq=1 ttl=64 time=0.067 ms
^C
```

Also, inspect the network again to see the running containers in it:

```cmd
docker network inspect workshop_specific
```

This command should show both containers "c3" and "c4" running:

```json
  "Containers": {
      "9cd0629b33188e3edd14467d64a0ea6e732e72530": {
          "Name": "c3",
          "EndpointID": "ce0060e186274f3ad41c0d3fb9e757c4dcc",
          "MacAddress": "aa:bb:cc:00:00:00",
          "IPv4Address": "10.0.0.3/24",
          "IPv6Address": ""
      },
      "efc62e05753bfd0e69bc865411d7c7f684c5ed45c": {
          "Name": "c4",
          "EndpointID": "1571f5622f4aba58bc5392b30c10358c9bdf",
          "MacAddress": "aa:bb:cc:00:00:00",
          "IPv4Address": "10.0.0.4/24",
          "IPv6Address": ""
      }
  }
```

### Cleanup
[Cleanup](#clean) all running containers.

Remove the manually created networks:

```cmd
docker network rm workshop_network
docker network rm workshop_specific
```

## <a name="define"></a>Define networks in docker compositions
You have now learned that it is possible to have multiple containers interact with each other across a Docker network. It can be cumbersome to use the Docker CLI to build large container orchestrations and networks. This is where `docker-compose` can help. It uses a declarative approach about your desired state, and ensures that your environment matches that state.

Before we create a composition, we will first design a network topology and use the Docker Compose YAML files to specify the networks and aliases for the containers.

The project you are working with has 3 tiers:

1. **Web Frontend** - uses the Web API
1. **Web API**  - uses the database
1. **SQL Database Server** - stores information

Create a visual diagram for the three containers and assign them to the **proper** networks. The boundaries of these networks should be such that the web application can reach the web API, but not the SQL Server database. On the other hand, the Web API should be able to reach both the SQL Server database and the web application, but not from the same network. This network topology acts as a security boundary.

> ##### A choice of network type
> What type of network driver should the two networks use? Remember that your are currently in a local, single-host situation. How would that change when running in a cluster? Also consider the impact of running multiple instances of your container.

### Find the compose files 
In your terminal, navigate to the `resources\lab04` folder. (e.g. `C:\Sources\ContainerWorkshop\ContainerWorkshop-Docs\resources\lab04`)

Run docker-compose to build the desired containers and network using a definition file named `00-docker-compose-netwrk.yml`:

  ```cmd
  docker-compose -f 00-docker-compose-netwrk.yml up -d

  Creating network "lab04_frontend" with driver "bridge"
  Creating network "lab04_backend" with driver "bridge"
  Creating lab04-backend-1  ... done
  Creating lab04-db-1       ... done
  Creating lab04-frontend-1 ... done
  ```
  
  After completion, you should have three running containers and two custom Docker networks.
  
  ```
  docker ps

  CONTAINER ID   IMAGE                                        COMMAND                  CREATED              STATUS              PORTS                                            NAMES
  bb0fb3d99df6   nginx                                        "/docker-entrypoint.…"   About a minute ago   Up About a minute   80/tcp                                           lab04-backend-1
  77cf533cd37a   mcr.microsoft.com/mssql/server:2019-latest   "/opt/mssql/bin/perm…"   About a minute ago   Up About a minute   0.0.0.0:5433->1433/tcp                           lab04-db-1
  2628e46f4874   nginx                                        "/docker-entrypoint.…"   About a minute ago   Up About a minute   80/tcp                                           lab04-frontend-1
  ```

  You can also see that all resources have a prefix `lab04` that equals the name of the folder that holds the compose file.

### Check that everything works

Hints, use tools like `docker exec -it <<container>> bash` and `docker network inspect lab04_backend` to verify connectivity works as expected.

Inside the backend container terminal, run the command `curl -v ` and check how many ethernet adapters are listed. Verify that it corresponds with your design.

```bash
curl -v lab04-frontend-1
```

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### I can't even run `ping` ?!
You'll likely find that there's very little tooling available within the containers to work with. This is a good thing, as it reduces the attack surface of your container.

If you need to investigate a container composition, you can temporarily run a new container (like busybox) inside the backend network:

```cmd
docker run -it --name bb --network lab04_backend busybox sh
```

From the terminal check for connectivity to the frontend:

```bash
ping lab04-frontend-1
ping: bad address 'lab04-frontend-1'
```

Check connectivity to localhost:

```bash
ping lab04-backend-1

PING lab04-backend-1 (172.22.0.3): 56 data bytes
64 bytes from 172.22.0.3: seq=0 ttl=64 time=0.065 ms
64 bytes from 172.22.0.3: seq=1 ttl=64 time=0.238 ms
^C
```

And finally, check network connectivity to the database server:

```bash
ping lab04-db-1
PING lab04-db-1 (172.22.0.2): 56 data bytes
64 bytes from 172.22.0.2: seq=0 ttl=64 time=0.041 ms
64 bytes from 172.22.0.2: seq=1 ttl=64 time=0.074 ms
^C
```

You can even see if SQL Server is running, by using `telnet`:

```bash
telnet lab04-db-1 1433

Connected to lab04-db-1
^C
Console escape. Commands are:

 l      go to line mode
 c      go to character mode
 z      suspend telnet
 e      exit telnet
 ```

Hit `Ctrl+C` and `e` to quit telnet.
Type `exit` to exit the `busybox` container.
Cleanup the `busybox` container. (`docker rm -f bb`)

### Container alias (DNS)

You can also give a container instance an alias, so you can refer to it by a network alias instead of its container service name. Use the fragment below to give the SQL Server instance created in the [Docker 101 lab](Lab02-Docker101.md#sql) a network alias `sql.containerworkshop.local` on your `db` service.

```yaml
  db:
    ..
    networks:
      backend:
        aliases:
          - "sql.containerworkshop.local"
```

>Please note that the network 'backend' no longer has a `-` in front of it.

If you want to complete this part, just apply the file named `01-docker-compose-netwrk-alias.yml`

```cmd
docker-compose -f 01-docker-compose-netwrk-alias.yml up -d
```

Run busybox again and verify that the database server can be resolved by its alias:

```bash
telnet sql.containerworkshop.local 1433

Connected to sql.containerworkshop.local
^C
Console escape. Commands are:

 l      go to line mode
 c      go to character mode
 z      suspend telnet
 e      exit telnet
 ```

### Add networks to workshop solution
Finally, you can try adding the same networking structure to the `docker-compose.override.yml` file. 
Use this checklist to see if it is complete:
- Add a `frontend` bridge network
- Add a `backend` bridge network
- Assign `leaderboardwebapi` and `sql.data` to the `backend` network
- Assign `leaderboardwebapi` and `gamingwebapp` to the `frontend` network
- Give the `sql.data` service an alias named `sql.retrogaming.internal`
- Change the connection string setting for the `leaderboardwebapi` service to reflect the alias

Verify that everything still works by running your Visual Studio solution. Fix any errors should they occur.

## Wrapup

In this lab you experimented with networks in Docker from the command line and later with definitions in Docker Compose compositions. You applied network segmentation to separate container instances from each other, to improve network security.

Continue with [Lab 5 - Environments](Lab05-Environments.md).
