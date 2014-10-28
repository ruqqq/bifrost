Q = require "q"
fs = require "fs"
path = require "path"
YAML = require "yamljs"
util = require "util"
rsync = require("rsyncwrapper").rsync

class Strategy extends require("./strategy.coffee")
	strategy_name: "build"

	constructor: (@bifrost, @server, @argv) ->
		super @bifrost, @server, @argv

		@numContainers = 1
		for ind,val of @argv
			if val is "--scale"
				@numContainers = parseInt(@argv[parseInt(ind)+1])
				@argv.splice ind, 2
				break

		@opts = @argv.join " "

	@help: () =>
		return "#{super} [--scale num]"

	execute: =>
		folder = "#{@app_folder}/#{@app_config.appFolder}"
		sftp = ""

		process.stdout.write "uploading to docker host...".yellow
		Q.denodeify(rsync)(
			args: ["-a"]
			src: folder
			dest: "#{@server.username}@#{@server.host}:/tmp/#{@app_name}"
			ssh: true
			port: @server.port
			privateKey: @server.key_file)
		.then (stdout, stderr, cmd) =>
			if stderr
				throw new Error stderr
			else
				process.stdout.write " uploaded!\n".green
		.then =>
			return Q.denodeify(@_docker_get_image_id_from_appname)(@app_config.name)
		.then (ids) =>
			@oldImageIds = ids
			process.stdout.write "[oldImageId: #{@oldImageIds}]\n".green
			return Q.denodeify(@_docker_get_ids_from_appname)(@app_config.name)
		.then (ids) =>
			@oldContainerIds = ids
			process.stdout.write "[oldContainerIds: #{@oldContainerIds}]\n".green

			deferred = Q.defer()

			process.stdout.write "building image (this may take a while)...\n".yellow
			@tag = @app_name + ":" + new Date().getTime()
			@_docker_build @tag, @app_name, @opts, (err) =>
				process.stdout.write "...done!\n".green

				if err then return deferred.reject err
				return deferred.resolve()
			, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout.toString().grey
				else if stderr
					process.stderr.write stderr.toString().red

			return deferred.promise
		.then =>
			return Q.denodeify(@_docker_get_image_id_from_appname)(@app_config.name)
		.then (ids) =>
			@newImageId = ids[0]
			process.stdout.write "[newImageId: #{@newImageId}]\n".green
			return Q.denodeify(@_mkdir_vols)(@app_config.name)
		.then =>
			deferred = Q.defer()

			if @app_config.configFolder and fs.existsSync folder + "/config"
				remote = "/tmp/#{@app_name}_config"

				process.stdout.write "uploading config to docker host...".yellow
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
					return Q.denodeify(@_copy)(remote + "/config/*", "/root/app_configs/#{@app_name}/")
				.then =>
					return Q.denodeify(@_rm)(remote)
				.then =>
					return deferred.resolve()
				.fail (err) =>
					return deferred.reject err
			else
				return deferred.resolve()

			return deferred.promise
		.then =>
			process.stdout.write "getting docker ip...\n".yellow
			return Q.denodeify(@_get_docker_iface_ip)(null)
		.then (ip) =>
			@docker_iface_ip = ip
			process.stdout.write "...#{ip}\n".green
			process.stdout.write "getting private ip...\n".yellow
			return Q.denodeify(@_get_private_ip)(null)
		.then (ip) =>
			process.stdout.write "...#{ip}\n".green

			deferred = Q.defer()

			process.stdout.write "starting containers...\n".yellow
			started = 0
			for ind in [1..@numContainers]
				Q.denodeify(@_docker_run)(@tag, @app_config, {docker: @docker_iface_ip, private: ip}, ["--restart=\"always\""])
				.then (id) =>
					return Q.denodeify(@_docker_inspect)(id, "")
				.then (inspect) =>
					process.stdout.write "\tid: #{inspect[0].Id}\n".green
					process.stdout.write "\tname: #{inspect[0].Name.replace('/', '')}\n".green
					process.stdout.write "\tip: #{inspect[0].NetworkSettings.IPAddress}\n".green
					process.stdout.write "\tports: #{util.inspect(inspect[0].NetworkSettings.Ports)}\n".green
					process.stdout.write "\tstate.running: #{inspect[0].State.Running}\n".green
					
					started++
					if started is @numContainers
						return deferred.resolve()
				.fail (err) =>
					return deferred.reject err

			return deferred.promise
		.then (id) =>
			process.stdout.write "...done!\n".green
			
			if @app_config.hipache
				@update_router = new @bifrost.strategies["update-router"] @bifrost, @server, [@app_folder]
				@update_router.connect()

			return Q.delay 2000
		.then =>
			imageIds = []
			for ind,id of @oldImageIds
				if id isnt @newImageId and imageIds.indexOf(id) is -1
					imageIds.push id

			@oldImageIds = imageIds

			if @oldContainerIds instanceof Array and @oldContainerIds.length > 0
				process.stdout.write "Removing old containers (#{@oldContainerIds.join(' ')})...\n".yellow
				Q.denodeify(@_docker_rm)(@oldContainerIds.join(" "), "")
				.then =>
					process.stdout.write "...removed containers!\n".green

					deferred = Q.defer()

					if @oldImageIds.length > 0
						process.stdout.write "Removing old images (#{@oldImageIds.join(' ')})...\n".yellow
						Q.denodeify(@_docker_rmi)(@oldImageIds.join(" "), "")
						.then =>
							process.stdout.write "...removed images!\n".green
							@connection.end()

							return deferred.resolve()
						.fail (err) =>
							return deferred.reject err
					else
						@connection.end()
						deferred.resolve()

					return deferred.promise
				.then =>
					if @app_config.hipache
						@update_router = new @bifrost.strategies["update-router"] @bifrost, @server, [@app_folder]
						@update_router.connect()
				.fail (err) =>
					throw err
			else if @oldImageIds.length > 0
				process.stdout.write "Removing old images (#{@oldImageIds.join(' ')})...\n".yellow
				Q.denodeify(@_docker_rmi)(@oldImageIds.join(" "), "")
				.then =>
					process.stdout.write "...removed images!\n".green
					@connection.end()

					if @app_config.hipache
						@update_router = new @bifrost.strategies["update-router"] @bifrost, @server, [@app_folder]
						@update_router.connect()
				.fail (err) =>
					throw err
			else
				@connection.end()
		.fail (err) =>
			console.error err.message.red
			@connection.end()

	# callback(err)
	_extract_tmp_tar: (tmp_tar, output, callback, opt_callback) =>
		if output
			mkdir = "&& mkdir -p #{output} "
			output = " -C #{output}"
		else
			mkdir = ""
			output = ""
		cmd = "cd /tmp #{mkdir}&& tar -xzvf #{tmp_tar}#{output} && rm -f #{tmp_tar}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect {code: code, signal: signal, stderr: output.stderr})

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