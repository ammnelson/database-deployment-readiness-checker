"""
Database Deployment Readiness Checker - Application Entry Point

Uses a Lambda-compatible handler structure for validation logic,
wrapped with a lightweight HTTP server for containerised deployment.
Designed to integrate directly with AWS Lambda and SQS in future phases.
"""

import json
from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from src.validator import validate_deployment_request

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    "ddrc_requests_total", "Total requests", ["endpoint", "status_code"]
)
VALIDATION_RESULTS = Counter(
    "ddrc_validation_results_total", "Validation results", ["result"]
)
REQUEST_LATENCY = Histogram(
    "ddrc_request_latency_seconds", "Request latency", ["endpoint"]
)


def lambda_handler(event, context=None):
    """
    AWS Lambda-compatible handler for validating deployment requests.

    Args:
        event: Dict containing the deployment request payload.
        context: Lambda context object (unused, for compatibility).

    Returns:
        Dict with statusCode and body containing validation result.
    """
    body = event.get("body")
    if isinstance(body, str):
        body = json.loads(body)
    elif body is None:
        body = event

    if not body:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Request body must be JSON"}),
        }

    result = validate_deployment_request(body)

    return {
        "statusCode": 200,
        "body": json.dumps(result),
    }


# HTTP wrapper routes for containerised deployment

@app.route("/health", methods=["GET"])
def health():
    REQUEST_COUNT.labels(endpoint="/health", status_code=200).inc()
    return jsonify({"status": "healthy", "service": "ddrc"}), 200


@app.route("/validate", methods=["POST"])
def validate():
    with REQUEST_LATENCY.labels(endpoint="/validate").time():
        event = {"body": request.get_json()}
        response = lambda_handler(event)
        result = json.loads(response["body"])

        VALIDATION_RESULTS.labels(result=result.get("status", "error")).inc()
        REQUEST_COUNT.labels(endpoint="/validate", status_code=response["statusCode"]).inc()

        return jsonify(result), response["statusCode"]


@app.route("/metrics", methods=["GET"])
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
