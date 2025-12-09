terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy to"
}

# Devices table
resource "aws_dynamodb_table" "devices" {
  name             = "iot-control-cloud-devices"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "deviceId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "deviceId"
    type = "S"
  }
}

# Connections table for WebSocket clients
resource "aws_dynamodb_table" "connections" {
  name         = "iot-control-cloud-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "connectionId"

  attribute {
    name = "connectionId"
    type = "S"
  }
}

# IAM role for all Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "iot-control-cloud-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "iot-control-cloud-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.devices.arn,
          "${aws_dynamodb_table.devices.arn}/stream/*",
          aws_dynamodb_table.connections.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# WebSocket API
resource "aws_apigatewayv2_api" "ws_api" {
  name                       = "iot-control-cloud-ws"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

# Lambda definitions – these expect zipped code at deploy time
resource "aws_lambda_function" "ingest_telemetry" {
  function_name = "iot-control-cloud-ingest-telemetry"
  role          = aws_iam_role.lambda_role.arn
  handler       = "ingestTelemetry.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/../lambda_build/ingestTelemetry.zip"
  timeout       = 10

  environment {
    variables = {
      DEVICES_TABLE = aws_dynamodb_table.devices.name
    }
  }
}

resource "aws_lambda_function" "send_command" {
  function_name = "iot-control-cloud-send-command"
  role          = aws_iam_role.lambda_role.arn
  handler       = "sendCommand.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/../lambda_build/sendCommand.zip"
  timeout       = 10

  environment {
    variables = {
      DEVICES_TABLE = aws_dynamodb_table.devices.name
    }
  }
}

resource "aws_lambda_function" "stream_to_ws" {
  function_name = "iot-control-cloud-stream-to-ws"
  role          = aws_iam_role.lambda_role.arn
  handler       = "streamToWebsocket.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/../lambda_build/streamToWebsocket.zip"
  timeout       = 10

  environment {
    variables = {
      CONNECTIONS_TABLE = aws_dynamodb_table.connections.name
      WS_ENDPOINT       = "${aws_apigatewayv2_api.ws_api.api_endpoint}/$default"
    }
  }
}

resource "aws_lambda_function" "connection_manager" {
  function_name = "iot-control-cloud-connection-manager"
  role          = aws_iam_role.lambda_role.arn
  handler       = "connectionManager.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/../lambda_build/connectionManager.zip"
  timeout       = 10

  environment {
    variables = {
      CONNECTIONS_TABLE = aws_dynamodb_table.connections.name
    }
  }
}

# Integrations
resource "aws_apigatewayv2_integration" "ingest_integration" {
  api_id                 = aws_apigatewayv2_api.ws_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest_telemetry.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "command_integration" {
  api_id                 = aws_apigatewayv2_api.ws_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.send_command.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "connect_integration" {
  api_id                 = aws_apigatewayv2_api.ws_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.connection_manager.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "connect_route" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect_integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect_route" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.connect_integration.id}"
}

resource "aws_apigatewayv2_route" "send_telemetry_route" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "sendTelemetry"
  target    = "integrations/${aws_apigatewayv2_integration.ingest_integration.id}"
}

resource "aws_apigatewayv2_route" "send_com_
