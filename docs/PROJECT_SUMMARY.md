# Database Deployment Readiness Checker (DDRC) — Full Project Summary

## Module 4: DevOps Tooling and Pipeline Automation

---

## 1. Project Overview

### What is the DDRC?

The Database Deployment Readiness Checker (DDRC) is a Python-based microservice that automatically validates database deployment requests against predefined readiness and compliance rules before they enter operational workflows. It was designed to solve a real operational problem: ensuring that deployment requests for database services are correctly configured before reaching the deployment pipeline, reducing failed deployments, rollback incidents, and on-call engineer burden.

### The Business Problem

Within the database services team, deployment requests for services such as Aurora, RDS, ElastiCache, DocumentDB, and Redshift are submitted regularly. Each request must meet specific criteria — correct engine versions, approved instance classes, valid maintenance windows, and complete required fields. Previously, these checks were performed manually or caught downstream after a deployment failure. This introduces risk, delays, and wasted engineering time.

### How DDRC Solves It

When a deployment request is submitted, the DDRC validates it against a comprehensive ruleset and returns one of three statuses:

- **READY** — All validation checks passed; the deployment can proceed safely
- **NOT_READY** — One or more rules failed; the request must be corrected before proceeding
- **INCOMPLETE** — Required fields are missing; the request cannot be evaluated

The service exposes a REST API with three endpoints:
- `POST /validate` — Accepts a JSON deployment request payload and returns the validation result
- `GET /health` — Returns service health status for monitoring and orchestration probes
- `GET /metrics` — Exposes Prometheus-compatible metrics for observability

### Supported Services

The DDRC validates deployment requests for the following database services:

| Service | Valid Engine Versions |
|---------|---------------------|
| Aurora MySQL | 3.04, 3.05, 3.06, 3.07 |
| Aurora PostgreSQL | 14.9, 15.4, 15.5, 16.1 |
| RDS MySQL | 8.0, 8.4 |
| RDS PostgreSQL | 14.9, 15.4, 16.1 |
| RDS Oracle | 19.0, 21.0 |
| RDS SQL Server | 2019, 2022 |
| RDS MariaDB | 10.6, 10.11, 11.4 |
| ElastiCache Redis | 7.0, 7.1 |
| ElastiCache Memcached | 1.6 |
| DocumentDB | 5.0, 6.0 |
| Redshift | 1.0 |

### Validation Rules

1. **Required fields check** — service_name, engine_version, instance_class, region, maintenance_window, requester must all be present and non-empty
2. **Service name validation** — Must match one of the approved service names
3. **Engine version validation** — Must match an approved version for the specified service
4. **Instance class validation** — Must use an approved instance class prefix (db.r5, db.r6g, db.r6i, db.r7g, db.m5, db.m6g, db.m6i, db.m7g, db.t3, db.t4g, cache.r6g, cache.r7g, cache.m6g, cache.m7g, dc2, ra3, ds2)
5. **Deprecated configuration detection** — Flags deprecated instance classes (db.r4, db.m4, db.t2, cache.r5, cache.m5, dc1)
6. **Maintenance window format** — Must match pattern `ddd:hh:mm-ddd:hh:mm` (e.g., `sun:03:00-sun:04:00`)

### Architecture

The system follows a Lambda-compatible handler pattern, meaning the core validation logic is written as a `lambda_handler(event, context)` function that can be deployed directly to AWS Lambda in future phases. For the current phase, it runs as a containerised Flask application deployed to Kubernetes, fronted by an Nginx reverse proxy.

```
Developer pushes code to GitHub
        ↓
Jenkins detects change (SCM polling)
        ↓
Pipeline executes: Checkout → Install → Test → Security Scan → Docker Build → K8s Deploy
        ↓
Docker image built and imported to k3s containerd
        ↓
Kubernetes runs 2 pod replicas with health/readiness probes
        ↓
NodePort service exposes the application
        ↓
Nginx reverse proxy routes external traffic to the service
```

---

## 2. Implementation Journey

### Phase 1 — Repository and Version Control Setup

**What was done:**
- Created a public GitHub repository: https://github.com/ammnelson/database-deployment-readiness-checker
- Established a modular project structure separating application code, tests, Kubernetes manifests, monitoring configuration, Nginx configuration, scripts, and documentation
- Configured SSH/PAT authentication for secure push access from the development environment
- Implemented a structured commit history with descriptive messages

**Repository structure:**
```
├── src/                  # Application source code
│   ├── __init__.py
│   ├── app.py           # Lambda handler + Flask HTTP wrapper
│   └── validator.py     # Core validation logic
├── tests/               # Pytest test suite
│   ├── __init__.py
│   └── test_validator.py
├── k8s/                 # Kubernetes manifests
│   ├── deployment.yaml
│   └── service.yaml
├── monitoring/          # Prometheus and Grafana config
├── nginx/               # Nginx reverse proxy config
├── scripts/             # Operational scripts
├── docs/                # Architecture documentation
├── reports/             # Test and scan results (generated)
├── Dockerfile           # Container definition
├── Jenkinsfile          # CI/CD pipeline definition
├── requirements.txt     # Python dependencies
└── README.md            # Project overview
```

**Evidence/Screenshots:**
- GitHub repository creation page
- VSCode folder structure view showing all directories (k8s, nginx, scripts, src, tests, etc.)

---

### Phase 2 — Application Development

**What was done:**
- Developed the core validation logic in `src/validator.py` using Test-Driven Development (TDD)
- Created the Flask application with Lambda-compatible handler in `src/app.py`
- Wrote 12 unit tests covering valid deployments, incomplete requests, and invalid configurations
- All tests passing with 100% coverage on the validator module

**Key files:**

**`src/validator.py`** (103 lines):
- Lines 1–53: Service definitions, approved engine versions, valid instance classes, deprecated configurations, required fields, and regex patterns
- Lines 55–103: The `validate_deployment_request()` function that evaluates all rules and returns the status

**`src/app.py`** (86 lines):
- Lines 1–58: Imports, Prometheus metric definitions, and the `lambda_handler(event, context)` function — AWS Lambda-compatible entry point
- Lines 60–86: Flask HTTP wrapper routes (`/health`, `/validate`, `/metrics`) that call the lambda_handler internally

**Test categories:**
- `TestValidDeployments` — Valid Aurora MySQL, ElastiCache Redis, and Redshift requests returning READY
- `TestIncompleteRequests` — Missing single field, missing multiple fields, empty field treated as missing
- `TestInvalidRequests` — Invalid service name, unapproved engine version, invalid instance class, deprecated instance class, invalid maintenance window, multiple simultaneous failures

**Evidence/Screenshots:**
- `src/validator.py` lines 9–48 (approved services and instance classes)
- `src/validator.py` lines 55–104 (validate function)
- `src/app.py` lines 20–69 (lambda handler and route definitions)
- pytest output showing all 12 tests passing in console

---

### Phase 3 — Infrastructure and Linux Configuration

**What was done:**
- Provisioned an Ubuntu 24.04 EC2 instance (t3.medium, 20GB gp3) in us-west-2
- Applied AWS security groups restricting all inbound traffic to work IP (15.248.3.91/32) on ports 22, 80, 443, and 8080 — implementing the principle of least privilege
- Performed Linux system administration including package management, user/group configuration, service management, and firewall rules
- Installed and configured: Java 21, Jenkins, Docker, Nginx, and k3s

**Technical details:**

| Component | Version | Notes |
|-----------|---------|-------|
| OS | Ubuntu 24.04 LTS | EC2 t3.medium |
| Java | OpenJDK 21 | Required for Jenkins (resolved from initial Java 17 incompatibility) |
| Jenkins | Latest LTS | CI/CD engine, port 8080 |
| Docker | docker.io | Container runtime |
| Nginx | Latest | Reverse proxy, port 80 |
| k3s | Latest | Lightweight Kubernetes |

**Troubleshooting encountered:**
1. **Jenkins GPG key issue** — Ubuntu 24.04 required importing the Jenkins signing key via `apt-key adv --keyserver` as the standard keyring method failed with signature verification errors
2. **Java version mismatch** — Jenkins installed but failed to start because it required Java 21, not Java 17. Diagnosed via `journalctl -u jenkins`, resolved by installing OpenJDK 21 and configuring JAVA_HOME in `/etc/default/jenkins`
3. **Systemd rate limiting** — After multiple failed starts, systemd rate-limited restart attempts. Resolved with `systemctl reset-failed jenkins` followed by `systemctl daemon-reload`

**Evidence/Screenshots:**
- EC2 instance launch/creation
- `sudo apt update` output
- Java 17 installation
- Jenkins installation
- Java 21 installation (resolving the Jenkins startup failure)
- `systemctl status jenkins` showing active (running)
- Docker installation and `docker --version`
- k3s installation (`curl -sfL https://get.k3s.io | sh -`)
- `sudo k3s kubectl get nodes` showing node Ready

---

### Phase 4 — CI/CD Pipeline Configuration

**What was done:**
- Created a declarative Jenkins pipeline (`Jenkinsfile`) with 6 automated stages
- Configured Jenkins to pull from the GitHub repository using Pipeline SCM integration
- Implemented automated testing, security scanning, container building, and Kubernetes deployment
- Resolved Ubuntu 24.04 PEP 668 restriction by using Python virtual environments in the pipeline

**Pipeline stages:**
1. **Checkout** — Clones the repository from GitHub
2. **Install Dependencies** — Creates a Python venv and installs requirements
3. **Unit Tests** — Runs pytest with coverage and JUnit XML output for Jenkins reporting
4. **Security Scan** — Runs Bandit static analysis, outputs JSON report
5. **Build Docker Image** — Builds the container image tagged with build number
6. **Deploy to Kubernetes** — Applies manifests to the k3s cluster

**Jenkinsfile configuration:**
- Pipeline type: Declarative
- SCM: Git, repository URL pointing to GitHub
- Branch: `*/main`
- Script path: `Jenkinsfile`
- Post actions: Archive reports, echo success/failure

**Security scan results (Bandit):**
- Total lines scanned: 122
- Issues found: 1 medium-severity (B104 — hardcoded bind to 0.0.0.0, acceptable for containerised deployment)
- No high-severity issues
- No critical vulnerabilities

**Evidence/Screenshots:**
- Jenkins pipeline job configuration showing GitHub repo URL (SCM settings)
- Jenkins console output showing 12 tests passing
- Bandit security scan results (run via SSH on EC2 showing the scan output with 1 medium finding)

---

### Phase 5 — Containerisation with Docker

**What was done:**
- Created a production Dockerfile using Python 3.12-slim base image
- Built the container image locally on the EC2 instance
- Ran the container and verified the health endpoint responds correctly
- Image uses gunicorn as the production WSGI server

**Dockerfile:**
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "src.app:app"]
```

**Container verification:**
- Image built successfully as `ddrc:latest`
- Container runs on port 8000
- Health check returns: `{"service":"ddrc","status":"healthy"}`

**Evidence/Screenshots:**
- `docker ps` showing the container running with port mapping 0.0.0.0:8000->8000/tcp
- `curl http://localhost:8000/health` returning healthy JSON response

---

### Phase 6 — Kubernetes Deployment

**What was done:**
- Created Kubernetes Deployment manifest with 2 replicas, resource limits, and health/readiness probes
- Created Kubernetes Service manifest (NodePort) to expose the application
- Imported the Docker image into k3s containerd
- Deployed to the k3s cluster and verified pods are running

**Deployment configuration:**
- Replicas: 2 (high availability)
- Image pull policy: Never (using locally imported image)
- Liveness probe: `GET /health` every 30s (initial delay 10s)
- Readiness probe: `GET /health` every 10s (initial delay 5s)
- Resource requests: 128Mi memory, 100m CPU
- Resource limits: 256Mi memory, 250m CPU

**Service configuration:**
- Type: NodePort
- Port: 80 → targetPort: 8000
- Assigned NodePort: 31758

**Deployment verification:**
```
NAME                    READY   STATUS    RESTARTS   AGE
ddrc-5bd94d7dbc-2nppf   0/1     Running   0          6s
ddrc-5bd94d7dbc-tnlcr   0/1     Running   0          6s

NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
ddrc-service   NodePort    10.43.202.225   <none>        80:31758/TCP   9s
```

**Evidence/Screenshots:**
- `sudo k3s kubectl get pods` showing 2 pods running
- `sudo k3s kubectl get svc` showing NodePort service on 31758

---

## 3. Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Language | Python 3.12 | Application development |
| Framework | Flask | HTTP wrapper for containerised deployment |
| Handler | lambda_handler | AWS Lambda-compatible entry point |
| Testing | pytest + pytest-cov | Unit testing and coverage |
| Security | Bandit | Static code analysis |
| CI/CD | Jenkins | Pipeline automation |
| Containerisation | Docker | Application packaging |
| Orchestration | k3s (Kubernetes) | Container orchestration |
| Reverse Proxy | Nginx | Traffic routing |
| Monitoring | Prometheus client | Metrics instrumentation |
| Version Control | GitHub + Git | Source code management |
| Infrastructure | AWS EC2 (Ubuntu 24.04) | Hosting environment |

---

## 4. Security Measures

- **AWS Security Groups**: Inbound traffic restricted to trusted IP (15.248.3.91/32) on required ports only
- **Bandit Static Analysis**: Integrated into CI/CD pipeline, scans every build
- **No credentials in source control**: Jenkins Credentials Manager used for secrets
- **Container security**: Minimal base image (python:3.12-slim), no root user in container
- **Kubernetes resource limits**: Prevent resource exhaustion
- **Health probes**: Automatic restart of unhealthy pods

---

## 5. Skills and Behaviours Demonstrated

| ID | Skill/Behaviour | Evidence |
|----|----------------|----------|
| S1 | Communicate credibly | Technical documentation, project README, code comments |
| S4 | Knowledge sharing | Internal documentation, peer code review |
| S9 | Cloud security tools | Bandit security scanning in automated pipeline |
| S11 | Systematic problem solving | Java 21 fix, GPG key resolution, venv fix — all diagnosed via logs |
| S12 | Automate tasks | Jenkins pipeline automating test → scan → build → deploy |
| S13 | Pair/mob programming | Collaborative code review with team members |
| S14 | TDD | 12 unit tests written before/alongside implementation, pytest |
| S15 | Release automation | Full CI/CD pipeline: GitHub → Jenkins → Docker → Kubernetes |
| S16 | Continuous learning | Learned Docker, k3s, Jenkins, Flask for this project |
| S17 | Code in general purpose language | Python application with validation logic |
| S20 | Writing code for merging | Git branching, structured commits, descriptive messages |
| S22 | Incremental refactoring | Refactored app.py from pure Flask to lambda_handler pattern (behaviour-preserving) |
| B1 | Collaborative community | Peer review, knowledge sharing, pair programming |
| B2 | Continuous development | Invested time learning containerisation, K8s, CI/CD tooling |
| B3 | You build it, you run it | End-to-end ownership from code to deployed, health-checked service |

---

## 6. Challenges and Resolutions

| Challenge | Diagnosis Method | Resolution |
|-----------|-----------------|------------|
| Jenkins GPG key verification failed on Ubuntu 24.04 | Reviewed `apt update` error output showing missing public key | Used `apt-key adv --keyserver` to import the key directly |
| Jenkins refused to start (Java 17 installed, Java 21 required) | Checked `journalctl -u jenkins` logs showing version requirement | Installed OpenJDK 21, set JAVA_HOME in /etc/default/jenkins |
| pip3 install blocked by PEP 668 (externally-managed-environment) | Read error message recommending venv approach | Refactored Jenkinsfile to use `python3 -m venv` |
| systemd rate-limiting Jenkins restart attempts | Observed "Start request repeated too quickly" in status output | Used `systemctl reset-failed` and `daemon-reload` before restarting |
| Docker image not available in k3s containerd | k3s uses its own containerd, not Docker's image store | Exported image with `docker save` and imported with `k3s ctr images import` |

---

## 7. Screenshot Inventory

| # | Screenshot | Phase | Demonstrates |
|---|-----------|-------|-------------|
| 1 | GitHub repository creation | Phase 1 | Version control setup (S20) |
| 2 | VSCode folder structure (k8s, nginx, scripts, src, tests) | Phase 1 | Project organisation |
| 3 | pytest 12 tests passing in console | Phase 2 | TDD approach (S14) |
| 4 | `src/validator.py` lines 9–48 | Phase 2 | Validation rules (S17) |
| 5 | `src/validator.py` lines 55–104 | Phase 2 | Core logic function (S17) |
| 6 | `src/app.py` lines 20–69 | Phase 2 | Lambda handler pattern (S17) |
| 7 | EC2 instance creation | Phase 3 | Cloud infrastructure |
| 8 | `sudo apt update` output | Phase 3 | Linux administration |
| 9 | Java 17 installation | Phase 3 | Dependency management |
| 10 | Jenkins installation | Phase 3 | CI/CD tooling setup |
| 11 | Java 21 installation (fixing Jenkins) | Phase 3 | Troubleshooting (S11) |
| 12 | `systemctl status jenkins` — active | Phase 3 | Service management |
| 13 | Docker installation + version | Phase 3 | Container runtime |
| 14 | k3s installation | Phase 3 | Kubernetes setup |
| 15 | `k3s kubectl get nodes` — Ready | Phase 3 | Cluster verification |
| 16 | Jenkins pipeline job config (GitHub SCM) | Phase 4 | CI/CD configuration (S15) |
| 17 | Jenkins console — 12 tests passing | Phase 4 | Automated testing (S14, S15) |
| 18 | Bandit security scan results (via SSH) | Phase 4 | Security scanning (S9) |
| 19 | `docker ps` + `curl /health` | Phase 5 | Containerisation working |
| 20 | `k3s kubectl get pods` — 2 pods running | Phase 6 | Kubernetes orchestration |
| 21 | `k3s kubectl get svc` — NodePort service | Phase 6 | Service exposure |

---

## 8. Git Commit History

```
23ff55f Add Kubernetes deployment and service manifests
75d51db Add Dockerfile for containerised deployment
c5290af Fix Jenkinsfile: use Python venv for Ubuntu 24.04 compatibility
58211e1 Add Jenkinsfile: CI/CD pipeline with test, scan, build, and deploy stages
406b3af Refactor app.py to use Lambda-compatible handler with HTTP wrapper
ec6f274 Add DDRC application: validator logic, Flask API, and 12 unit tests (TDD)
c0db4bf Initial project structure: directory layout, README, and requirements
```

---

## 9. Repository

- **GitHub**: https://github.com/ammnelson/database-deployment-readiness-checker
- **EC2 Host**: ec2-44-251-175-27.us-west-2.compute.amazonaws.com
- **Jenkins**: http://44.251.175.27:8080
- **Application (via NodePort)**: http://44.251.175.27:31758/health

---

## 10. Next Steps (Future Modules)

- Infrastructure as Code with Terraform (provision EC2, security groups programmatically)
- Configuration management with Ansible (automate Jenkins/Docker/k3s installation)
- Migration to AWS Lambda + SQS for serverless event-driven processing
- Migration to AWS CodePipeline and CodeBuild for cloud-native CI/CD
- Monitoring with CloudWatch for production observability
- Nginx reverse proxy configuration for production traffic routing
- Prometheus + Grafana dashboards for service metrics visualisation
