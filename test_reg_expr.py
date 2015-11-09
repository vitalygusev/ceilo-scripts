import time

import unittest

import keystoneclient
import novaclient.client
import ceilometerclient.v2.client


URL = 'http://192.168.0.2:5000/v2.0/'

alarm_name = "reg_expr"
alarm_body = {'meter_name': 'image', 'threshold': '0.9', 'name': alarm_name,
              'period': '10', 'statistic': 'avg', 'comparison_operator': 'lt'}


class TestRegExpr(unittest.TestCase):

    @staticmethod
    def wait_to_status(cli, obj_id, expected_status='active'):
        timeout = 5 * 60
        start = int(time.time())
        status = cli.get(obj_id).status.lower()
        while status != expected_status:
            if status.lower() in ["error"]:
                raise StandardError("Object has error state.")
            time.sleep(10)
            status = cli.get(obj_id).status.lower()
            if int(time.time()) - start >= timeout:
                raise RuntimeError(
                    "Object has {} state after 5 minutes, but expected "
                    "status:{}".format(status, expected_status))

    @classmethod
    def setUpClass(cls):
        keystone = keystoneclient.v2_0.client.Client(
            username='admin', password='admin',
            tenant_name='admin', auth_url=URL)
        c_endpoint = keystone.service_catalog.url_for(
            service_type='metering', endpoint_type='internalURL')
        cls.nova = novaclient.client.Client(
            '2', 'admin', 'admin', 'admin', URL, service_type='compute',
            no_cache=True)
        cls.ceilo = ceilometerclient.v2.Client(
            endpoint=c_endpoint, token=keystone.auth_token)
        cls.alarm = cls.ceilo.alarms.create(**alarm_body)
        flavor = [flavor for flavor in cls.nova.flavors.list()
                  if flavor.name == "m1.micro"]
        image = [image for image in cls.nova.images.list()
                 if image.name == "TestVM"]
        net_id = [net.id for net in cls.nova.networks.list()
                  if net.label == "net04"]
        server_body = {"flavor": flavor[0], "image": image[0],
                       "name": "test-server", "nics": [{"net-id": net_id[0]}]}
        cls.server = cls.nova.servers.create(**server_body)

    @classmethod
    def tearDownClass(cls):
        if cls.alarm:
            cls.ceilo.alarms.delete(cls.alarm.id)
        if cls.server:
            cls.nova.servers.delete(cls.server.id)

    def test_query_alarms(self):
        part = self.alarm.alarm_id.split("-")[1]
        q = "{\"=~\": {\"alarm_id\": \"{part}\"}}".replace("{part}", part)
        query_list = self.ceilo.query_alarms.query(q)
        self.assertEqual(1, len(query_list))

    def test_query_alarms_history(self):
        part = self.alarm.alarm_id.split("-")[1]
        q = "{\"=~\": {\"alarm_id\": \"{part}\"}}".replace("{part}", part)
        query_list_history = self.ceilo.query_alarm_history.query(q)
        self.assertNotEqual(0, len(query_list_history))

    def test_query_samples(self):
        self.wait_to_status(self.nova.servers, self.server.id)
        part = self.server.id.split("-")[1]
        q = "{\"=~\": {\"resource_id\": \"{part}\"}}".replace("{part}", part)
        query_list = self.ceilo.query_samples.query(q)
        self.assertNotEqual(0, len(query_list))


suite = unittest.TestLoader().loadTestsFromTestCase(TestRegExpr)
unittest.TextTestRunner(verbosity=2).run(suite)

