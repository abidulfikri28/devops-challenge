mock_provider "aws" {}

variables {
  name = "test-claims-documents"
}

run "existing_bucket_defaults_unchanged" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_public_access_block.private) == 0 && length(aws_s3_bucket_server_side_encryption_configuration.private) == 0
    error_message = "Private bucket controls must stay opt-in for existing module users"
  }
}

run "claims_documents_bucket_is_private" {
  command = plan

  variables {
    private_bucket = true
    versioning     = true
    force_destroy  = false
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.private[0].block_public_acls && aws_s3_bucket_public_access_block.private[0].block_public_policy && aws_s3_bucket_public_access_block.private[0].ignore_public_acls && aws_s3_bucket_public_access_block.private[0].restrict_public_buckets
    error_message = "Claim documents must block public access through ACLs and policies"
  }

  assert {
    condition     = length(aws_s3_bucket_ownership_controls.private) == 1 && length(aws_s3_bucket_server_side_encryption_configuration.private) == 1 && length(aws_s3_bucket_versioning.this) == 1 && !aws_s3_bucket.this.force_destroy
    error_message = "Claim documents must enforce bucket ownership, encryption, versioning, and safe deletion"
  }
}
