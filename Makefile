.PHONY: build
build:
	javac -classpath './lib/*' SendGetDocumentTypes.java

.PHONY: run
run:
	java -classpath '.:./lib/*' SendGetDocumentTypes
