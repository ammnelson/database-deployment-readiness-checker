"""
Database Deployment Readiness Checker - Core Validation Logic

Validates deployment requests for database services against predefined
readiness and compliance rules.
"""

import re

#approved services and their valid engine versions
APPROVED_SERVICES = {
    "aurora-mysql": ["3.04", "3.05", "3.06", "3.07"],
    "aurora-postgresql": ["14.9", "15.4", "15.5", "16.1"],
    "rds-mysql": ["8.0", "8.4"],
    "rds-postgresql": ["14.9", "15.4", "16.1"],
    "rds-oracle": ["19.0", "21.0"],
    "rds-sqlserver": ["2019", "2022"],
    "rds-mariadb": ["10.6", "10.11", "11.4"],
    "elasticache-redis": ["7.0", "7.1"],
    "elasticache-memcached": ["1.6"],
    "documentdb": ["5.0", "6.0"],
    "redshift": ["1.0"],
}

# Valid instance class prefixes
VALID_INSTANCE_CLASSES = [
    "db.r5", "db.r6g", "db.r6i", "db.r7g",
    "db.m5", "db.m6g", "db.m6i", "db.m7g",
    "db.t3", "db.t4g",
    "cache.r6g", "cache.r7g", "cache.m6g", "cache.m7g",
    "dc2.", "ra3.", "ds2.",
]

#deprecated configurations that should be flagged
DEPRECATED_CONFIGS = [
    "db.r4", "db.m4", "db.t2", "cache.r5", "cache.m5", "dc1.",
]

#required fields for a valid deployment request
REQUIRED_FIELDS = [
    "service_name",
    "engine_version",
    "instance_class",
    "region",
    "maintenance_window",
    "requester",
]

MAINTENANCE_WINDOW_PATTERN = re.compile(
    r"^(mon|tue|wed|thu|fri|sat|sun):\d{2}:\d{2}-(mon|tue|wed|thu|fri|sat|sun):\d{2}:\d{2}$",
    re.IGNORECASE,
)


def validate_deployment_request(request: dict) -> dict:
    reasons = []

    #check for missing required fields
    missing_fields = [f for f in REQUIRED_FIELDS if not request.get(f)]
    if missing_fields:
        return {
            "status": "INCOMPLETE",
            "reasons": [f"Missing required field: {f}" for f in missing_fields],
        }

    service_name = request["service_name"].lower().strip()
    engine_version = request["engine_version"].strip()
    instance_class = request["instance_class"].lower().strip()
    maintenance_window = request["maintenance_window"].strip()

    #validate service name
    if service_name not in APPROVED_SERVICES:
        reasons.append(f"Invalid service name: {service_name}")

    #validate engine version
    if service_name in APPROVED_SERVICES:
        approved_versions = APPROVED_SERVICES[service_name]
        if not any(engine_version.startswith(v) for v in approved_versions):
            reasons.append(
                f"Engine version {engine_version} not approved for {service_name}. "
                f"Approved: {approved_versions}"
            )

    #validate instance class
    if not any(instance_class.startswith(prefix) for prefix in VALID_INSTANCE_CLASSES):
        reasons.append(f"Invalid instance class: {instance_class}")

    #check for deprecated configurations
    if any(instance_class.startswith(dep) for dep in DEPRECATED_CONFIGS):
        reasons.append(f"Deprecated instance class: {instance_class}")

    #validate maintenance window format
    if not MAINTENANCE_WINDOW_PATTERN.match(maintenance_window):
        reasons.append(
            f"Invalid maintenance window format: {maintenance_window}. "
            f"Expected: ddd:hh:mm-ddd:hh:mm"
        )

    #return result
    if reasons:
        return {"status": "NOT_READY", "reasons": reasons}

    return {"status": "READY", "reasons": []}
