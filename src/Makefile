SendGetDocumentTypes.class:
	javac -classpath '../lib/*' SendGetDocumentTypes.java

UploadDocumentWithAssociations.class:
	javac -classpath '../lib/*' UploadDocumentWithAssociations.java

decrypt.class: decrypt.java
	javac -classpath '../lib/*' decrypt.java

.PHONY: build
build: SendGetDocumentTypes.class UploadDocumentWithAssociations.class decrypt.class

.PHONY:run
run:
	#java -classpath '.:../lib/*' SendGetDocumentTypes | ./run.rb
	#java -classpath '.:../lib/*' UploadDocumentWithAssociations | ./run.rb

.PHONY:decrypt
decrypt: decrypt.class
	java -classpath '.:../lib/*' decrypt
