"""Alarm formatter.

CloudWatch alarms publish their raw notification to the "raw" SNS topic. This
Lambda rewrites each into plain language (with the measured value, affected
resource, and a console link) and republishes to the clean topic (email + Slack),
so people get a readable, actionable message instead of the default card.
"""

import json
import os
import re

import boto3

sns = boto3.client("sns")
CLEAN_TOPIC_ARN = os.environ["CLEAN_TOPIC_ARN"]
ENVIRONMENT = os.environ.get("ENVIRONMENT", "prod")

_OPS = {
    "GreaterThanOrEqualToThreshold": "≥",
    "GreaterThanThreshold": ">",
    "LessThanThreshold": "<",
    "LessThanOrEqualToThreshold": "≤",
}


def _measured_value(reason):
    # NewStateReason contains "... [98.5 (23/07/26 13:00:00)] was ...".
    match = re.search(r"\[([-\d.eE]+)\s", reason or "")
    return match.group(1) if match else None


def handler(event, _context):
    for record in event.get("Records", []):
        try:
            alarm = json.loads(record["Sns"]["Message"])
        except (ValueError, KeyError):
            continue

        name = alarm.get("AlarmName", "alarm")
        description = alarm.get("AlarmDescription") or name
        state = alarm.get("NewStateValue", "ALARM")
        when = (alarm.get("StateChangeTime", "") or "")[:16].replace("T", " ")
        reason = alarm.get("NewStateReason", "")
        account = alarm.get("AWSAccountId", "")
        region = (alarm.get("AlarmArn", "").split(":") + [""] * 4)[3]

        trigger = alarm.get("Trigger", {}) or {}
        metric = trigger.get("MetricName", "")
        threshold = trigger.get("Threshold")
        op = _OPS.get(trigger.get("ComparisonOperator", ""), "")
        dims = trigger.get("Dimensions", []) or []
        resource = ", ".join(f"{d.get('name')}={d.get('value')}" for d in dims)
        value = _measured_value(reason)

        severity = "P1" if description.startswith("P1") else ("P2" if description.startswith("P2") else "")
        sentence = description.split(":", 1)[1].strip() if ":" in description else description
        console = (
            f"https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#alarmsV2:alarm/{name}"
            if region
            else ""
        )

        if state == "OK":
            title = f"\U0001f7e2 Resolved: {sentence}"
            lines = ["Good news - this is back to normal.", ""]
        else:
            emoji = "\U0001f534" if severity == "P1" else "\U0001f7e0"
            label = f"{severity} " if severity else ""
            title = f"{emoji} {label}ALERT: {sentence}"
            lines = [f"*What's wrong:* {sentence}"]

        if value is not None and threshold is not None:
            metric_suffix = f" · {metric}" if metric else ""
            lines.append(f"*Measured:* {value} (limit {op} {threshold}){metric_suffix}")
        if resource:
            lines.append(f"*Resource:* {resource}")
        lines.append(f"*Severity:* {severity or 'n/a'}")
        lines.append(f"*Environment:* {ENVIRONMENT}")
        lines.append(f"*Account / Region:* {account} / {region}")
        lines.append(f"*Since:* {when} UTC")
        lines.append(f"*Alarm:* {name}")
        if console:
            lines.append(f"*Open in CloudWatch:* {console}")

        card = {
            "version": "1.0",
            "source": "custom",
            "content": {"textType": "client-markdown", "title": title, "description": "\n".join(lines)},
        }
        email_text = "\n".join([title, ""] + [line.replace("*", "") for line in lines])

        sns.publish(
            TopicArn=CLEAN_TOPIC_ARN,
            Subject=title.encode("ascii", "ignore").decode().strip()[:100] or name,
            MessageStructure="json",
            Message=json.dumps({"default": json.dumps(card), "email": email_text}),
        )
