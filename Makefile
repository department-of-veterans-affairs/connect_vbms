.PHONY: build
build:
	javac -classpath './lib/*' src/SendGetDocumentTypes.java

.PHONY: run
run:
	make -C src run

.PHONY: update
update:
	git co origin/greg-java -- java/SendGetDocumentTypes.java 
	mv java/SendGetDocumentTypes.java . 
	git rm -rf java
