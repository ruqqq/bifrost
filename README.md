# bifrost

bifrost is a deployment tool to be used in a *simple** Docker setup. bifrost deploy containers based on parameters specified in `bifrost.yml` and `Dockerfile`.

*(Using bifrost for large scale deployments is largely untested)*

A *simplified* idea of how bifrost works by describing what happens during the command `b build`:

1. Copy folder which includes the `Dockerfile` to the docker host.
2. SSH into docker host and run `docker build`
3. `docker run` with the image which was just created
4. The container is up now if there were no errors during deployment

bifrost was built because I needed a way to deploy my Docker apps easily with minimal setup. Please read through the README before attempting to use.

## Installation

bifrost is basically a bunch of "scripts" which SSH into your Docker host and perform the requested commands. Minimally, you only need a local machine (the deployer) with the dependencies installed, and the target machine with Docker and SSH installed.

Target Machine:
- Install Docker (tested with 1.3)
- A private IP on `eth0` (possible without but untested)

Local Machine:
- Install rsync (already installed on OSX and Ubuntu)
- Node.js, npm and CoffeeScript
- Install bifrost
- Generate SSH key and install on target machine's root user

Install bifrost:

```
$ npm install -g bifrost-deploy
```

**You can now invoke bifrost with either `bifrost <args>` or simply just `b <args>`.**

### hipache Integration

bifrost comes with integration with hipache as a dynamic router for web apps deployed in Docker containers. Setting it up is easy:

- Upload your SSL key and cert (`ssl.key` and `ssl.crt`) into `/root/ssl/ssl.key` and `/root/ssl/ssl.crt` on your Docker host respectively
- On your Docker host:

```
$ docker run --restart="always" -d --name router -p 80:80 -p 443:443 -v /root/ssl:/etc/ssl ruqqq/hipache
```

This will expose the Docker host port 80 and 443 to the hipache instance known as `router`. Now you can point A records of domains to the Docker host public IP and the requests will be routed by hipache.

In your app `bifrost.yml`, configure the `hipache` section accordingly. Bifrost will automatically configure hipache to point to the app as a backend when issuing build/start/stop/restart commands. You can deploy as many containers as you want and hipache will load balance between the backends.

**Important: Using this integration means you should start/stop/restart/build your containers with bifrost exclusively as the integration mechanism exists in those commands too.**

*Note: To use hipache without SSL, you'll need to supply your own config.json. Refer to https://github.com/ruqqq/dockerfile-hipache*

## Usage

### Servers YAML

- Servers are configured in a YAML file - A sample is available in `servers-sample/server.sample.yml`
- The filename should be the server hostname (i.e. `domain.com.yml`)
- Place the file in a folder somewhere (i.e. `~/.bifrost_servers`) and set `BIFROST_SERVERS` environment variable:

```
$ export BIFROST_SERVERS=~/.bifrost_servers
```

- Alternatively, set this environment in your shell init file

### Setting Environment Variables

- `BIFROST_SERVERS`: Location of your servers yml files (i.e. `~/.bifrost_servers`)
- `BIFROST_HOST`: The Docker host to target deployment at. Optionally, you can instead specify `--host domain.com` option when running commands. In this example, `$BIFROST_SERVERS/domain.com.yml` must exist.

### Single Host Deployment

1. Ensure your app folder has a `Dockerfile`
2. Ensure `bifrost.yml` is configured correctly in the app folder (sample in `sample-app/bifrost.sample.yml`)
3. Ensure your environment variables are set (see previous section)
4. In your app folder, run `$ b build --host=domain.com`

bifrost will now SSH into the server and build the docker image followed by creating and running the container. If no errors were encountered, you should have your container up an running. Every time you need to update, just run the command again and it'll rebuild the image as needed and start a new container (and delete existing ones).

### Multi Host Deployment

bifrost does not support fleet deployment. You'll have to deploy to individual Docker hosts manually. (i.e. running `b build` command on the different hosts). To make your `--links` directive work properly, refer to [Docker Ambassador Pattern].

For hipache-based deployments, you should setup your Docker hosts in a private network. In `bifrost.yml` config, expose the ports to your Docker host private IP. hipache will then map the domains to the Docker containers on different hosts via the private IP.

[Docker Ambassador Pattern]: https://docs.docker.com/articles/ambassador_pattern_linking/

## Sample App

**TODO: Finish Sample App **

### Available Commands

The commands are to be run in your app folder which contains `bifrost.yml`. You can also run `b --help` in the command line for help.

Command | Description
---:| ---
`build [--scale num]` | build and deploy image; use `--scale` to specify how many instances to run
`clean` | stops all containers, remove them and remove all images; kind of like "reformatting" the host
`inspect <container id>` | inspect the specific container id
`logs <container id> [--file file]` | view log for the specific container id; use `--file` to view log file inside the container
`restart [--c containerid]` | restart the app on the host; use `--c` to target specific container
`rm [--c containerid]` | remove the app on the host; use `--c` to target specific container
`sftp` | view sftp folder for the containers
`start [--c containerid]` | start the app on the host; use `--c` to target specific container
`status [--c containerid]` | view status of the app on the host; use `--c` to target specific container
`stop [--c containerid]` | stop the app on the host; use `--c` to target specific container
`trim` | deletes unused images on the host
`update-config` | upload <appFolder>/config to the host
`update-router` | update hipache routing for the app

## Author

- Faruq Rasid <me@ruqqq.sg>