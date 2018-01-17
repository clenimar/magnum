# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

from oslo_log import log as logging
import six

from magnum.common import profiler
import magnum.conf
from magnum.drivers.common import driver
from magnum import objects
from magnum.objects import fields

CONF = magnum.conf.CONF

LOG = logging.getLogger(__name__)


@profiler.trace_cls("rpc")
class Handler(object):

    def __init__(self):
        super(Handler, self).__init__()

    # Federation operations.
    # Please note they are all performed in the hostcluster.

    def federation_create(self, context, federation, create_timeout):
        LOG.debug('federation_heat federation_create')

        federation.status = fields.FederationStatus.CREATE_IN_PROGRESS
        federation.status_reason = None
        federation.create()

        try:
            # Get the hostcluster driver.
            hostcluster = objects.Cluster.get(context,
                                              federation.hostcluster_id)
            host_driver = driver.Driver.get_driver_for_cluster(context,
                                                               hostcluster)
            host_driver.create_federation(context, federation, create_timeout)
            federation.save()

        # TODO(clenimar): Improve exception handling.
        except Exception as e:
            federation.status = fields.FederationStatus.CREATE_FAILED
            federation.status_reason = six.text_type(e)
            federation.save()
            raise

        return federation

    def federation_update(self, context, federation, rollback=False):
        LOG.debug('federation_heat federation_update')

        delta = federation.obj_what_changed()
        if not delta:
            return federation

        try:
            # Get the hostcluster driver.
            hostcluster = objects.Cluster.get(context,
                                              federation.hostcluster_id)
            host_driver = driver.Driver.get_driver_for_cluster(context,
                                                               hostcluster)
            # Perform the update.
            host_driver.update_federation(context, federation, rollback)
            federation.status = fields.FederationStatus.UPDATE_IN_PROGRESS
            federation.status_reason = None

        # TODO(clenimar): Improve exception handling.
        except Exception as e:
            federation.status = fields.FederationStatus.UPDATE_FAILED
            federation.status_reason = six.text_type(e)
            federation.save()
            raise

        federation.save()
        return federation

    def federation_delete(self, context, uuid):
        LOG.debug('federation_conductor federation_delete')

        federation = objects.Federation.get(context, uuid)

        try:
            # Get the hostcluster driver.
            hostcluster = objects.Cluster.get(context,
                                              federation.hostcluster_id)
            host_driver = driver.Driver.get_driver_for_cluster(context,
                                                               hostcluster)
            # Delete the federation.
            host_driver.delete_federation(context, federation)
            federation.status = fields.FederationStatus.DELETE_IN_PROGRESS
            federation.status_reason = None

        # TODO(clenimar): Improve exception handling.
        except Exception as e:
            federation.status = fields.FederationStatus.DELETE_FAILED
            federation.status_reason = six.text_type(e)
            federation.save()
            raise

        federation.save()
        return None
