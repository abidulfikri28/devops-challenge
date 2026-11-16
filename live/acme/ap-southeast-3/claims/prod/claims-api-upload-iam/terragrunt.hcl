include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//irsa-role"
}

dependency "eks" {
  config_path = "../../../platform/prod/eks"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.ap-southeast-3.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "documents" {
  config_path = "../claims-documents-bucket"
}

dependency "queue" {
  config_path = "../claims-documents-queue"
}

inputs = {
  name              = "claims-api-upload-prod"
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  namespace         = "claims"
  service_account   = "claims-api"

  policy_statements = [
    {
      sid       = "DocumentsUpload"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${dependency.documents.outputs.bucket_arn}/uploads/*"]
    },
    {
      sid       = "QueueDocumentForOcr"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [dependency.queue.outputs.queue_arn]
    },
  ]
}
