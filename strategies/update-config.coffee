Q = require "q"
fs = require "fs"
path = require "path"
YAML = require "yamljs"
util = require "util"
rsync = require("rsyncwrapper").rsync

class Strategy extends require("./strategy.coffee")
	strategy_name: "update-config"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

		if !@app_config.configFolder
			console.error "Config folder not supported by app. (Probably included in Dockerfile)."
			process.exit 1

		if !fs.existsSync("#{@app_folder}/#{@app_config.appFolder}/config")
			console.error "Config folder does not exist for the app."
			process.exit 1

		@opts = @argv.join " "

	@help: () =>
		return "#{super}"

	execute: =>
		folder = @app_folder
		remote = "/tmp/#{@app_name}_config"

		Q.denodeify(rsync)(
			args: ["-a"]
			src: folder + "/config"
			dest: "#{@server.username}@#{@server.host}:#{remote}"
			ssh: true
			port: @server.port
			privateKey: @server.key_file)
		.then (stdout, stderr, cmd) =>
			if stderr
				throw new Error stderr
			else
				process.stdout.write " uploaded!\n".green
		.then =>
			return Q.denodeify(@_mkdir_vols)(@app_config.name)
		.then =>
			return Q.denodeify(@_copy)(remote + "/config/*", "/root/app_configs/#{@app_name}/")
		.then =>
			return Q.denodeify(@_rm)(remote)
		.then =>
			return @connection.end()
		.fail (err) =>
			console.error err.message.red
			return @connection.end()

	# callback(err)
	_mkdir_vols: (container_id, callback, opt_callback) =>
		cmd = "mkdir -p /root/app_configs/#{container_id} "
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect {code: code, signal: signal, stderr: output.stderr})

module.exports = Strategy