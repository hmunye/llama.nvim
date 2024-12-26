fmt:
	echo "===> Formatting"
	stylua lua/ plugin/ --config-path=.stylua.toml
	@echo "\n"

lint:
	echo "===> Linting"
	selene --config=.selene.toml lua/ plugin/
	@echo "\n"

test:
	echo "===> Testing"
	nvim --headless -c 'PlenaryBustedDirectory tests/'
	@echo "\n"

push-ready: fmt lint test
