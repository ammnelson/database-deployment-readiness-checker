# DDRC Threat Model

Scope: the Module 5 DDRC system - API Gateway -> api Lambda -> SQS -> worker Lambda -> DynamoDB,
plus the Jenkins build host that tests, packages and deploys the code.

## Assets

| Asset | Why it matters |
|---|---|
| Validation results table (`ddrc-results`) | The audit trail; integrity matters more than confidentiality (no PII stored) |
| Lambda function code | Whoever changes it controls what "compliant" means |
| Build host IAM role | Holds the deploy permission; the most powerful identity in the system |
| Jenkins itself | Controls the path from git push to production code |
| GitHub repository | The source of truth everything else derives from |

## Trust boundaries

1. Internet -> API Gateway (public entry point)
2. Internet -> build host (SSH/Jenkins, IP-allowlisted)
3. Build host -> AWS APIs (instance profile)
4. api Lambda -> queue -> worker Lambda (untrusted message contents)

## Threats and mitigations

| Threat | Mitigation | Evidence |
|---|---|---|
| Credential theft from the build host via SSRF/metadata service | IMDSv2 required (session tokens); no long-lived keys exist anywhere - all identities are roles | checkov remediation commit |
| Stolen deploy access blast radius | Build host role can only push code to the two DDRC functions; cannot touch infrastructure | `ddrc-jenkins-lambda-deploy` policy screenshot |
| Compromised api Lambda | Role limited to enqueue + write results + own logs; cannot read the queue or reach other resources | IAM policy screenshots |
| Compromised worker Lambda | Role limited to consume + write results + own logs; cannot even send messages | IAM policy screenshots |
| Malicious/malformed queue messages | Worker validates input, skips unparseable messages with a structured log; genuine processing failures retry 3x then land in an encrypted DLQ with an alarm | Poison-message exercise (Phase 4) |
| Brute force on SSH/Jenkins | Security group restricts 22/8080 to named CIDRs; password auth disabled (key only) | SG rules; Ansible hardening |
| Insecure infrastructure changes | checkov runs as a blocking pipeline stage; failures stop the deploy | Build #12 (caught unresolvable SSH allowlist) / #13 green |
| Vulnerable application code | Bandit static analysis on every build; dependency versions pinned in requirements.txt | Pipeline stage |
| Data loss in the audit trail | DynamoDB point-in-time recovery enabled | checkov remediation commit |
| Tampering with results in transit | TLS everywhere (API Gateway, AWS SDK calls); queues and topic encrypted at rest | Terraform config |

## Accepted risks (deliberate, documented)

| Risk | Reasoning |
|---|---|
| `POST /validate` is publicly reachable with no authentication | v1 demo scope; abuse is bounded (validator holds no secrets, writes capped by Lambda concurrency). Production would add IAM or JWT authorization at the gateway |
| API handler does not decode base64-encoded request bodies | Callers without a JSON Content-Type get a 500 instead of a clean 400; hardening noted for a follow-up |
| checkov skips (26) | Each carries an inline justification in the Terraform; largely enterprise-scale controls (CMKs, code signing, VPC-attached Lambdas) disproportionate at this scale |
| SSH allowlist lives in gitignored tfvars, unresolvable by CI scanning | The alternative is committing IP addresses to git; the variable is required so no default can open the port |

## What I would do next at production scale

Authentication on the API (IAM/JWT), WAF in front of API Gateway, VPC flow logs,
alerts on IAM policy changes (CloudTrail + EventBridge), and Trivy scanning of the
Docker image in the pipeline.
