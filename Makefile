.PHONY: build
build:
	make -C src build

.PHONY: docs
docs:
	make -C docs html
