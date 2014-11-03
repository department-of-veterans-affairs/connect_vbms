build:
	make -C src build

.PHONY: run
run:
	make -C src run

.PHONY: update
update:
	#git co origin/greg-java -- java/GetDocumentTypes.java
	#mv java/GetDocumentTypes.java src/
	git co origin/greg-java -- java/UploadDocumentWithAssociations.java
	mv java/UploadDocumentWithAssociations.java src/
	git rm -rf java
