Q = require "q"
util = require "util"

class Strategy extends require("./strategy.coffee")
	strategy_name: "trim"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

	execute: =>
		process.stdout.write "Deleting unused containers and images...!\n".yellow
		Q.denodeify(@_docker_trim)()
		.then =>
			process.stdout.write "...done!\n".green
			@connection.end()
		.fail (err) =>
			console.error err.message.red
			@connection.end()

module.exports = Strategy