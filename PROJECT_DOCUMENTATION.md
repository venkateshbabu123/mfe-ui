# Project Series: Hosting a Modern Frontend on AWS with S3, CloudFront, ACM, and Route53

Author: You (Cloud/DevOps, 10+ years)  
Audience: Intermediate-to-advanced engineers, mentees, and readers of your Medium/LinkedIn content

---

## Why this project
Shipping modern frontends requires fast, secure, global delivery with minimal ops overhead. AWS offers a best-practice stack for static sites: S3 for storage, CloudFront for CDN, ACM for TLS, and Route53 for DNS. This project demonstrates a production-grade pattern using Infrastructure as Code (Terraform), plus an Angular app for realistic context.

What readers will learn:
- Use Terraform to provision static hosting with AWS best practices
- Understand the path from domain → CDN → secure storage
- Implement least-privilege access between CloudFront and S3 using OAC
- Automate ACM certificate issuance and DNS validation
- Integrate a real frontend build and deployment workflow
- Reason about cost, security, and performance trade-offs

---

## Scope and coverage
- Domain: Existing public hosted zone `demoprojectbc1.com`
- Subdomain: `skillsync.demoprojectbc1.com` as the site origin
- Regions: Workload in your preferred region, certificates in `us-east-1`
- Components:
  - S3: Private bucket for static assets, versioning optional
  - CloudFront: Global CDN with OAC and modern cache policy
  - ACM: DNS-validated cert for the subdomain
  - Route53: Alias A/AAAA records in the existing hosted zone
  - IAM: Inline policy for S3 allowing CloudFront to read via SourceArn
- App: Angular 19 micro-frontend, built with `ng build`, published to S3

---

## Design decisions
- Private S3 + OAC: Avoids public buckets and reduces attack surface
- ACM in us-east-1: Mandatory for CloudFront-managed TLS
- Route53 alias records: Native targets for CloudFront; no health checks
- DNS-validated ACM: Robust automation with no email approvals
- Terraform modules: Clear separation of concerns (S3, CDN, ACM, DNS, IAM)
- Environment inputs via `.tfvars`: Repeatable dev/stage/prod setups

---

## Infrastructure flow
1) Terraform looks up existing hosted zone `demoprojectbc1.com`
2) ACM creates/validates a cert for `skillsync.demoprojectbc1.com` in `us-east-1`
3) S3 bucket is created with block public access + versioning (optional)
4) CloudFront distribution is created with OAC, Alternate Domain Name set
5) Route53 creates A/AAAA alias records for the subdomain pointing to CloudFront

---

## Step-by-step (high level)
- Clone repo and set AWS credentials
- Review `devops/variables/dev/dev.tfvars`
- `terraform init` with backend config
- `terraform apply` to provision infra
- `npm run build` to build Angular app
- `aws s3 sync` to upload to S3
- Optionally invalidate CloudFront
- Browse to https://skillsync.demoprojectbc1.com

---

## Reproducibility and environments
- Keep per-env tfvars (dev, stage, prod) under `devops/variables/<env>`
- Use the same modules with different inputs
- Optional: separate AWS accounts per environment with a shared root domain

---

## Technical rationale and trade-offs
Why these services (and not others):
- S3 (as origin) vs S3 Static Website hosting:
  - OAC requires the S3 REST endpoint (not the website endpoint). Using REST keeps the bucket private with fine-grained policy tied to the CloudFront distribution ARN.
  - Website endpoints enable S3-side redirects/error documents, but that implies public access; we prefer CloudFront-managed behaviors.
- CloudFront vs direct S3 access:
  - Global edge network, TLS termination, HTTP/2/3, compression, caching, and WAF/Shield integrations.
  - Dramatically reduces origin traffic and enables custom headers/functions at the edge.
- ACM vs self-managed certificates:
  - Free, auto-renewed, tightly integrated with CloudFront; no rotation burden.
- Route53 vs third-party DNS:
  - First-class Alias support for CloudFront and programmatic management with Terraform; avoids vendor-specific APIs.
- Terraform over console:
  - Versioned, repeatable, reviewable. Supports multi-env via var files and provider aliases.

Alternatives briefly:
- AWS Amplify Hosting: Faster onboarding with CI/CD built-in, but less control over IAM/OAC/caching and infra layout.
- Netlify/Vercel: Great DX, but introduces non-AWS dependency and different cost/model.
- OAI (legacy) vs OAC (modern): OAC supports SigV4 for all origins and is the current AWS recommendation.

---

## Service deep dive
S3 (origin):
- Block Public Access: on by default; prevent ACLs/policies that make objects public.
- Ownership controls: `BucketOwnerEnforced` avoids ACL-based ownership issues.
- Versioning: enabled/disabled per environment. Enables rollbacks and longevity for assets.
- Policy: Grants `s3:GetObject` only to the CloudFront distribution via `AWS:SourceArn`.

CloudFront (CDN):
- OAC: Signs origin requests; no public bucket needed. Prefer OAC over OAI for new builds.
- Cache policy: Using AWS Managed CachingOptimized (ID `658327ea-f89d-4fab-a63d-7e88639e58f6`). For SPAs, cache static assets (hash-named) long; cache `index.html` short (can be done via cache policy + separate behavior if needed).
- Protocols: `viewer_protocol_policy = redirect-to-https`; supports HTTP/2 and HTTP/3 automatically.
- Price class: Tune edge coverage vs cost. `PriceClass_All` maximizes reach; `200/100` can reduce spend.
- SPA routing: You can map 403/404 to `index.html` at CloudFront (custom_error_response) to support deep links without S3 website hosting.
- Logs: Optional access logs to S3; consider enabling for observability and analytics.

ACM (TLS):
- Region requirement: Must be `us-east-1` for CloudFront. Use a provider alias to ensure creation there.
- Validation: DNS CNAMEs are created in the root hosted zone; issuance proceeds automatically.
- RSA_2048 vs ECDSA: RSA is broadly compatible; ECDSA improves performance and smaller certs but might need dual-cert setup for widest client support.

Route53 (DNS):
- Alias A/AAAA records point to CloudFront using its `domain_name` and `hosted_zone_id` (CloudFront’s hosted zone id is globally consistent but taken from the distribution output for correctness).
- EvaluateTargetHealth: generally false for CloudFront aliases.

---

## Terraform architecture and patterns
- Provider aliasing: Separate `aws` default region from `aws.alias_us_east_1` for ACM.
- data sources: `aws_route53_zone` used to look up the existing hosted zone by name and privacy.
- Module dependencies: Outputs (certificate ARN, distribution domain/zone) are wired to downstream modules (CloudFront → Route53 → IAM policy).
- State backend: S3 backend with remote state locking/enc.
- Variables and types: Strong typing for safety (enums for policies, sets for methods, etc.).
- Outputs: Expose S3 bucket info, alias records, and certificate details for post-deploy steps.

---

## SPA routing strategies
- CloudFront custom error responses (recommended with OAC): Map 403/404 → 200 and serve `/index.html`. Works while keeping S3 private.
- S3 website routing rules (not used here): Requires public website endpoint; incompatible with OAC and private buckets.
- Edge rewrites (advanced): CloudFront Functions or Lambda@Edge can rewrite unknown paths to `index.html` with more control (headers, cookies).

---

## Security hardening checklist
- Enforce HTTPS redirects at CloudFront.
- Enable HSTS header at the edge (CloudFront Function/Lambda@Edge) for strict transport security.
- Consider WAF (AWS WAF) with managed rules for L7 protections.
- Restrict allowed HTTP methods to `GET/HEAD/OPTIONS` for static sites (you can reduce from the broader set if POST/PUT aren’t needed).
- Use strict bucket policies; no public ACLs or bucket policies.
- Rotate CloudFront invalidation credentials by using IAM roles/OIDC in CI/CD.

---

## Performance tuning checklist
- Long cache TTLs for immutable, hash-named assets. Short TTL for HTML.
- Enable compression (Brotli/Gzip) automatically handled by CloudFront for text assets.
- Consider Origin Shield for high cache hit and fewer origin fetches (extra cost).
- Use PriceClass_200 or _100 to reduce cost if your audience is regionally concentrated.
- Leverage image optimization at build time; CloudFront does not transform images natively.

---

## Operations and CI/CD
- Build → upload to S3 → invalidate CloudFront (or rely on immutable asset versioning to minimize invalidations).
- Favor content hashing so that new builds don’t require global invalidations except for HTML shell.
- Use GitHub Actions with OIDC to assume an AWS role without long-lived credentials.

---

## Observability and logging
- CloudFront standard metrics in CloudWatch (requests, 4xx/5xx, cache hit rate, bytes).
- Optional: Enable access logs to S3 or use CloudFront real-time logs (Kinesis) for advanced analysis.
- S3 server access logs are usually disabled here since the origin isn’t public; use CloudFront logs for request visibility.
- Set alarms on 5xx, low cache hit rate, and high latency in CloudWatch.

---

## Cost model details
- S3: Storage and request costs; lifecycle policies can transition old versions to IA/Glacier.
- CloudFront: Request + data transfer out; invalidations are free for first 1K paths/month.
- Route53: Hosted zone fixed cost (already exists) + per-record pricing is minimal.
- ACM: Public certificates are free.
- Optimization: Prefer immutable assets to reduce invalidations and origin traffic; choose a suitable price class.

---

## Alternatives and extensions
- SPA routing with custom error/responses (e.g., 403/404 rewrite to index.html)
- Add WAF on CloudFront
- Use OAI instead of OAC (legacy; OAC is recommended)
- Lambda@Edge/CloudFront Functions for headers, redirects, auth
- CI/CD with GitHub Actions for build + deploy + invalidation
- Multi-domain or wildcard certs if needed (SANs)

---

## Gotchas
- Cert must be in `us-east-1`
- Alternate Domain Name must match DNS exactly
- DNS propagation can take minutes; don’t forget IPv6 AAAA
- If destroy fails, empty the S3 bucket before `terraform destroy`

---

## Appendix: Commands cheatsheet
Infra:
- `terraform init -backend-config=variables/dev/dev.backend.tfvars`
- `terraform plan  -var-file=variables/dev/dev.tfvars`
- `terraform apply -var-file=variables/dev/dev.tfvars`

App:
- `npm ci && npm run build`
- `aws s3 sync <dist> s3://<bucket>/ --delete`
- `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`

---

## Conclusion
This project is a practical, production-grade reference for hosting a frontend on AWS using IaC. It emphasizes security, repeatability, and clarity—ideal for mentoring and content creation. Use it as a base for a series: part 1 (IaC + AWS), part 2 (CI/CD), part 3 (ops hardening and observability).
