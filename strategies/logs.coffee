Q = require "q"
util = require "util"

class Strategy extends require("./strategy.coffee")
	strategy_name: "logs"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

		for ind,val of @argv
			if val is "--f"
				@file = @argv[parseInt(ind)+1]
				@argv.splice ind, 2
				break

		@container_id = @argv[0]
		
		@opts = @argv.join " "

	@help: () =>
		return "#{super} <container id> [--f file]"

	execute: =>
		if !@container_id
			console.error "Please specify instance name.".red
			process.stdout.write "Instances:\n".blue
			Q.denodeify(@_docker_get_ids_from_appname)(@app_name)
			.then (ids) =>
				if !ids or ids.length is 0
					throw new Error "Instance not found."

				return Q.denodeify(@_docker_inspect)(ids.join(" "), "")
			.then (inspect) =>
				for ind,data of inspect
					process.stdout.write "\tid: #{data.Id}\n".green
					process.stdout.write "\tname: #{data.Name.replace('/', '')}\n".green
					process.stdout.write "\tip: #{data.NetworkSettings.IPAddress}\n".green
					process.stdout.write "\tports: #{util.inspect(data.NetworkSettings.Ports)}\n".green
					process.stdout.write "\tstate.running: #{data.State.Running}\n".green
					process.stdout.write "\n"
				@connection.end()
			.fail (err) =>
				console.error err.message.red
				return @connection.end()
		else
			Q.denodeify(@_docker_get_ids_from_appname)(@app_name)
			.then (ids) =>
				if !ids or ids.length is 0
					throw new Error "Instance not found."

				return Q.denodeify(@_docker_inspect)(ids.join(" "), "")
			.then (inspect) =>
				container = null

				for ind,data of inspect
					if data.Name.replace('/', '') is @container_id
						container = data
						break

				if !container
					throw new Error "Instance not found."

				if !container.State.Running
					console.log "WARNING: Instance is not running.".yellow

				@_logs container.Id, @file, (std, output) =>
					@connection.end()
				, (stderr, stdout) =>
					if stdout
						process.stdout.write stdout.toString().grey
					else if stderr
						process.stderr.write stderr.toString().red 
			.fail (err) =>
				console.error err.message.red
				return @connection.end()

	_logs: (container_id, file, callback, opt_callback) =>
		cmd = "docker logs -f -t #{container_id}"
		if @file
			cmd = "tail -n 500 -f /var/lib/docker/devicemapper/mnt/#{container_id}/rootfs#{file}"
		
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error util.inspect({code: code, signal: signal, stderr: output.stderr})

module.exports = Strategy