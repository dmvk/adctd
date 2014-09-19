_ = require 'lodash'
fs = require 'fs'
path = require 'path'

module.exports = (basepath) ->

	extensions = Object.keys require('module')._extensions

	->

		factories = {}

		# reserved factory name

		loadDir = (dir, opts) ->

			# load coffee and js files from given path

			for file in fs.readdirSync dir
				if file.match /\.(js|coffee)$/
					loadFile path.join(dir, file), opts

		loadFile = (file, opts) ->

			# Remove ext

			module = file.replace /\.\w+$/, ''

			# Remove dashes from basename and camelcase result

			name = path.basename(module).replace /\-(\w)/g, (match, letter) -> letter.toUpperCase()

			# Register module

			container.register name, require(module), opts

		resolveArguments = (fn) ->

			# match argument list

			match = fn.toString().match /function.*?\(([\s\S]*?)\)/
			throw new Error "could not parse function arguments: #{fn.toString()}" unless match

			# create array of normalized argument names

			match[1].split(',').filter((v) -> v).map (str) -> str.trim()

		resolveCacheFlag = (name) ->

			# if any of factory's dependencies has cache flag set to false - inherit it

			factory = factories[name]
			throw new Error "Dependency '#{name}' does not exist" unless factory

			return false if factory.opts.cache is false

			if factory.dependencies.length > 0
				for dependency in factory.dependencies
					return false unless resolveCacheFlag dependency

			true

		# PUBLIC INTERFACE

		container =

			get: (name, overrides = {}, visited = [], cache = {}) ->

				# check for circular dependencies

				throw new Error "Circular dependency - #{name}" if name in visited
				visited.push name

				# try to retrieve factory

				factory = factories[name]
				throw new Error "Dependency '#{name}' does not exist" unless factory

				# resolve if an instance should be cached

				factory.opts.cache = resolveCacheFlag name unless factory.opts.cache?

				storeInstance = _.isEmpty(overrides) and factory.opts.cache

				# instance is stored just in "per-request" cache - return

				return cache[name] if name of cache

				# instance already created - return

				return factory.instance if factory.instance and storeInstance

				# resolve factory arguments

				args = factory.dependencies.map (dependency) =>
					return overrides[dependency] if dependency of overrides
					@get dependency, overrides, _.clone(visited), cache

				# create instance

				instance = factory.fn args...

				# store instance in right cache

				if storeInstance
					factory.instance = instance
				else
					cache[name] = instance

				instance

			getByTag: (tag) ->
				instances = {}
				instances[k] = @get k for k, v of factories when tag in v.opts.tags
				instances

			register: (name, fn, opts = {}) ->

				throw new Error 'Unable to register null function' unless fn

				# throw exception if service already exists

				throw new Error "Service '#{name}' is already registered" if name of factories

				# resolve service's options

				opts = _.extend cache: null, tags: [], opts

				# store service for later

				if _.isFunction fn
					factories[name] =
						fn: fn
						dependencies: resolveArguments fn
						opts: opts
				else
					factories[name] =
						fn: -> fn
						dependencies: []
						opts: opts

			load: (file, opts = {}) ->

				# resolve absolute file path

				possibleFiles = [
					file
					path.join basepath, file
				]

				for e in extensions
					possibleFiles.push file + e
					possibleFiles.push path.join basepath, file + e

				for possibleFile in possibleFiles
					if fs.existsSync possibleFile
						realpath = fs.realpathSync possibleFile
						break

				throw new Error "Unable to load file: #{file}" if typeof realpath is 'undefined'

				# load particular file or directory

				if fs.statSync(realpath).isDirectory()
					loadDir realpath, opts
				else
					loadFile realpath, opts

			# do not use unless you know what you are doing

			override: (name) ->
				delete factories[name] if name of factories
				@register arguments...

		# register itself as a service

		container.register 'container', container

		container
