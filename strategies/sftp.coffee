Q = require "q"
util = require "util"

class Strategy extends require("./strategy.coffee")
	strategy_name: "sftp"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

		@opts = @argv.join " "

	execute: =>
		#console.info "WARNING: You can only access folders of running instances. If the instance is not running, do not save files via SFTP.".yellow
		Q.denodeify(@_docker_get_ids_from_appname)(@app_name)
		.then (ids) =>
			if !ids or ids.length is 0
				return @connection.end()

			return Q.denodeify(@_docker_inspect)(ids.join(" "), "")
		.then (inspect) =>
			for ind,data of inspect
				process.stdout.write "\tname: #{data.Name.replace('/', '')}\n".green
				process.stdout.write "\tstate.running: #{data.State.Running}\n".green
				process.stdout.write "\tsftp://#{@server.username}@#{@server.host}:#{@server.port}//var/lib/docker/devicemapper/mnt/#{data.Id}/rootfs/\n".green
				process.stdout.write "\n"
			@connection.end()
		.fail (err) =>
			console.error err.message.red
			return @connection.end()

module.exports = Strategy