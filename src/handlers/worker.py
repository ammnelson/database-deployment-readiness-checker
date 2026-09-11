import json

from src.handlers.results import put_result
from src.validator import validate_deployment_request


def handler(event, context=None):
    # SQS back door: each invocation carries a batch of queued messages
    for record in event["Records"]:
        message = json.loads(record["body"])
        request_id = message["request_id"]
        request = message["request"]

        result = validate_deployment_request(request)
        put_result(request_id, request, result, source="worker-sqs")

    return {"processed": len(event["Records"])}
