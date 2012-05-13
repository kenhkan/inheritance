build-ti:
	@rm -rf build
	@make build
	@echo "_ = require(\"lib/underscore\");\nowl = require(\"lib/deep_copy\");\n" | cat - build/inherit.js > /tmp/out && cp /tmp/out build/inherit.js

build-node:
	@rm -rf build
	@make build
	@echo "_ = require(\"./underscore\");\nowl = require(\"./deep_copy\");\n" | cat - build/inherit.js > /tmp/out && cp /tmp/out build/inherit.js

build:
	@mkdir build
	@cp lib/underscore.js build
	@cp lib/deep_copy.js build
	@cp inherit.js build

test:
	@rm -rf build
	@make build-node
	@jasmine-node --coffee spec
