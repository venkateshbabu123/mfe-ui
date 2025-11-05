# Course MFE on AWS (S3 + CloudFront + ACM + Route53)

This repository contains an Angular 19 micro-frontend and Terraform IaC to host it as a static website on AWS using S3, CloudFront, ACM, and Route53.

What you get:
- Production-ready static hosting on S3 fronted by CloudFront
- TLS termination with ACM (us-east-1) and a custom domain
- DNS Alias records in an existing Route53 hosted zone
- Least-privilege OAC access from CloudFront to your S3 bucket
- Simple, repeatable Terraform workflow


## Architecture
- Browser → Route53 Alias (A/AAAA) for `skillsync.demoprojectbc1.com`
- Route53 → CloudFront distribution (Alternate Domain Name set)
- CloudFront → S3 via Origin Access Control (OAC)
- SSL/TLS via ACM in `us-east-1`


## Repository Structure
```
/ (Angular app)
/devops                # Terraform IaC
  ├── modules          # S3, CloudFront, ACM, Route53, IAM OAC policy
  └── variables/dev    # Example tfvars for dev
```

Key files:
- Terraform root: `devops/`
- Tf backend vars: `devops/variables/dev/dev.backend.tfvars`
- Tf env vars: `devops/variables/dev/dev.tfvars`


## Prerequisites
- AWS account + credentials with permissions for Route53, ACM, CloudFront, S3, IAM
- Domain hosted in Route53 (existing public hosted zone): `demoprojectbc1.com`
- Node.js 18+
- Terraform 1.5+
- AWS CLI v2

Ensure your AWS credentials are configured (for example using SSO or a profile).


## Configure Terraform
This stack uses an existing public hosted zone `demoprojectbc1.com` and creates:
- An ACM certificate in `us-east-1` for `skillsync.demoprojectbc1.com`
- A CloudFront distribution with that alternate domain name
- Alias A/AAAA records in `demoprojectbc1.com` pointing to CloudFront
- A private S3 bucket for build artifacts with OAC policy

Edit the environment tfvars (dev shown):
- `devops/variables/dev/dev.tfvars`
  - `root_domain_name = "demoprojectbc1.com"`
  - `sub_domain_name  = "skillsync.demoprojectbc1.com"`
  - `cloudfront_acm_region = "us-east-1"`
  - Optionally adjust S3 bucket name and other flags

Edit remote state backend (optional):
- `devops/variables/dev/dev.backend.tfvars`
  - Update `bucket`, `key`, and `region` for your state bucket


## Provision Infrastructure
Run these from the `devops` directory:

```bash
cd devops
terraform init -backend-config=variables/dev/dev.backend.tfvars
terraform plan -var-file=variables/dev/dev.tfvars
terraform apply -var-file=variables/dev/dev.tfvars
```

Important notes:
- The ACM certificate must be in `us-east-1` for CloudFront; this is already handled by providers and module wiring.
- DNS validation CNAMEs for the certificate are created automatically in the existing hosted zone.
- The Route53 module creates Alias A and AAAA records for `skillsync.demoprojectbc1.com` that target CloudFront.

Outputs you will need:
```bash
terraform output
```
Look for:
- `s3_details.bucket_id` (bucket name for uploads)
- `dns_alias_records.a_fqdn` (the public DNS record)
- `cloudfront_certificate_details.status` (should be Issued)


## Build the Angular App
From the repo root:
```bash
npm ci
npm run build
# Production build goes to dist/ by default (Angular 15+ uses dist/<project>)
```
Confirm your build output path (e.g. `dist/mfe-ui/browser` or similar based on your Angular config).


## Deploy Static Assets to S3
Replace <dist-path> with your actual build folder and <bucket> with output from Terraform.
```bash
aws s3 sync <dist-path> s3://<bucket>/ --delete
```

Make sure the S3 bucket policy is managed only via Terraform (we already attach the minimal OAC policy). Do not make the bucket public.


## Invalidate CloudFront Cache
After initial deploys or when changing assets:
```bash
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "<YOUR_DIST_ID>") \
  --paths "/*"
```
If you didn’t expose the distribution ID as an output, copy it from the AWS Console.


## Verify
- Navigate to https://skillsync.demoprojectbc1.com
- Certificate should be valid (Issued) and served by CloudFront
- The site should load via HTTPS


## Teardown
```bash
cd devops
terraform destroy -var-file=variables/dev/dev.tfvars
```
If the S3 bucket is non-empty, empty it first:
```bash
aws s3 rm s3://<bucket>/ --recursive
```


## Troubleshooting
- Stuck at ACM validation: Check that ACM CNAME records exist in the hosted zone and that the zone is public.
- 403 from S3 via CloudFront: Ensure the OAC policy is attached and the bucket blocks public access (as expected). Do not set public ACLs.
- Domain not resolving: Confirm that the Alias A/AAAA records exist in `demoprojectbc1.com` and the CloudFront distribution is Deployed.
- SSL errors on CloudFront: Alternate Domain Name must match `skillsync.demoprojectbc1.com` and the ACM cert must be in `us-east-1`.


## App Quickstart (Local)
```bash
npm start
# or
ng serve
```
Open http://localhost:4200/


## CI/CD (Optional)
You can add a GitHub Actions workflow to:
- Build Angular on push
- Upload build artifacts to S3
- Invalidate CloudFront
- Optionally run Terraform in a separate infra pipeline


## License
MIT
