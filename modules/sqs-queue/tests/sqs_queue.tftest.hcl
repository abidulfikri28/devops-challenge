mock_provider "aws" {
  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:ap-southeast-3:111111111111:test-queue-alarms"
    }
  }
}

variables {
  name = "test-queue"
}

run "creates_queue_and_dlq" {
  command = apply

  assert {
    condition     = aws_sqs_queue.this.name == "test-queue"
    error_message = "Queue should use the given name"
  }

  assert {
    condition     = aws_sqs_queue.dlq.name == "test-queue-dlq"
    error_message = "Dead-letter queue should be named <name>-dlq"
  }
}

run "redrive_uses_max_receive_count" {
  command = apply

  variables {
    max_receive_count = 3
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.this.redrive_policy).maxReceiveCount == 3
    error_message = "Redrive policy should use max_receive_count"
  }
}

run "email_alarm_wires_sns_topic" {
  command = apply

  variables {
    alarm_email_endpoint = "claims-alerts@acme-insure.example"
  }

  assert {
    condition     = length(aws_sns_topic.alarm) == 1 && contains(aws_cloudwatch_metric_alarm.oldest_message_age.alarm_actions, aws_sns_topic.alarm[0].arn)
    error_message = "Email alerts must create an SNS topic and connect it to the queue alarm"
  }
}
