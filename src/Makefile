GetDocumentTypes.class:
	javac -classpath '../lib/*' GetDocumentTypes.java

UploadDocumentWithAssociations.class:
	javac -classpath '../lib/*' UploadDocumentWithAssociations.java

DecryptMessage.class: DecryptMessage.java
	javac -classpath '../lib/*' DecryptMessage.java

.PHONY: build
build: GetDocumentTypes.class UploadDocumentWithAssociations.class DecryptMessage.class

.PHONY:run
run:
	java -classpath '.:../lib/*' UploadDocumentWithAssociations | ./run.rb

.PHONY:decrypt
decrypt: DecryptMessage.class
	# Decrypt fails... but run decrypt_hack to pull the message out of the log
	-java -classpath '.:../lib/*' DecryptMessage
	./decrypt_hack.rb
