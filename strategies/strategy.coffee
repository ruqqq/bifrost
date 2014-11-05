Connection = require "ssh2"
util = require "util"
fs = require "fs"
YAML = require "yamljs"

class Strategy
	strategy_name: "default"

	constructor: (@bifrost, @server, @argv) ->
		@app_folder = process.cwd()
		@app_folder = fs.realpathSync @app_folder

		try
			@app_config = YAML.load @app_folder + "/" + "bifrost.yml"
		catch e
			console.error "Please specify a valid folder with a bifrost.yml."
			process.exit 1

		@app_name = @app_config.name

		if !@app_name
			console.error "Please provide a valid name in bifrost.yml"
			process.exit 1

		if !@app_config.appFolder
			@app_config.appFolder = ""

		@connection = new Connection()

		@connection.on "ready", =>
			@onSSHConnected()
			@execute()

		@connection.on "error", (err) =>
			@onSSHError err

		@connection.on "end", =>
			@onSSHEnded()

		@connection.on "close", =>
			@onSSHClosed()

		process.on "SIGINT", =>
			if @connection
				if @_second_sigint
					process.exit(0)
				else
					@connection.end()

			@_second_sigint = true

	@help: () =>
		return "[--host BIFROST_HOST]"

	connect: =>
		auth =
			host: @server.host
			port: @server.port or 22
			username: @server.username or "root"

		if @server.key_file
			auth.privateKey = require("fs").readFileSync("#{@server.key_file}")
		else
			auth.password = @server.password

		console.log "connecting to #{@server.name} (#{@server.host})...".cyan
		@connection.connect auth

	onSSHConnected: =>
		console.log "...connected!".cyan

	onSSHError: (err) =>
		console.trace err

	onSSHEnded: =>
		#console.log "connection ended."

	onSSHClosed: =>
		console.log "Closed connection to #{@server.name} (#{@server.host}).".cyan

	execute: =>
		@connection.exec "uptime", (err, stream) =>
			stream.on "data", (data, extended) =>
				if extended isnt "stderr"
					extended = "stdout"
				console.log "#{extended}: #{data}".cyan

			stream.on "end", () =>
				console.log "[exec:end]".cyan

			stream.on "close", () =>
				console.log "[exec:close]".cyan

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				console.log "[exec:exit] #{code} - #{signal}".cyan
				@connection.end()

	shell: () =>
		@connection.shell (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout
				else if stderr
					process.stderr.write stderr

			stream.on "end", () =>
				console.log "[shell:end]".cyan

			stream.on "close", () =>
				console.log "[shell:close]".cyan

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				console.log "[shell:exit] #{code} - #{signal}".cyan

			process.stdin.on 'readable', (chunk) =>
				chunk = process.stdin.read()
				if chunk isnt null
					stream.write chunk

	# opt_callback(stderr, stdout)
	_attachDefaultCallbackToStream: (stream, output, opt_callback) =>
		output.stdout = ""
		output.stderr = ""

		stream.on "data", (data) =>
			if data
				output.stdout += data.toString()
				if opt_callback then opt_callback null, data.toString()
		stream.stderr.on "data", (data) =>
			if data
				output.stderr += data.toString()
				if opt_callback then opt_callback data.toString(), null

		#stream.on "end", () =>
		#	console.log "[exec:end]"

		#stream.on "close", () =>
		#	console.log "[exec:close]"

		stream.on "exit", (code, signal) =>
			#console.log "[exec:exit] #{code} - #{signal}"

		# callback(err)

	# callback(err)
	_copy: (src, dest, callback) =>
		cmd = "cp -R #{src} #{dest}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_rm: (file, callback) =>
		cmd = "rm -rf #{file}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))


	_escapeshell: (cmd) =>
		return cmd.replace(/(["'$`\\])/g,'\\$1')

	# callback(err)
	_docker_start_stop_restart: (start_stop_restart, opt, container_id, callback) =>
		cmd = "docker #{start_stop_restart} #{opt} #{container_id}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_docker_list: (name, callback) =>
		cmd = "docker ps -a | grep \" #{name}:\""
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, ids)
	_docker_get_ids_from_appname: (name, callback) =>
		cmd = "docker ps -a | grep \" #{name}:\" | awk '{print $1}'"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					ids = output.stdout.split("\n")
					ids.splice ids.length-1, 1
					if callback then return callback null, ids
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, ids)
	_docker_get_image_tags_from_appname: (name, callback) =>
		cmd = "docker images | grep \"^#{name} \" | awk '{print $2}'"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					tags = output.stdout.split("\n")
					tags.splice ids.length-1, 1
					if callback then return callback null, tags
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, ids)
	_docker_get_image_id_from_appname: (name, callback) =>
		cmd = "docker images | grep \"^#{name} \" | awk '{print $3}'"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					ids = output.stdout.split("\n")
					ids.splice ids.length-1, 1
					if callback then return callback null, ids
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_docker_build: (tag, name, opt, callback, opt_callback) =>
		cmd = "cd /tmp/#{name} && docker build -t #{tag} #{opt} . && rm -rf /tmp/#{name}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, id)
	# TODO: Add more options
	_docker_run: (tag, config, ips, ext_opt, callback) =>
		opt = []

		cmd = ""
		if config.cmd
			cmd = '"' + @_escapeshell(config.cmd) + '"'

		if config.cpu
			opt.push "-c"
			opt.push config.cpu

		if config.entrypoint
			opt.push "--entrypoint=\"#{@_escapeshell(config.entrypoint)}\""
		
		if config.memory
			opt.push "-m"
			opt.push config.memory

		if config.environment and config.environment instanceof Object
			for key,val of config.environment
				opt.push "-e"
				opt.push "#{@_escapeshell(key)}=#{@_escapeshell(val)}"
		
		mkdirs = []
		if config.volumes and config.volumes instanceof Array
			for ind,vol of config.volumes
				if vol.host and vol.container
					mkdirs.push "mkdir -p \"#{@_escapeshell(vol.host)}\""
					opt.push "-v"
					opt.push "#{vol.host}:#{vol.container}"
				else if vol
					opt.push "-v"
					opt.push "#{vol}"

		if config.volumesFrom and config.volumesFrom instanceof Array
			for ind,vol of config.volumesFrom
				if vol.host and vol.container
					opt.push "--volumes-from"
					opt.push vol

		if config.configFolder
			opt.push "-v"
			opt.push "/root/app_configs/#{config.name}:#{config.configFolder}"

		if config.ports and config.ports instanceof Array
			for ind,port of config.ports
				opt.push "-p"
				port = port.replace "{DOCKER_IFACE}", ips.docker
				if port.indexOf("{PRIVATE_IFACE}") > -1 and !ips.private
					throw new Error("Error: bifrost.yml specified {PRIVATE_IFACE} but docker host has no private interface.")
				if ips.private
					port = port.replace "{PRIVATE_IFACE}", ips.private
				opt.push port

		if config.links and config.links instanceof Array
			for ind,link of config.links
				if link.container and link.alias
					opt.push "--link"
					opt.push "#{link.container}:#{link.alias}"
				else if link
					opt.push "--link"
					opt.push "#{link}"

		if !tag
			tag = config.name

		mkdir = ""
		if mkdirs.length > 0
			mkdir = mkdirs.join " && "
			mkdir += " && "

		cmd = "#{mkdir}docker run -d #{opt.join(' ')} #{ext_opt} #{tag} #{cmd}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback null, output.stdout.trim()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, inspect)
	_docker_inspect: (container_id, opt, callback) =>
		cmd = "docker inspect #{opt} #{container_id}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					inspect = {}
					try
						inspect = JSON.parse output.stdout
					catch e
						if callback then return callback e
					
					if callback then return callback null, inspect
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, inspect)
	_docker_logs: (container_id, opt, opt_callback, callback) =>
		cmd = "docker logs -f -t #{opt} #{container_id}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_docker_rm: (container_id, opt, callback) =>
		cmd = "docker stop #{container_id} && sleep 3 && docker rm #{opt} #{container_id}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_docker_clean: (callback) =>
		cmd = "docker stop $(docker ps -a -q) && sleep 3 && docker rm $(docker ps -a -q) && sleep 3 && docker rmi $(docker images -a -q)"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_docker_trim: (callback) =>
		cmd = "docker images -f dangling=true -q | xargs docker rmi"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err)
	_docker_rmi: (image_id, opt, callback) =>
		cmd = "docker rmi #{opt} #{image_id}"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if callback then return callback()
				else
					if callback then return callback new Error(util.inspect({code: code, signal: signal, stdout: output.stdout, stderr: output.stderr}))

	# callback(err, ip)
	_get_docker_iface_ip: (iface, callback) =>
		if !iface
			iface = "docker0"
		cmd = "ip addr show #{iface} | grep inet | grep #{iface} | awk '{print $2}' | awk -F '/' '{print $1}'"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if output.stdout
						output.stdout = output.stdout.replace("\n", "").trim()
					if callback then return callback null, output.stdout
				else
					if callback then return callback new Error util.inspect({code: code, signal: signal, stderr: output.stderr})

	# callback(err, ip)
	_get_private_ip: (iface, callback) =>
		if !iface
			iface = "eth0"
		cmd = "ip addr show #{iface} | grep 192 | awk '{print $2}' | awk -F '/' '{print $1}'"
		#console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, null

			code = null
			signal = null
			stream.on "exit", (c, s) =>
				code = c
				signal = s
			stream.on "close", =>
				if code is 0
					if output.stdout
						output.stdout = output.stdout.replace("\n", "").trim()
					if callback then return callback null, output.stdout
				else
					if callback then return callback new Error util.inspect({code: code, signal: signal, stderr: output.stderr})

module.exports = Strategy