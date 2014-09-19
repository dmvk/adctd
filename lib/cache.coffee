module.exports = (container, cache = {}) ->

	get: (name, overrides = {}) ->
		container.get name, overrides, null, cache

	register: ->
		container.register arguments...

	load: ->
		container.load arguments...
