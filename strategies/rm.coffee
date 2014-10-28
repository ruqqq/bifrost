Q = require "q"

class Strategy extends require("./strategy.coffee")
	strategy_name: "rm"

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
		process.stdout.write "Removing #{@app_name}...\n".yellow
		if @container_id
			process.stdout.write "...only for #{@container_id}...\n".yellow
		f = null
		
		if @container_id
			@ids = [@container_id]
			f = Q.denodeify(@_docker_rm)(@container_id, @opts).then =>
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

					@_docker_rm ids[index], @opts, (err) =>
						process.stdout.write "...done!\n".green

						if err
							console.error err.message.red

						cmd ++index

				cmd 0

				return deferred.promise

		f.then => 
			@connection.end()
		.fail (err) =>
			console.error err.message.red
			return @connection.end()

module.exports = Strategy