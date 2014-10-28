Q = require "q"
util = require "util"

class Strategy extends require("./strategy.coffee")
	strategy_name: "status"

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
		Q.denodeify(@_docker_get_ids_from_appname)(@app_name)
		.then (ids) =>
			if !ids or ids.length is 0
				throw new Error "No #{@app_name} instances found."

			if @container_id
				if ids.indexOf(@container_id) > -1
					return Q.denodeify(@_docker_inspect)(@container_id, "")
				else
					throw new Error "Instance not found."
			else
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

module.exports = Strategy