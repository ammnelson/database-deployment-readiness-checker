"""
Unit tests for the Database Deployment Readiness Checker.

Tests cover valid requests, invalid configurations, missing fields,
deprecated instances, and edge cases.
"""

import pytest
from src.validator import validate_deployment_request


class TestValidDeployments:
    """Tests for requests that should return READY."""

    def test_valid_aurora_mysql_request(self):
        request = {
            "service_name": "aurora-mysql",
            "engine_version": "3.05.2",
            "instance_class": "db.r6g.large",
            "region": "eu-west-2",
            "maintenance_window": "sun:03:00-sun:04:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "READY"
        assert result["reasons"] == []

    def test_valid_elasticache_request(self):
        request = {
            "service_name": "elasticache-redis",
            "engine_version": "7.1.0",
            "instance_class": "cache.r6g.large",
            "region": "eu-west-1",
            "maintenance_window": "tue:04:00-tue:05:00",
            "requester": "boydypd",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "READY"
        assert result["reasons"] == []

    def test_valid_redshift_request(self):
        request = {
            "service_name": "redshift",
            "engine_version": "1.0",
            "instance_class": "ra3.xlplus",
            "region": "us-east-1",
            "maintenance_window": "sat:02:00-sat:03:00",
            "requester": "elliotuk",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "READY"
        assert result["reasons"] == []


class TestIncompleteRequests:
    """Tests for requests with missing required fields."""

    def test_missing_service_name(self):
        request = {
            "engine_version": "3.05.2",
            "instance_class": "db.r6g.large",
            "region": "eu-west-2",
            "maintenance_window": "sun:03:00-sun:04:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "INCOMPLETE"
        assert "Missing required field: service_name" in result["reasons"]

    def test_missing_multiple_fields(self):
        request = {
            "service_name": "aurora-mysql",
            "region": "eu-west-2",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "INCOMPLETE"
        assert len(result["reasons"]) == 4

    def test_empty_field_treated_as_missing(self):
        request = {
            "service_name": "",
            "engine_version": "3.05.2",
            "instance_class": "db.r6g.large",
            "region": "eu-west-2",
            "maintenance_window": "sun:03:00-sun:04:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "INCOMPLETE"


class TestInvalidRequests:
    """Tests for requests that should return NOT_READY."""

    def test_invalid_service_name(self):
        request = {
            "service_name": "dynamodb",
            "engine_version": "1.0",
            "instance_class": "db.r6g.large",
            "region": "eu-west-2",
            "maintenance_window": "sun:03:00-sun:04:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "NOT_READY"
        assert any("Invalid service name" in r for r in result["reasons"])

    def test_unapproved_engine_version(self):
        request = {
            "service_name": "aurora-mysql",
            "engine_version": "2.07.1",
            "instance_class": "db.r6g.large",
            "region": "eu-west-2",
            "maintenance_window": "sun:03:00-sun:04:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "NOT_READY"
        assert any("not approved" in r for r in result["reasons"])

    def test_invalid_instance_class(self):
        request = {
            "service_name": "rds-postgresql",
            "engine_version": "15.4",
            "instance_class": "db.x2g.large",
            "region": "eu-west-2",
            "maintenance_window": "mon:05:00-mon:06:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "NOT_READY"
        assert any("Invalid instance class" in r for r in result["reasons"])

    def test_deprecated_instance_class(self):
        request = {
            "service_name": "aurora-postgresql",
            "engine_version": "15.4",
            "instance_class": "db.r4.large",
            "region": "eu-west-2",
            "maintenance_window": "wed:03:00-wed:04:00",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "NOT_READY"
        assert any("Deprecated" in r for r in result["reasons"])

    def test_invalid_maintenance_window_format(self):
        request = {
            "service_name": "documentdb",
            "engine_version": "6.0",
            "instance_class": "db.r6g.large",
            "region": "eu-west-2",
            "maintenance_window": "sunday 3am to 4am",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "NOT_READY"
        assert any("Invalid maintenance window" in r for r in result["reasons"])

    def test_multiple_validation_failures(self):
        request = {
            "service_name": "aurora-mysql",
            "engine_version": "2.07.1",
            "instance_class": "db.r4.large",
            "region": "eu-west-2",
            "maintenance_window": "invalid",
            "requester": "ngarratt",
        }
        result = validate_deployment_request(request)
        assert result["status"] == "NOT_READY"
        assert len(result["reasons"]) >= 3
