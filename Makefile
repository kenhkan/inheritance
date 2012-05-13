build:
	@mkdir build
	@cp lib/underscore.js build
	@cp lib/deep_copy.js build
	@coffee -o build -cb inherit.coffee
