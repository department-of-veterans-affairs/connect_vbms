SendGetDocumentTypes.class:
	javac -classpath '../lib/*' SendGetDocumentTypes.java

UploadDocumentWithAssociations.class:
	javac -classpath '../lib/*' UploadDocumentWithAssociations.java

decrypt.class:
	javac -classpath '../lib/*' decrypt.java

.PHONY: build
build: SendGetDocumentTypes.class UploadDocumentWithAssociations.class decrypt.class

.PHONY:run
run:
	#java -classpath '.:../lib/*' SendGetDocumentTypes | ./run.rb
	#java -classpath '.:../lib/*' UploadDocumentWithAssociations | ./run.rb
	java -classpath '.:../lib/*' decrypt

.PHONY: show
show:
	#javac -classpath '../lib/*' SendPdf.java && java -classpath '.:../lib/*' SendPdf | xmllint -format - | less
	#javac -classpath '../lib/*' UploadDocumentWithAssociations.java && java -classpath '.:../lib/*' UploadDocumentWithAssociations | xmllint -format - | less
	javac -classpath '../lib/*' UploadDocumentWithAssociations.java && java -classpath '.:../lib/*' UploadDocumentWithAssociations
