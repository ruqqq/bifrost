# bifrost

bifrost is a deployment tool to be used in a *simple** Docker setup. bifrost deploy containers based on parameters specified in `bifrost.yml` and `Dockerfile`.

*(Using bifrost for large scale deployments is largely untested)*

A *simplified* idea of how bifrost works by describing what happens during the command `b build`.

1. Copy folder which includes the `Dockerfile` to the docker host.
2. SSH into docker host and run `docker build`
3. `docker run` with the image which was just created
4. The container is up now if there were no errors during deployment

bifrost was built because I needed a way to deploy my Docker apps easily. Minimal setup and boilerplate. Please read through the README before attempting to use.

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
$ npm install -g bifrost
```

bifrost comes with a helper script `b`. If the bifrost folder is in your `$PATH`, you can invoke bifrost with just `b <args>`.

### hipache Integration

bifrost comes with integration with hipache as a dynamic router for web apps deployed in Docker containers. Setting it up is easy:

- Upload your SSL key and cert (`ssl.key` and `ssl.crt`) into `/root/ssl/ssl.key` and `/root/ssl/ssl.crt` on your Docker host respectively
- On your Docker host:

```
$ docker run --restart="always" -d --name router -p 80:80 -p 443:443 -v /root/ssl:/etc/ssl ruqqq/hipache
```

This will expose the Docker host port 80 and 443 to the hipache instance known as `router`. Now you can point domains A record to the Docker host public IP and the requests will be routed by hipache.

In your app `bifrost.yml`, configure the `hipache` section accordingly. After that, any deployments will automatically configure hipache to point to the deployed app as a backend.

You can deploy as many containers as you want and hipache will load balance between the backends.

**Important: Using this integration means you should start/stop/restart/build your containers with bifrost exclusively as the integration mechanism exists in those commands too.**

*Note: To use hipache without SSL, you'll need to supply your own config.json. Refer to https://github.com/ruqqq/dockerfile-hipache*

## Usage

### Single Host Deployment

1. Create `Dockerfile`
2. Define the application deployment details in `bifrost.yml`
3. Set the folder where you store server configs and SSH keys: `$ export BIFROST_SERVERS=~/.bifrost_servers`
4. Run `$ b build --host=yourserver.com` in the folder with the two files above

**TODO: Finish section**

### Multi Host Deployment

**TODO: Finish section**

Readings:
- [Docker Ambassador Pattern]

[Docker Ambassador Pattern]: https://docs.docker.com/articles/ambassador_pattern_linking/

### Available Commands

You can run `b --help` in the command line for help. The commands are provided here for reference only.

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