SOAPUI=/Applications/SoapUI-5.0.0.app/Contents/java/app/lib

build:
	javac -classpath ./lib/wss4j-1.6.7.jar SendGetDocumentTypes.java

run:
	java -cp .:$(SOAPUI)/* SendGetDocumentTypes
