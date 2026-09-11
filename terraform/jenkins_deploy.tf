# The pipeline's deploy permission: the build host may update the code of
# exactly these two functions - nothing else. Infra changes stay off the box.
resource "aws_iam_role_policy" "jenkins_lambda_deploy" {
  name = "ddrc-jenkins-lambda-deploy"
  role = module.compute.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DeployDdrcFunctions"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction"
        ]
        Resource = module.serverless.function_arns
      }
    ]
  })
}
