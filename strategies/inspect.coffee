Q = require "q"
util = require "util"

class Strategy extends require("./strategy.coffee")
	strategy_name: "inspect"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv
		
		@container_id = @argv[0]
		if !@container_id
			console.error "Please specify container id".red
			return process.exit(1)

		@argv.splice 0, 1
		
		@opts = @argv.join " "

	@help: () =>
		return "#{super} <container id>"

	execute: =>
		Q.denodeify(@_docker_inspect)(@container_id, @opts)
		.then (inspect) =>
			console.log util.inspect(inspect).grey
			@connection.end()
		.fail (err) =>
			console.error err.message.red
			@connection.end()

module.exports = Strategy