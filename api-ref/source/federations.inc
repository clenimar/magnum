.. -*- rst -*-

===================
 Manage Federation 
===================

Lists, creates, shows details for, updates, and deletes Federation.

Create new federation
======================

.. rest_method:: POST /v1/federations

Create new federation.

Response Codes
--------------

.. rest_status_code:: success status.yaml

   - 202

.. rest_status_code:: error status.yaml

   - 400
   - 401
   - 403
   - 404

Request
-------

.. rest_parameters:: parameters.yaml

  - name: name
  - hostcluster_id: hostcluster_id
  - properties: properties

.. note::

   Request for creating federation is asynchronous.

Request Example
----------------

.. literalinclude:: samples/federation-create-req.json
   :language: javascript

Response
--------

.. rest_parameters:: parameters.yaml

  - X-Openstack-Request-Id: request_id
  - uuid: federation_id

Response Example
----------------

.. literalinclude:: samples/federation-create-resp.json
   :language: javascript

List all federations
=====================

.. rest_method:: GET /v1/federations

List all federations in Magnum.

Response Codes
--------------

.. rest_status_code:: success status.yaml

   - 200

.. rest_status_code:: error status.yaml

   - 401
   - 403

Response
--------

.. rest_parameters:: parameters.yaml

  - X-Openstack-Request-Id: request_id
  - federations: federation_list
  - status: status
  - uuid: federation_id
  - links: links
  - hostcluster_id: hostcluster_id
  - member_ids: member_ids
  - properties: properties
  - name: name

Response Example
----------------

.. literalinclude:: samples/federation-get-all-resp.json
   :language: javascript

Show details of a federation
=============================

.. rest_method:: GET /v1/federations/{federation_ident}

Get all information of a federation in Magnum.

Response Codes
--------------

.. rest_status_code:: success status.yaml

   - 200

.. rest_status_code:: error status.yaml

   - 401
   - 403
   - 404

Request
-------

.. rest_parameters:: parameters.yaml

  - federation_ident: federation_ident

Response
--------

.. rest_parameters:: parameters.yaml

  - X-Openstack-Request-Id: request_id
  - status: status
  - hostcluster_id: hostcluster_id
  - member_ids: member_ids
  - uuid: federation_id
  - links: links
  - created_at: created_at
  - updated_at: updated_at
  - status_reason: status_reason
  - properties: properties
  - name: name

Response Example
----------------

.. literalinclude:: samples/federation-get-one-resp.json
   :language: javascript

Delete a federation
====================

.. rest_method:: DELETE /v1/federations/{federation_ident}

Delete a federation.

Response Codes
--------------

.. rest_status_code:: success status.yaml

   - 204

.. rest_status_code:: error status.yaml

   - 401
   - 403
   - 404
   - 409

Request
-------

.. rest_parameters:: parameters.yaml

  - federation_ident: federation_ident

Response
--------

This request does not return anything in the response body.

.. rest_parameters:: parameters.yaml

  - X-Openstack-Request-Id: request_id

Add a member cluster (join)
============================

.. rest_method:: PATCH /v1/federation/{federation_ident}

Add a member cluster to the federation using ``add`` operation.

Response Codes
--------------

.. rest_status_code:: success status.yaml

   - 202

.. rest_status_code:: error status.yaml

   - 400
   - 401
   - 403
   - 404

Request
-------

.. rest_parameters:: parameters.yaml

  - federtion_ident: federation_ident
  - path: path
  - value: value
  - op: op

.. note::

   Request for adding a member cluster is asynchronous.

Request Example
----------------

.. literalinclude:: samples/federation-join-req.json
   :language: javascript

Response
--------

.. rest_parameters:: parameters.yaml

  - X-Openstack-Request-Id: request_id
  - uuid: federation_id

Remove a member cluster (unjoin)
=================================

.. rest_method:: PATCH /v1/federation/{federation_ident}

Remove a member cluster to the federation using ``remove`` operation.

Response Codes
--------------

.. rest_status_code:: success status.yaml

   - 202

.. rest_status_code:: error status.yaml

   - 400
   - 401
   - 403
   - 404

Request
-------

.. rest_parameters:: parameters.yaml

  - federtion_ident: federation_ident
  - path: path
  - value: value
  - op: op

.. note::

   Request for removing a member cluster is asynchronous.

Request Example
----------------

.. literalinclude:: samples/federation-unjoin-req.json
   :language: javascript

Response
--------

.. rest_parameters:: parameters.yaml

  - X-Openstack-Request-Id: request_id
  - uuid: federation_id
