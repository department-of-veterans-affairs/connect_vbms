EncryptSOAPDocument.class: main/java/EncryptSOAPDocument.java
	javac -classpath '../lib/*' -d ../classes main/java/EncryptSOAPDocument.java

DecryptMessage.class: main/java/DecryptMessage.java
	javac -classpath '../lib/*' -d ../classes main/java/DecryptMessage.java

.PHONY: build
build: EncryptSOAPDocument.class DecryptMessage.class

.PHONY:run
run:
	java -classpath '../classes:../lib/*:../lib' EncryptSOAPDocument

.PHONY:decrypt
decrypt: DecryptMessage.class
	# Decrypt fails... but run decrypt_hack to pull the message out of the log
	java -classpath '../classes:../lib/*:../lib' DecryptMessage
	./decrypt_hack.rb
