# Database Deployment Readiness Checker (DDRC)

A Python-based service that validates database deployment requests against predefined readiness and compliance rules. Designed to ensure only properly configured deployment requests proceed into operational workflows.

## Overview

When a deployment request is submitted for a database service (Aurora, RDS, ElastiCache, DocumentDB, Redshift), the DDRC validates the request against:

- Required fields (service name, engine version, instance class, region, maintenance window, requester)
- Approved service names and engine versions
- Valid instance class families
- Maintenance window format
- Deprecated or restricted configuration detection

Each request returns one of three statuses:
- **READY** — All checks passed, deployment can proceed
- **NOT_READY** — One or more validation rules failed
- **INCOMPLETE** — Required fields are missing

## Project Structure

```
├── src/                  # Application source code
├── tests/                # Pytest test suite
├── k8s/                  # Kubernetes manifests
├── monitoring/           # Prometheus and Grafana configuration
├── nginx/                # Nginx reverse proxy configuration
├── scripts/              # Operational scripts
├── docs/                 # Architecture notes and documentation
├── Dockerfile            # Container definition
├── Jenkinsfile           # CI/CD pipeline configuration
├── requirements.txt      # Python dependencies
└── README.md             # This file
```

## Tech Stack

- **Language**: Python 3.11 (Flask)
- **Testing**: pytest
- **CI/CD**: Jenkins
- **Containerisation**: Docker
- **Orchestration**: Amazon EKS (Kubernetes)
- **Reverse Proxy**: Nginx
- **Monitoring**: Prometheus + Grafana

## API Endpoints

| Method | Endpoint    | Description                        |
|--------|-------------|------------------------------------|
| POST   | `/validate` | Validate a deployment request      |
| GET    | `/health`   | Health check endpoint              |
| GET    | `/metrics`  | Prometheus metrics endpoint        |

## Running Locally

```bash
pip install -r requirements.txt
python src/app.py
```

## Running Tests

```bash
pytest tests/ -v --cov=src
```
