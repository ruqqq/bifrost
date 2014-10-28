Q = require "q"
util = require "util"

class Strategy extends require("./strategy.coffee")
	strategy_name: "stop"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

		for ind,val of @argv
			if val is "--c"
				@container_id = @argv[parseInt(ind)+1]
				@argv.splice ind, 2
				break
		
		@opts = @argv.join " "

	@help: () =>
		return "#{super} [--c containerid]"

	execute: =>
		process.stdout.write "Stopping #{@app_name}...\n".yellow
		if @container_id
			process.stdout.write "...only for #{@container_id}...\n".yellow
		f = null
		
		if @container_id
			@ids = [@container_id]
			f = Q.denodeify(@_docker_start_stop_restart)("stop", @container_id, @opts).then =>
				process.stdout.write "...done!\n".green
		else
			f = Q.denodeify(@_docker_get_ids_from_appname)(@app_name).then (ids) =>
				@ids = ids
				deferred = Q.defer()

				if !ids or ids.length is 0
					deferred.reject new Error "No #{@app_name} instances found."

				cmd = (index) =>
					if index >= ids.length
						return deferred.resolve()

					@_docker_start_stop_restart "stop", ids[index], @opts, (err) =>
						process.stdout.write "...done!\n".green

						if err
							console.error err.message.red

						cmd ++index
					, (stderr, stdout) =>
						if stdout
							process.stdout.write stdout.toString().grey
						else if stderr
							process.stderr.write stderr.toString().red

				cmd 0

				return deferred.promise

		f.then => 
			return Q.denodeify(@_docker_inspect)(@ids.join(" "), "")
		.then (inspect) =>
			for ind,data of inspect
				process.stdout.write "\tid: #{data.Id}\n".green
				process.stdout.write "\tname: #{data.Name.replace('/', '')}\n".green
				process.stdout.write "\tip: #{data.NetworkSettings.IPAddress}\n".green
				process.stdout.write "\tports: #{util.inspect(data.NetworkSettings.Ports)}\n".green
				process.stdout.write "\tstate.running: #{data.State.Running}\n".green
				process.stdout.write "\n"
			@connection.end()

			if @app_config.hipache
				@update_router = new @bifrost.strategies["update-router"] @bifrost, @server, [@app_folder]
				@update_router.connect()
		.fail (err) =>
			console.error err.message.red
			return @connection.end()

module.exports = Strategy