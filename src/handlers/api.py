import json
import os
import uuid

import boto3

from src.handlers.results import put_result
from src.validator import validate_deployment_request

_sqs = None


def get_queue_url():
    return os.environ["QUEUE_URL"]


def sqs_client():
    global _sqs
    if _sqs is None:
        _sqs = boto3.client("sqs")
    return _sqs


def handler(event, context=None):
    # API Gateway front door: validate now, or enqueue when the toggle is on
    body = event.get("body")
    if isinstance(body, str):
        body = json.loads(body)

    if not body:
        return respond(400, {"error": "Request body must be JSON"})

    request_id = str(uuid.uuid4())

    if os.environ.get("ENABLE_SQS", "false").lower() == "true":
        # async path: hand the request to the queue and reply immediately
        print(json.dumps({"log": "request_queued", "request_id": request_id}))
        message = {"request_id": request_id, "request": body}
        sqs_client().send_message(
            QueueUrl=get_queue_url(), MessageBody=json.dumps(message)
        )
        return respond(202, {"request_id": request_id, "status": "QUEUED"})

    # sync path: validate inline and store the result
    result = validate_deployment_request(body)
    print(json.dumps({"log": "validated_sync", "request_id": request_id, "status": result.get("status")}))
    put_result(request_id, body, result, source="api-sync")
    return respond(200, {"request_id": request_id, **result})


def respond(status_code, payload):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }
