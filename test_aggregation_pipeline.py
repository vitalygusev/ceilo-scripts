import argparse
import collections
import json
import pdb
import random
import time

import keystoneclient.v2_0

from ceilometerclient import client


METER_NAME = "cpu_util"

KEY_CREDS = {
    "auth_url": "http://172.16.49.199:5000/v2.0",
    "os_region_name": "RegionOne",
    "username": "admin",
    "password": "admin",
    "tenant_name": "admin",
    "timeout": 600
}

CEILO_CREDS = {
    "service_type": "metering",
    "endpoint_type": "publicURL"
}

TASKS = {}


def setup_tasks():
    key_cli = keystoneclient.v2_0.client.Client(**KEY_CREDS)
    endpoint = key_cli.service_catalog.url_for(**CEILO_CREDS)
    cl = client.get_client(2, ceilometer_url=endpoint,
                           os_auth_token=lambda: key_cli.auth_token,
                           timeout=600)
    resources = cl.resources.list()
    resource = random.choice(resources)
    while not resource.project_id or not resource.user_id:
        resource = random.choice(resources)

    TASKS["TASK 1"] = {}
    TASKS["TASK 2"] = dict(period=80)
    TASKS["TASK 3"] = dict(period=5000)
    TASKS["TASK 4"] = dict(period=180, q=[dict(field="project_id",
                                               value=resource.project_id),
                                          dict(field="user_id",
                                               value=resource.user_id)],
                           groupby=["resource_id"],)
    TASKS["TASK 5"] = dict(period=3600*24,
                           q=[dict(field="project_id",
                                   value=resource.project_id),
                              dict(field="user_id",
                                   value=resource.user_id)],
                           groupby=["resource_id"])
    TASKS["TASK 6"] = dict(groupby=["resource_id", "project_id", "user_id"])


def make_request(task):
    key_cli = keystoneclient.v2_0.client.Client(**KEY_CREDS)
    endpoint = key_cli.service_catalog.url_for(**CEILO_CREDS)
    cl = client.get_client(2, ceilometer_url=endpoint,
                           os_auth_token=lambda: key_cli.auth_token,
                           timeout=600)
    data = None
    status = "OK"
    start_time = time.time()
    try:
        data = cl.statistics.list(METER_NAME, **task)
    except Exception as e:
        print "FAIL %s" % pdb.set_trace()
        status = "FAIL"
    finally:
        delta_time = (time.time() - start_time) * 1000
        return delta_time, status, data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-n",
                        help="Count of task repeats",
                        default=10,
                        type=int,
                        dest="count")
    parser.add_argument("-o",
                        help="Output file",
                        default="/tmp/performance_result.raw",
                        dest="output")
    args = parser.parse_args()

    setup_tasks()
    task_data = {}
    with open(args.output, "w") as f:
        f.write("Test results\n")
    for name, task in sorted(TASKS.items()):
        print "Start %s" % name
        timings = []
        for _ in xrange(args.count):
            ts, status, data = make_request(task)
            if status == "OK":
                task_data[name] = data
                timings.append(ts)
            else:
                time.sleep(5)
        results = dict(objs=sum(stat.count
                                for stat in task_data[name]),
                       min=min(timings),
                       max=max(timings),
                       avg=sum(timings)/len(timings),
                       hmean=(args.count/sum(1/i for i in timings)),
                       med=list(sorted(timings))[args.count/2-1],
                       succ=(len(timings)/args.count) * 100)
        printlist = "Task %s\n" % name
        printlist += "\n".join("\t%s:\t%.0f" % (k, v)
                               for k, v in results.items())
        printlist += "\n\n"
        print printlist
        with open(args.output, "a") as f:
            f.write(printlist)

if __name__ == '__main__':
    main()
