default:
	mdbook serve

build:
	-rm -r -f docs
	mdbook build
	-rm docs/.gitignore
	-rm -rf docs/.git

clean: