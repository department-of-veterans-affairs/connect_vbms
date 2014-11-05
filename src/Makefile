SendGetDocumentTypes.class:
	javac -classpath '../lib/*' SendGetDocumentTypes.java

UploadDocumentWithAssociations.class:
	javac -classpath '../lib/*' UploadDocumentWithAssociations.java

DecryptMessage.class: DecryptMessage.java
	javac -classpath '../lib/*' DecryptMessage.java

.PHONY: build
build: SendGetDocumentTypes.class UploadDocumentWithAssociations.class DecryptMessage.class

.PHONY:run
run:
	java -classpath '.:../lib/*' UploadDocumentWithAssociations | ./run.rb

.PHONY:decrypt
decrypt: decrypt.class
	java -classpath '.:../lib/*' DecryptMessage
