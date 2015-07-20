Welcome to Connect VBMS
=======================

Connect VBMS is an SDK for integrating with VBMS from Ruby.

To get started, you'll first need to get credentials from the VBMS team.
You'll also need to make sure you have ``javac`` installed (version 1.7 or higher), and run
``rake`` in the root of the Connect VBMS repo to build a gem in the ``pkg`` dir.

Once you have credentials for VBMS, you can dive in:

.. code-block:: ruby

    require 'vbms'

    client = VBMS::Client.new(
        '<endpoint URL for the environment you want to access>',
        '<path to key store>',
        '<path to SAML XML token>',
        '<path to key, or nil>',
        '<password for key store>',
        '<path to CA certificate, or nil>',
        '<path to client certificate, or nil>',
    )

Now you can issue a request, to list the contents of an eFolder:

.. code-block:: ruby

    request = VBMS::Requests::ListDocuments.new("<file number>")

    result = client.send(request)

Connect VBMS works by creating request objects, which are pure-data objects to
represent the set of parameters an API call takes. These request objects are
then passed to the client for execution.

For ``ListDocuments``, the result is a list of ``VBMS::Document`` objects. For
full details on ``ListDocuments`` and all the other API requests, consult the
:doc:`API requests documentation <requests>`.

Contents
--------

.. toctree::
    :maxdepth: 2

    requests
