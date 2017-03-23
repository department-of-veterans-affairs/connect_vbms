VBMS eFolder Service Version 1.0 API Requests
=============================================

This is a list of the requests that Connect VBMS supports.

``FindDocumentSeriesReference``
-----------------

.. code-block:: ruby

    VBMS::Requests::FindDocumentSeriesReference.new('<file number>')

``FindDocumentSeriesReference`` finds a list of all of the documents in an eFolder for a given
file.

Result
~~~~~~

An ``Array`` of ``OpenStruct`` objects:

* ``document_id`` (``String``): a  unique identifier for the document.
* ``type_id`` (``String``): the id for this document type.
* ``type_description`` (``String``): the description for this document type.
* ``subject`` (``String``): subject of the document.
* ``source`` (``String``): where this document came from.
* ``mime_type`` (``String``): the MIME type of the document.
* ``received_at`` (``Date``): when the VA received this document.
* ``restricted`` (``Boolean``): whether the document is restricted or not.


``GetDocumentContent``
---------------------

.. code-block:: ruby

    VBMS::Requests::GetDocumentContent.new('<document id>')

``GetDocumentContent`` gets the contents and details about a document, by its
identifier.

Result
~~~~~~

A ``OpenStruct`` object:

* ``document_id`` (``String``): a  unique identifier for the document.
* ``content`` (``String``): content of the document.


``InitializeUpload``
----------------------------------

.. code-block:: ruby

    VBMS::Requests::InitializeUpload.new(
      '<content_hash>', '<filename>', '<file_number>', '<va_receive_date>',
      '<doc_type>', '<source>', '<subject>', '<new_mail>'
    )

``InitializeUpload`` sends document metadata and gets a token used in the second call ``UploadDocument``

Result
~~~~~~

A ``OpenStruct`` object:

* ``upload_token`` (``String``): upload token used in the second call ``UploadDocument``.


``UploadDocument``
----------------------------------

.. code-block:: ruby

    VBMS::Requests::UploadDocument.new('<upload_token>', '<filepath>')

``UploadDocument`` creates a new file in the Veteran's eFolder.


``ListTypeCategory``
--------------------

.. code-block:: ruby

    VBMS::Requests::ListTypeCategory.new()

``ListTypeCategory`` gets an ``Array`` of all the document types that VBMS
supports.

Result
~~~~~~

An ``OpenStruct`` object:

* ``type_id`` (``String``): document type id.
* ``description`` (``String``): description of the document type.


