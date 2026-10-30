"""Secret-access notifier.

Invoked by a CloudWatch Logs subscription filter on the CloudTrail log group.
The subscription filter has already narrowed events to: non-SDK IAM users calling
secretsmanager:GetSecretValue. This function decodes each matched CloudTrail record
and publishes ONE SNS message with two representations:
  - "email": readable text for email subscribers.
  - "default": AWS Chatbot custom-notification JSON so it renders as a card in Slack.
    (Chatbot silently drops plain-text messages, so Slack needs this format.)
"""

import base64
import gzip
import json
import os

import boto3

sns = boto3.client("sns")
secretsmanager = boto3.client("secretsmanager")
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
ENVIRONMENT = os.environ.get("ENVIRONMENT", "prod")


def _belongs_to_env(secret_id):
    """True if the secret belongs to ENVIRONMENT.

    The account is shared across dev/stg/prod and the trail is account-wide, so
    scope alerts to this environment only. RDS-managed secrets are tagged
    Environment; tenant/provisioner secrets are untagged but name-prefixed
    (tenants/<env>_..., <env>/...). Fail OPEN (alert) if we cannot classify - a
    false alert is safer than missing a real prod secret read.
    """
    if not secret_id or secret_id == "unknown":
        return True
    try:
        meta = secretsmanager.describe_secret(SecretId=secret_id)
    except Exception:
        return True
    tags = {t.get("Key"): t.get("Value") for t in meta.get("Tags", [])}
    if tags.get("Environment"):
        return tags["Environment"] == ENVIRONMENT
    name = meta.get("Name", "") or ""
    return (
        name.startswith(f"tenants/{ENVIRONMENT}_")
        or f"/{ENVIRONMENT}/" in name
        or name.startswith(f"{ENVIRONMENT}/")
    )


def handler(event, _context):
    raw = base64.b64decode(event["awslogs"]["data"])
    payload = json.loads(gzip.decompress(raw))

    for entry in payload.get("logEvents", []):
        try:
            record = json.loads(entry["message"])
        except (ValueError, KeyError):
            continue

        identity = record.get("userIdentity", {})
        params = record.get("requestParameters") or {}
        secret_id = params.get("secretId", "unknown")

        # Only alert for THIS environment's secrets (dev/stg reads are ignored).
        if not _belongs_to_env(secret_id):
            continue

        who = identity.get("userName") or identity.get("arn", "unknown")

        fields = [
            ("User", who),
            ("ARN", identity.get("arn", "unknown")),
            ("Secret", params.get("secretId", "unknown")),
            ("Source IP", record.get("sourceIPAddress", "unknown")),
            ("User-agent", record.get("userAgent", "unknown")),
            ("Time", record.get("eventTime", "unknown")),
            ("Region", record.get("awsRegion", "unknown")),
            ("Account", record.get("recipientAccountId", "unknown")),
        ]

        # Plain text for email.
        email_text = "\n".join(
            ["SECURITY: a non-SDK IAM user read a Secrets Manager secret.", ""]
            + [f"{label}: {value}" for label, value in fields]
        )

        # AWS Chatbot custom-notification format for Slack (renders as a card).
        chatbot = {
            "version": "1.0",
            "source": "custom",
            "content": {
                "textType": "client-markdown",
                "title": f":rotating_light: [{ENVIRONMENT}] Human secret access: {who}",
                "description": "\n".join(
                    [f"*{label}:* {value}" for label, value in fields]
                ),
            },
        }

        sns.publish(
            TopicArn=TOPIC_ARN,
            Subject=f"[{ENVIRONMENT}] Human secret access: {who}"[:100],
            MessageStructure="json",
            Message=json.dumps({"default": json.dumps(chatbot), "email": email_text}),
        )
