resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = var.tags
}

resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = var.tags
}

resource "aws_sns_topic" "alarm" {
  count = var.alarm_email_endpoint == "" ? 0 : 1

  name = "${var.name}-alarms"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email_endpoint == "" ? 0 : 1

  topic_arn = aws_sns_topic.alarm[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoint
}

locals {
  notification_actions = concat(var.alarm_actions, aws_sns_topic.alarm[*].arn)
}

resource "aws_cloudwatch_metric_alarm" "oldest_message_age" {
  alarm_name        = "${var.name}-oldest-message-age"
  alarm_description = "Messages in ${var.name} are not being consumed"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateAgeOfOldestMessage"
  dimensions = {
    QueueName = aws_sqs_queue.this.name
  }

  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_age_threshold_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.notification_actions
  ok_actions    = local.notification_actions

  tags = var.tags
}
