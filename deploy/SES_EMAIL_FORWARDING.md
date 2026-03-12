# AWS SES Email Forwarding to Gmail

This guide documents how incoming email to `*@givingshelf.net` is received by AWS SES, stored in S3, and forwarded to a personal Gmail address via a Lambda function. The solution is generic: any sender, any address at givingshelf.net.

**Related:** [SES Setup (sending)](SES_SETUP.md) covers domain verification and SMTP for outbound mail.

---

## Overview

1. **MX record** – Incoming mail for `givingshelf.net` is delivered to SES.
2. **SES receipt rule** – Matches the domain, stores the raw email in S3 and invokes Lambda.
3. **Lambda** – Reads the email from S3, parses it with `mailparser`, and sends a **new** email (not raw) from a verified identity to Gmail. This avoids SES "unverified sender" errors and improves deliverability (subject + HTML body, no third-party DKIM).

---

## Prerequisites

- Domain `givingshelf.net` verified in SES (see [SES_SETUP.md](SES_SETUP.md)).
- SES in **us-west-2** (same region as the app).
- DNS access for `givingshelf.net`.

---

## Part 1: MX Record for Receiving

Point incoming mail for the domain to SES.

| Field     | Value                                    |
|----------|------------------------------------------|
| **Name** | `@` or `givingshelf.net`                 |
| **Type** | MX                                      |
| **Value**| `10 inbound-smtp.us-west-2.amazonaws.com`|
| **TTL**  | 300 (or default)                         |

**Note:** If you already have MX records (e.g. for another provider), remove them or set this one as primary (lowest priority number) so SES receives mail first.

---

## Part 2: S3 Bucket for Incoming Mail

1. **S3** → Create bucket.
2. **Name:** e.g. `givingshelf-incoming-email`.
3. **Region:** `us-west-2`.
4. Create bucket.

### Bucket policy (allow SES to write)

Replace `YOUR_AWS_ACCOUNT_ID`, `givingshelf-incoming-email`, and the receipt rule name/set if different. Rule set is often `default` or `default-rule-set`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::givingshelf-incoming-email/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceAccount": "YOUR_AWS_ACCOUNT_ID",
          "AWS:SourceArn": "arn:aws:ses:us-west-2:YOUR_AWS_ACCOUNT_ID:receipt-rule-set/default-rule-set:receipt-rule/givingshelf-forward"
        }
      }
    }
  ]
}
```

If you get "Could not write to bucket", try `receipt-rule-set/default` instead of `default-rule-set`, or temporarily remove the `Condition` block to confirm the bucket name and principal are correct, then lock down again with the exact ARN from the SES rule.

---

## Part 3: Lambda Function

### 3.1 Create function

- **Runtime:** Node.js 20.x (or 18.x).
- **Name:** e.g. `givingshelf-email-forward`.
- Create function.

### 3.2 Add dependency (mailparser)

From a directory containing your Lambda code:

```bash
npm init -y
npm install mailparser
```

Zip the handler file(s) and `node_modules`, and upload as the Lambda deployment package (or use a Lambda layer that includes `mailparser`).

### 3.3 Environment variables

| Variable       | Example                      | Required |
|----------------|------------------------------|----------|
| `BUCKET_NAME`  | `givingshelf-incoming-email` | Yes      |
| `FORWARD_TO`   | `your-forwarding-address@example.com` | Yes      |
| `FORWARD_FROM` | `support@givingshelf.net`   | Yes      |

### 3.4 Handler code (parse + SendEmail, HTML-safe)

This version parses the stored email and sends a **new** message so the From is always your verified identity, the subject is preserved, and the body is HTML-safe.

```javascript
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { simpleParser } from "mailparser";

const s3Client = new S3Client({ region: "us-west-2" });
const sesClient = new SESClient({ region: "us-west-2" });

export const handler = async (event) => {
  const BUCKET_NAME = process.env.BUCKET_NAME;
  const FORWARD_TO = process.env.FORWARD_TO;
  const FORWARD_FROM = process.env.FORWARD_FROM;

  if (!BUCKET_NAME || !FORWARD_TO || !FORWARD_FROM) {
    throw new Error("Missing required env: BUCKET_NAME, FORWARD_TO, or FORWARD_FROM");
  }

  const sesNotification = event.Records[0].ses;
  const messageId = sesNotification.mail.messageId;

  try {
    const getObjectResponse = await s3Client.send(new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: messageId
    }));
    const rawEmail = await getObjectResponse.Body.transformToString("utf-8");

    const parsed = await simpleParser(rawEmail);
    const originalFrom = parsed.from?.text || parsed.from?.value?.[0]?.address || "(unknown)";
    const originalSubject = parsed.subject || "(no subject)";
    const originalDate = parsed.date ? parsed.date.toISOString() : "";

    let bodyHtml = parsed.html || null;
    if (!bodyHtml && parsed.text) {
      bodyHtml = `<pre style="white-space: pre-wrap; font-family: sans-serif;">${escapeHtml(parsed.text)}</pre>`;
    }
    if (!bodyHtml) bodyHtml = "<p>(no body)</p>";

    const forwardHeader = [
      "<p style='margin:0 0 0.5em 0;'><strong>Forwarded from:</strong> " + escapeHtml(originalFrom) + "</p>",
      "<p style='margin:0 0 0.5em 0;'><strong>Original subject:</strong> " + escapeHtml(originalSubject) + "</p>",
      originalDate ? "<p style='margin:0 0 1em 0;'><strong>Date:</strong> " + escapeHtml(originalDate) + "</p>" : "",
      "<hr style='margin:1em 0; border: none; border-top: 1px solid #ccc;'>"
    ].filter(Boolean).join("");

    const fullHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="font-family: sans-serif; line-height: 1.5; color: #333;">
  ${forwardHeader}
  <div class="original-body">${bodyHtml}</div>
</body>
</html>`;

    await sesClient.send(new SendEmailCommand({
      Source: FORWARD_FROM,
      Destination: { ToAddresses: [FORWARD_TO] },
      Message: {
        Subject: { Data: originalSubject, Charset: "UTF-8" },
        Body: {
          Html: { Data: fullHtml, Charset: "UTF-8" }
        }
      }
    }));

    console.log(`Forwarded message ${messageId} to ${FORWARD_TO}`);
    return { disposition: "STOP_RULE_SET" };
  } catch (err) {
    console.error("Error forwarding email:", err);
    throw err;
  }
};

function escapeHtml(str) {
  if (typeof str !== "string") return "";
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
```

### 3.5 Lambda configuration

- **Timeout:** 30 seconds.
- **Memory:** 256 MB.

### 3.6 IAM permissions (execution role)

The Lambda execution role needs:

- **S3:** `s3:GetObject` on `arn:aws:s3:::givingshelf-incoming-email/*`
- **SES:** `ses:SendEmail` (and optionally `ses:SendRawEmail` if you use it elsewhere)

Example inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::givingshelf-incoming-email/*"
    },
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    }
  ]
}
```

**Where to set:** Lambda → Configuration → Permissions → click the execution role name → IAM → Roles → [role] → Permissions → Add inline policy or edit existing.

---

## Part 4: SES Receipt Rule

1. **SES** → **Email receiving** → **Rule sets**.
2. Create or open the active rule set (e.g. `default` or `default-rule-set`).
3. **Create rule** (or edit existing):
   - **Rule name:** e.g. `givingshelf-forward`
   - **Recipient:** `givingshelf.net` (domain) so **any** `*@givingshelf.net` is forwarded.
   - **Actions (order matters):**
     1. **S3** – Bucket: `givingshelf-incoming-email`, no object key prefix.
     2. **Lambda** – Function: `givingshelf-email-forward`, invocation type: **Event** (asynchronous).
4. Save.

Ensure SES has permission to invoke the Lambda (SES usually adds this when you select the function in the rule; if not, add a resource-based policy on the Lambda allowing `ses.amazonaws.com` to invoke it).

---

## Part 5: Verify and Test

1. Send a test email to e.g. `support@givingshelf.net` or `admin@givingshelf.net` from an external address.
2. Check **S3** – object with key = message ID should appear.
3. Check **CloudWatch** – Lambda log group for your function; confirm no errors and "Forwarded message … to …".
4. Check **Gmail** (inbox and spam) for the forwarded message with correct subject and HTML body.

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| "Could not write to bucket" | Bucket policy `Condition.AWS:SourceArn` must match the receipt rule exactly (rule set name + rule name). Try `default-rule-set` or `default`. |
| "Email address is not verified" | Old approach: raw forward had From/Return-Path/Reply-To from original sender. Fix: use the parse + SendEmail flow above so only `FORWARD_FROM` is used. |
| No subject / hard to read | Same: use the mailparser + SendEmail flow so subject and HTML body are set explicitly. |
| Spam in Gmail | New email from your domain (no third-party DKIM) and clear subject/HTML usually improve deliverability. Mark as Not Spam once; ensure SPF (and DKIM) for givingshelf.net include SES. |
| Lambda "require is not defined" | Use ES module syntax: `import`/`export`, not `require`/`exports`. |
| Lambda init error / missing mailparser | Include `node_modules` (with `mailparser`) in the deployment zip or attach a layer. |

---

## Summary

- **MX** → SES receives mail for `givingshelf.net`.
- **Receipt rule** (domain `givingshelf.net`) → S3 + Lambda.
- **S3** stores raw message; key = message ID (no prefix).
- **Lambda** reads from S3, parses with `mailparser`, sends new email via `SendEmail` from `FORWARD_FROM` to `FORWARD_TO` with original subject and HTML body, and "Forwarded from" / "Original subject" in the body.
- **IAM:** Lambda role needs `s3:GetObject` and `ses:SendEmail`; bucket policy allows SES to `PutObject` for the receipt rule.
