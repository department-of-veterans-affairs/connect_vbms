.PHONY: build
build:
	javac -classpath './lib/*' -d build src/SendGetDocumentTypes.java
	cp src/run.rb build/

.PHONY: run
run:
	make -C src run

.PHONY: update
update:
	git co origin/greg-java -- java/SendGetDocumentTypes.java 
	mv java/SendGetDocumentTypes.java . 
	git rm -rf java
