"""ECS crash-loop counter.

Invoked by an EventBridge rule on ECS Task State Change events that are crashes
(essential container exited, or the task failed to start) in the prod cluster.
Each crash emits one data point on a custom metric; a CloudWatch alarm on the
5-minute sum flags a crash loop.
"""

import os

import boto3

cw = boto3.client("cloudwatch")
CLUSTER_NAME = os.environ["CLUSTER_NAME"]


def handler(_event, _context):
    cw.put_metric_data(
        Namespace="SaaS/ECS",
        MetricData=[
            {
                "MetricName": "TaskCrash",
                "Dimensions": [{"Name": "ClusterName", "Value": CLUSTER_NAME}],
                "Value": 1.0,
                "Unit": "Count",
            }
        ],
    )
