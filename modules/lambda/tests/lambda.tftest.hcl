mock_provider "aws" {}
mock_provider "archive" {
  mock_data "archive_file" {
    defaults = { output_path = "bootstrap.zip", output_base64sha256 = "synthetic" }
  }
}
variables {
  name     = "test-worker"
  role_arn = "arn:aws:iam::559098897826:role/test-worker"
  vpc      = { private_subnet_ids = ["subnet-test"], lambda_sg_id = "sg-test", vpn_client_sg_id = "sg-vpn" }
}
run "existing_binary" {
  command = plan
  variables { binary = "tests/bootstrap" }
  assert {
    condition     = aws_lambda_function.this.runtime == "provided.al2023" && aws_lambda_function.this.handler == "bootstrap" && aws_lambda_function.this.ephemeral_storage[0].size == 512
    error_message = "Existing binary callers must keep their runtime and storage defaults."
  }
}
run "python_zip_worker" {
  command = plan
  variables {
    package_file      = "tests/bootstrap"
    runtime           = "python3.12"
    handler           = "atlas_data.worker.handler"
    ephemeral_storage = 10240
  }
  assert {
    condition     = aws_lambda_function.this.runtime == "python3.12" && aws_lambda_function.this.filename == "tests/bootstrap" && aws_lambda_function.this.source_code_hash == filebase64sha256("tests/bootstrap") && length(data.archive_file.this) == 0 && aws_lambda_function.this.ephemeral_storage[0].size == 10240
    error_message = "Prebuilt Python ZIPs must retain the shared VPC controls and content hash."
  }
}
