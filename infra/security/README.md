# IranVault Security Hardening

This directory contains enterprise-grade security hardening configurations for the IranVault cryptocurrency exchange. The implementation provides comprehensive protection against modern cyber threats while maintaining high availability and performance.

## 🛡️ Security Overview

IranVault implements a defense-in-depth security strategy covering:

- **Web Application Firewall (WAF)** - ModSecurity with OWASP Core Rule Set
- **Rate Limiting** - Global and per-service rate limiting to prevent abuse
- **DDoS Protection** - Layer 7 and Layer 4 DDoS mitigation
- **Zero Trust Networking** - Network policies and mTLS for internal communication
- **Security Monitoring** - Comprehensive alerting and detection
- **Secrets Management** - Secure secret storage and rotation
- **Compliance Monitoring** - KYC, AML, and geographic restrictions

## 📁 Directory Structure

```
infra/security/
├── deploy-security.ps1          # Main deployment script
├── setup-secrets.ps1            # Secret management script
├── ingress-nginx-values.yaml    # WAF and ingress configuration
├── network-policies.yaml        # Zero trust network policies
├── prometheus-alerts.yaml       # Security monitoring rules
├── rate-limiting-config.yaml    # Rate limiting configurations
├── secrets-template.yaml        # Secret templates
└── README.md                    # This documentation
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x
- kubectl configured
- cert-manager (for TLS certificates)
- Prometheus/Grafana (for monitoring)

### One-Command Deployment

```powershell
# Deploy all security components
.\deploy-security.ps1

# Dry run to preview changes
.\deploy-security.ps1 -DryRun

# Deploy to custom namespace
.\deploy-security.ps1 -Namespace "iranvault-staging"
```

### Manual Deployment Steps

1. **Set up secrets:**
   ```powershell
   .\setup-secrets.ps1
   ```

2. **Deploy network policies:**
   ```bash
   kubectl apply -f network-policies.yaml
   ```

3. **Deploy ingress with WAF:**
   ```bash
   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
     -f ingress-nginx-values.yaml \
     -n ingress-nginx
   ```

4. **Deploy monitoring:**
   ```bash
   kubectl apply -f prometheus-alerts.yaml
   ```

## 🔐 Security Components

### 1. Web Application Firewall (WAF)

**Technology:** ModSecurity v3 + OWASP Core Rule Set

**Protection Against:**
- SQL Injection
- Cross-Site Scripting (XSS)
- Remote Code Execution (RCE)
- Path Traversal
- Bad bots and crawlers

**Configuration:** `ingress-nginx-values.yaml`

```yaml
controller:
  config:
    enable-modsecurity: "true"
    enable-owasp-modsecurity-crs: "true"
    modsecurity-snippet: |
      SecRuleEngine On
      SecRequestBodyAccess On
```

### 2. Rate Limiting

**Types:**
- **Global Rate Limiting:** 100 req/min, burst 200
- **Authentication:** 5 req/min for login
- **Trading:** 50 req/min for orders
- **Market Data:** 500 req/min for tickers

**Configuration:** `rate-limiting-config.yaml`

```yaml
# Authentication endpoints - strict limiting
auth:
  login:
    nginx.ingress.kubernetes.io/rate-limit: "5"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
```

### 3. DDoS Protection

**Layer 7 (Application):**
- Rate limiting
- WAF filtering
- Connection limits
- Request size limits

**Layer 4 (Network):**
- Cloud provider DDoS protection (Hetzner/AWS)
- SYN flood protection
- Traffic filtering

### 4. Zero Trust Networking

**Network Policies:** `network-policies.yaml`

- Service-to-service communication strictly controlled
- External access only through ingress
- Database access limited to required services
- East-west traffic isolation

**mTLS Internal Communication:**
- Mutual TLS between services
- Certificate-based authentication
- Encrypted internal traffic

### 5. Security Monitoring & Alerting

**Prometheus Alerts:** `prometheus-alerts.yaml`

- Brute force detection
- DDoS attack detection
- WAF block monitoring
- Rate limit violations
- Authentication failures
- Resource exhaustion
- Compliance violations

### 6. Secrets Management

**Secure Storage:**
- Kubernetes secrets with encryption
- External API keys
- Database credentials
- TLS certificates

**Rotation:**
- Automated certificate rotation
- Secret versioning
- Secure backup procedures

## 📊 Monitoring Dashboard

### Key Metrics to Monitor

1. **WAF Blocks:** `nginx_ingress_controller_requests{status="403"}`
2. **Rate Limit Hits:** `nginx_ingress_controller_requests{status="429"}`
3. **Failed Auth:** `nginx_ingress_controller_requests{status=~"401|403"}`
4. **DDoS Traffic:** `rate(nginx_ingress_controller_requests_total[1m])`

### Grafana Dashboard

Import the security dashboard from `monitoring/grafana-dashboards/security.json`

## 🔧 Configuration

### Ingress Annotations

Apply security annotations to your services:

```yaml
metadata:
  annotations:
    # Rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"

    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "DENY" always;
      add_header X-Content-Type-Options "nosniff" always;

    # SSL/TLS
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### Service Security Context

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101
      containers:
      - securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
              - ALL
```

## 🧪 Testing Security

### Penetration Testing

```bash
# Test WAF
curl -H "User-Agent: sqlmap" https://api.iranvault.com/api/v1/orders

# Test rate limiting
for i in {1..100}; do curl https://api.iranvault.com/api/v1/auth/login; done

# Test DDoS protection
ab -n 10000 -c 100 https://api.iranvault.com/api/v1/market/ticker
```

### Security Validation

```bash
# Check network policies
kubectl get networkpolicies -n iranvault-prod

# Check secrets
kubectl get secrets -n iranvault-prod

# Check ingress security
kubectl describe ingress api-gateway -n iranvault-prod

# Test SSL/TLS
openssl s_client -connect api.iranvault.com:443 -servername api.iranvault.com
```

## 📋 Security Checklist

### Pre-Production Checklist

- [ ] WAF enabled and tested
- [ ] Rate limiting configured
- [ ] Network policies applied
- [ ] mTLS certificates deployed
- [ ] Security monitoring active
- [ ] Secrets properly configured
- [ ] SSL/TLS certificates valid
- [ ] Security headers enabled
- [ ] Pod security contexts set
- [ ] Resource limits configured

### Production Checklist

- [ ] External API keys updated
- [ ] Email service configured
- [ ] Cloud provider secrets set
- [ ] Backup encryption enabled
- [ ] Log aggregation configured
- [ ] Alert notifications tested
- [ ] Incident response plan ready
- [ ] Security audit completed

## 🚨 Incident Response

### Common Incidents

1. **Brute Force Attack:**
   - Check alerts: `BruteForceLoginDetected`
   - Block offending IPs
   - Review authentication logs

2. **DDoS Attack:**
   - Check alerts: `DDoSAttackDetected`
   - Enable cloud DDoS protection
   - Scale ingress controllers

3. **WAF Bypass:**
   - Review WAF logs
   - Update rules if needed
   - Implement custom rules

### Emergency Contacts

- Security Team: security@iranvault.com
- DevOps: devops@iranvault.com
- Compliance: compliance@iranvault.com

## 📚 Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [ModSecurity Reference](https://github.com/SpiderLabs/ModSecurity/wiki)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)

## 🤝 Contributing

When adding new security features:

1. Update this README
2. Add tests for new security controls
3. Update monitoring alerts if needed
4. Document incident response procedures
5. Review with security team

## 📞 Support

For security-related issues or questions:

- **Security Issues:** Report to security@iranvault.com
- **Documentation:** Update this README
- **Code Reviews:** Require security team approval for security changes

---

**Remember:** Security is an ongoing process. Regular audits, updates, and monitoring are essential for maintaining a secure environment.