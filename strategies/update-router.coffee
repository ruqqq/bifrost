Q = require "q"
util = require "util"
fs = require "fs"
YAML = require "yamljs"
Connection = require "ssh2"

class Strategy extends require("./strategy.coffee")
	strategy_name: "update-router"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

		@app_server = @server

		# load the server file based on env or argv
		serverPath = if process.env.BIFROST_SERVERS then process.env.BIFROST_SERVERS else "servers"
		if serverPath is ""
			console.error "Env variable BIFROST_SERVERS is empty.".red
			process.exit 1

		@hipache_server = "#{serverPath}/#{@app_config.hipache.host}.yml"

		if !fs.existsSync(@hipache_server)
			console.error "Server #{@app_config.hipache.host} not found.".red
			process.exit 1

		@hipache_server = require(@hipache_server)

		@opts = @argv.join " "

		@second_step = false
		@backends = []

	execute: =>
		if @second_step
			console.log "Updating hipache config...".yellow
			console.log "...removing #{@app_server.host}:*".yellow
			Q.denodeify(@_commanche_remove_all_backends)(@app_config.hipache.container, @app_config.hipache.frontend, @app_server.host)
			.then =>
				if @private_ip
					console.log "...removing #{@private_ip}:*".yellow
					return Q.denodeify(@_commanche_remove_all_backends)(@app_config.hipache.container, @app_config.hipache.frontend, @private_ip)
			.then =>
				if @app_server.host is @hipache_server.host
					console.log "...removing #{@docker_iface_ip}:*".yellow
					return Q.denodeify(@_commanche_remove_all_backends)(@app_config.hipache.container, @app_config.hipache.frontend, @docker_iface_ip)
			.then =>
				if @backends.length > 0
					console.log "...adding #{@backends}".yellow
					return Q.denodeify(@_commanche_add_backends)(@app_config.hipache.container, @app_config.hipache.frontend, @backends)
			.then =>
				console.log "...success.".green
				@connection.end()
			.fail (err) =>
				console.error err.message.red
				return @connection.end()
		else
			console.log "Retrieving app info...".yellow

			Q.denodeify(@_docker_get_ids_from_appname)(@app_name)
			.then (ids) =>
				if !ids or ids.length is 0
					@continue_reconfigure_hipache = true
					throw new Error "No #{@app_name} instances found."

				if @container_id
					if ids.indexOf(@container_id) > -1
						return Q.denodeify(@_docker_inspect)(@container_id, "")
					else
						@continue_reconfigure_hipache = true
						throw new Error "Instance not found."
				else
					return Q.denodeify(@_docker_inspect)(ids.join(" "), "")
			.then (inspect) =>
				for ind,data of inspect
					host = @app_server.host
					
					for p,val of data.NetworkSettings.Ports
						if val and @app_config.hipache.port is p
							for ind,val of val
								host = val.HostIp
								port = val.HostPort

								b = "http://" + host + ":" + port
								@backends.push b
								console.log "...Found #{b}...".yellow

				console.log "...done.".green
				process.stdout.write "getting docker ip...\n".yellow
				return Q.denodeify(@_get_docker_iface_ip)(null)
			.then (ip) =>
				@docker_iface_ip = ip
				return Q.denodeify(@_get_private_ip)(null)
			.then (ip) =>
				@private_ip = ip
				@_configure_hipache()
			.fail (err) =>
				console.error err.message.red
				if @continue_reconfigure_hipache
					return @_configure_hipache()
				else
					return @connection.end()

	_configure_hipache: (callback) =>
		@second_step = true
		@server = @hipache_server
		if @server.host isnt @hipache_server.host
			@connection.end()
			@connect()
		else
			@execute()

	_commanche_add_backends: (router_container_id, frontend, backends, opt_callback, callback) =>
		cmd = "docker run -it --rm --link #{router_container_id}:redis ruqqq/commanche bash -c 'commanche -h $REDIS_PORT_6379_TCP_ADDR -add -f=\"#{frontend}\" -b=\"#{backends.join(',')}\"'"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error util.inspect({code: code, signal: signal, stderr: output.stderr})

	_commanche_remove_all_backends: (router_container_id, frontend, backend, opt_callback, callback) =>
		cmd = "docker run -it --rm --link #{router_container_id}:redis ruqqq/commanche bash -c 'commanche -h $REDIS_PORT_6379_TCP_ADDR -rm -f=\"#{frontend}\" -b=\"#{backend}:*\"'"
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