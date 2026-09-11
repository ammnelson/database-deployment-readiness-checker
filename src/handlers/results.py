import json
import os
from datetime import datetime, timezone

import boto3

_table = None


def get_table():
    # created once per Lambda container, not per request
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    return _table


def put_result(request_id, request, result, source):
    # audit trail: one item per validation, keyed by request_id
    get_table().put_item(
        Item={
            "request_id": request_id,
            "status": result.get("status", "ERROR"),
            "request": json.dumps(request),
            "result": json.dumps(result),
            "source": source,
            "validated_at": datetime.now(timezone.utc).isoformat(),
        }
    )
