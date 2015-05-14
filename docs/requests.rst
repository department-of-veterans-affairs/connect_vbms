API Requests
============

This is a complete list of the requests that Connect VBMS supports.

``ListDocuments``
-----------------

.. code-block:: ruby

    VBMS::Requests::ListDocuments.new('<file number>')

``ListDocuments`` finds a list of all of the documents in an eFolder for a given
file.

Result
~~~~~~

An ``Array`` of ``VBMS::Document`` objects.

``FetchDocumentById``
---------------------

.. code-block:: ruby

    VBMS::Requests::FetchDocumentById.new('<document id>')

``FetchDocumentById`` gets the contents and details about a document, by its
identifier.

Result
~~~~~~

A ``VBMS::DocumentWithContent``.

``GetDocumentTypes``
--------------------

.. code-block:: ruby

    VBMS::Requests::GetDocumentTypes.new()

``GetDocumentTypes`` gets an ``Array`` of all the document types that VBMS
supports.

Result
~~~~~~

An ``Array`` of ``VBMS::DocumentType``.

Responses
=========

``VBMS::Document``
------------------

Attributes
~~~~~~~~~~

* ``document_id`` (``String``): a  unique identifier for the document.
* ``filename`` (``String``): the original filename of this document.
* ``doc_type`` (``String``): the id for this document type.
* ``source`` (``String``): where this document came from.
* ``received_at`` (``Date`` or ``nil``): when the VA received this document.

``VBMS::DocumentWithContent``
-----------------------------

Attributes
~~~~~~~~~~

* ``document`` (``VBMS::Document``)
* ``content`` (``String``): the contents of the file

``VBMS::DocumentType``
----------------------

Attributes
~~~~~~~~~~

* ``type_id`` (``String``)
* ``description`` (``String``): a human readable description of the document
  type.
