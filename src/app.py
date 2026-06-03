"""
Database Deployment Readiness Checker - Flask Application

Exposes REST API endpoints for validating database deployment requests.
"""

from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from src.validator import validate_deployment_request

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    "ddrc_requests_total",
    "Total validation requests",
    ["endpoint", "status_code"],
)
VALIDATION_RESULTS = Counter(
    "ddrc_validation_results_total",
    "Validation results by status",
    ["result"],
)
REQUEST_LATENCY = Histogram(
    "ddrc_request_latency_seconds",
    "Request latency in seconds",
    ["endpoint"],
)


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    REQUEST_COUNT.labels(endpoint="/health", status_code=200).inc()
    return jsonify({"status": "healthy", "service": "ddrc"}), 200


@app.route("/validate", methods=["POST"])
def validate():
    """Validate a database deployment request."""
    with REQUEST_LATENCY.labels(endpoint="/validate").time():
        data = request.get_json()

        if not data:
            REQUEST_COUNT.labels(endpoint="/validate", status_code=400).inc()
            return jsonify({"error": "Request body must be JSON"}), 400

        result = validate_deployment_request(data)

        VALIDATION_RESULTS.labels(result=result["status"]).inc()
        REQUEST_COUNT.labels(endpoint="/validate", status_code=200).inc()

        return jsonify(result), 200


@app.route("/metrics", methods=["GET"])
def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
