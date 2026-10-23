import json

from src.handlers.results import put_result
from src.validator import validate_deployment_request


def handler(event, context=None):
    # SQS back door: each invocation carries a batch of queued messages
    processed = 0
    skipped = 0
    for record in event["Records"]:
        try:
            message = json.loads(record["body"])
            request_id = message["request_id"]
            request = message["request"]
        except (json.JSONDecodeError, KeyError, TypeError) as exc:
            # Malformed message: log and skip rather than crash the whole batch
            print(json.dumps({"log": "malformed_message_skipped", "message_id": record.get("messageId"), "error": str(exc)}))
            skipped += 1
            continue

        result = validate_deployment_request(request)
        print(json.dumps({"log": "validated_worker", "request_id": request_id, "status": result.get("status")}))
        put_result(request_id, request, result, source="worker-sqs")
        processed += 1

    return {"processed": processed, "skipped": skipped}
