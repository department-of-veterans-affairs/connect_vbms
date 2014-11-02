.PHONY: build
build:
	javac -classpath './lib/*' SendGetDocumentTypes.java

.PHONY: run
run:
	java -classpath '.:./lib/*' SendGetDocumentTypes | ./run.rb

.PHONY: update
update:
	git co origin/greg-java -- java/SendGetDocumentTypes.java 
	mv java/SendGetDocumentTypes.java . 
	git rm -rf java
