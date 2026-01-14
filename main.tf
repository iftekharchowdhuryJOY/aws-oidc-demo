provider "aws" {
  region = "ca-central-1"
}

# --- 1. DYNAMICALLY FETCH GITHUB'S SIGNATURE ---
# This fixes the "Thumbprint Mismatch" error by asking GitHub for their current cert
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# --- 2. CREATE OIDC PROVIDER ---
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  
  # Use the dynamically fetched fingerprint
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# --- 3. CREATE THE ROLE ---
resource "aws_iam_role" "github_oidc_role" {
  name = "github-actions-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            # 🔒 VERIFY THIS LINE EXACTLY MATCHES YOUR GITHUB REPO
            # Syntax: repo:YourUsername/YourRepoName:*
            "token.actions.githubusercontent.com:sub": "repo:iftekharchowdhury/aws-oidc-demo:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# --- 4. ATTACH PERMISSIONS ---
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- 5. OUTPUT THE ARN ---
output "role_arn" {
  value = aws_iam_role.github_oidc_role.arn
}