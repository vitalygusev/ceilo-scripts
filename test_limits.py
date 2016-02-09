import ceilometerclient.v2.client
import keystoneclient
import unittest


URL = 'http://192.168.0.2:5000/v2.0/'


class TestMandatoryLimits(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        keystone = keystoneclient.v2_0.client.Client(
            username='admin', password='admin',
            tenant_name='admin', auth_url=URL)
        c_endpoint = keystone.service_catalog.url_for(
            service_type='metering', endpoint_type='internalURL')
        cls.ceilo = ceilometerclient.v2.Client(
            endpoint=c_endpoint, token=keystone.auth_token)

    def test_meter_list(self):
        meter_list = self.ceilo.meters.list()
        self.assertEqual(100, len(meter_list))

    def test_resource_list(self):
        resource_list = self.ceilo.resources.list()
        self.assertEqual(100, len(resource_list))

    def test_samples_list(self):
        sample_list = self.ceilo.samples.list()
        self.assertEqual(100, len(sample_list))

    def test_event_list(self):
        event_list = self.ceilo.events.list()
        self.assertEqual(100, len(event_list))


suite = unittest.TestLoader().loadTestsFromTestCase(TestMandatoryLimits)
unittest.TextTestRunner(verbosity=2).run(suite)

