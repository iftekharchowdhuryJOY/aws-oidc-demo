provider "aws" {
  region = "ca-central-1"
}

# --- 1. CREATE OIDC PROVIDER ---
# This tells AWS to accept tokens signed by GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub's thumbprint (This is public knowledge and rarely changes)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# --- 2. CREATE THE ROLE ---
resource "aws_iam_role" "github_oidc_role" {
  name = "github-actions-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            # 🔒 LOCK THIS DOWN: Replace with your actual username/repo
            # Example: "repo:iftekharchowdhury/my-project:*"
            "token.actions.githubusercontent.com:sub": "repo:iftekharchowdhury/*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# --- 3. ATTACH PERMISSIONS ---
# Give the role power (Admin for now, limit this in production!)
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- 4. OUTPUT THE ARN ---
output "role_arn" {
  value = aws_iam_role.github_oidc_role.arn
}