default:
	mdbook serve

build:
	-rm -r -f docs
	mdbook build
	-rm docs/.gitignore
	-rm -rf docs/.git

cover:
	convert -resize 600x cover-full.png cover.jpg

clean: