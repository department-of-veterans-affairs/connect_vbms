.PHONY:run
run:
	#java -classpath '.:../lib/*' SendGetDocumentTypes | ./run.rb
	java -classpath '.:../lib/*' UploadDocumentWithAssociations | ./run.rb

.PHONY: show
show:
	#javac -classpath '../lib/*' SendPdf.java && java -classpath '.:../lib/*' SendPdf | xmllint -format - | less
	#javac -classpath '../lib/*' UploadDocumentWithAssociations.java && java -classpath '.:../lib/*' UploadDocumentWithAssociations | xmllint -format - | less
	javac -classpath '../lib/*' UploadDocumentWithAssociations.java && java -classpath '.:../lib/*' UploadDocumentWithAssociations
