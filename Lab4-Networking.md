# Lab 4 - Networking

This lab will give you time to work with the various networking features of the Docker stack and implement a network design in your current application.

Goals for this lab:
- [Experiment with networking](#experiment)
- [Create networks for application from CLI](#create)
- [Define multiple networks in composition](#define)

> Make sure to configure Docker Desktop to run Linux containers.

## <a name="experiment"></a>Experimenting with networking

To start out, you are going to experiment a little with the networking stack of Docker.
Run a couple of commands from the Docker CLI to investigate the existing networks:

```
docker network ls
```

You should see a number of networks, amongst which the default networks `host`, `bridge` and `none`. There might be some additional networks from the Docker composition you created in the previous lab. 

Pick a couple of the available networks by running:
``` 
docker inspect <networkid>
```
where *\<networkid>* is the unique part of the network ID listed in `docker network ls`. 
Read each of the JSON fragments. Pay special attention to the `Config` object in the `IPAM` section and the `Containers`  array. 

### Types of networks
- bridge: The default network driver. Mostly used when standalone containers need to communicate with each other. It allows communication between containers on the same host inside the same bridge network, but isolates them from other containers. Custom bridge networks allow containers to find each other by using DNS. The container name can be used to find its IP address.
- host: Used for standalone containers. This network remove isolation between the container and host, and use the host's network directly. A container can access services running on the host, by calling them on `localhost` and using a port number.
- none: Using this option, disables networking for a container.

> ##### Different configurations
> Why are the config sections for networks `host` & `none` empty?
> Which IP addresses will be assigned to the containers when they are inside a bridge network?

Shut down any running compositions, by stopping your Visual Studio debugging session and any manually started containers of the demo application.

## <a name="create"></a>Create networks manually

Let's create a new network and run a couple of containers in them. 
```
docker network create workshop_network --driver bridge
```
Use `docker inspect` on the new network. Note the network address range that it will use.
Run a simply container with a Bash shell in attached mode:
```
docker run -it --name c1 --network workshop_network alpine sh
```
You should see a Bash command prompt `/ #`. You can check the IP address that this container has by using the command `ip address` or `ip a` for short. There should be information showing an address in the range you saw before, resembling something like this:
```
29: eth0@if30: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
```
Also check the network configuration by running `ifconfig` from the Bash prompt. It will probably list two networks `lo` for the loopback and eth0 as an Ethernet adapter controlling the inbound and outbound traffic in the address range for any containers running in this network.

Repeat this for a container without specifying the network the container should run in.

```cmd
docker run -it --name c2 alpine sh
```

Try to figure out in which network this container ended up.

Experiment some more with manually created networks. For example use a specific address range when creating the network and add a container with a specified IP address in the range and an alias:

```cmd
docker network create -d bridge --subnet 10.0.0.0/24 workshop_specific
docker run -itd --name c3 --ip 10.0.0.123 --net workshop_specific --network-alias c3.containerworkshop.local alpine sh
```

You should be able to ping container `c3` from inside itself with `ping c3.containerworkshop.local`. Also, inspect the network again to see the running containers in it. 

## <a name="define"></a>Define networks in docker compositions

The final step is to design your network topology and use the Docker Compose YAML files to specify the networks and aliases for the containers.

Create a visual diagram for the three containers and draw assign them to two networks. The boundaries of these networks should be such that the web application can reach the web API, but not the SQL Server database. On the other hand, the Web API should be able to reach both the SQL Server database and the web application, but not from the same network.

> ##### A choice of network type
> What type of network drive should the two networks use? Remember that your are currently in a local, single-host situation. How would that change when running in a cluster?

Give the two networks an appropriate name such as `frontend` and `backend`. Define the two networks in the `docker-compose.override.yml` file with:

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

Assign the container service definitions to the networks from your diagram. You can do this by adding a `network` section to the corresponding service like so:

```yaml
    networks:
      - frontend
```

Finish all changes and test your new network topology for the container composition. Run a couple of commands from the Docker CLI to list and inspect the new networks. Verify that your containers are running in the respective networks and that they have the correct IP addresses. As a reminder, some commands that might help here:

```cmd
docker network ls
docker inspect <networkid>
docker exec -it <containerid> sh
```

The last command will give a bash from the container instance whose ID you specified. Run a command `ip a` and check how many ethernet adapters are listed. Verify that it corresponds with your design.

You can also give a container instance an alias, so you can refer to it by a network alias instead of its container service name. Use the fragment below to give the SQL Server instance created in the [previous module](https://github.com/XpiritBV/ContainerWorkshop2018Docs/blob/master/Lab3-DockerizingNETCore.md#running-sql-server-in-a-docker-container) a network alias `sql.containerworkshop.local`.

```yaml
    networks:
      backend:
        aliases:
          - sql.containerworkshop.local
```
## Coming from Lab 3
Did you work on Lab 3 before this? If so, after defining this alias, change the connection string setting of the `LeaderboardContext` for the Web API to use this new network name.

## Wrapup

In this lab you experimented with networks in Docker from the command line and later with definitions in compositions. You applied network segmentation to separate the container instances from each other, to improve network security.

Continue with [Lab 5 - Environments](Lab5-Environments.md).
