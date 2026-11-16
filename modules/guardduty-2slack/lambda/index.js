'use strict';

const https = require('node:https');

const MIN_SEVERITY = Number(process.env.MIN_SEVERITY || 4);

function severityLabel(severity) {
  if (severity >= 7) return 'HIGH';
  if (severity >= 4) return 'MEDIUM';
  return 'LOW';
}

function buildMessage(finding) {
  const resource = finding.resource || {};
  const identifiers = [
    resource.instanceDetails?.instanceId && `Instance: ${resource.instanceDetails.instanceId}`,
    resource.s3BucketDetails?.[0]?.name && `Bucket: ${resource.s3BucketDetails[0].name}`,
    resource.accessKeyDetails?.userName && `IAM user: ${resource.accessKeyDetails.userName}`,
  ].filter(Boolean);
  const resourceText = identifiers.length ? identifiers.join(' | ') : `Resource: ${resource.resourceType || 'unknown'}`;

  return {
    text: `:rotating_light: GuardDuty ${severityLabel(finding.severity)}: ${finding.title}`,
    blocks: [
      {
        type: 'section',
        text: { type: 'mrkdwn', text: `*${finding.title}*\n${finding.description}` },
      },
      {
        type: 'context',
        elements: [
          {
            type: 'mrkdwn',
            text: `Type: ${finding.type} | Account: ${finding.accountId} | Region: ${finding.region} | ${resourceText}`,
          },
        ],
      },
    ],
  };
}

function postToSlack(webhookUrl, payload) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      webhookUrl,
      { method: 'POST', headers: { 'Content-Type': 'application/json' } },
      (res) => {
        res.resume();
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve();
        } else {
          reject(new Error(`Slack webhook returned HTTP ${res.statusCode}`));
        }
      },
    );
    req.on('error', reject);
    req.write(JSON.stringify(payload));
    req.end();
  });
}

exports.handler = async (event) => {
  const finding = event.detail;

  if (finding.severity < MIN_SEVERITY) {
    return;
  }

  await postToSlack(process.env.SLACK_WEBHOOK_URL, buildMessage(finding));
};

exports.buildMessage = buildMessage;
exports.severityLabel = severityLabel;
