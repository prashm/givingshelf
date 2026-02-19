# AWS SES Setup with BYODKIM

Step-by-step guide for setting up Amazon Simple Email Service (SES) in the AWS Console with **BYODKIM** (Bring Your Own DKIM) for `givingshelf.net`.

## Why BYODKIM?

- **Single DNS record** instead of three (Easy DKIM uses three CNAME records)
- **Key rotation** – You control when and how often to rotate DKIM keys
- Same deliverability and authentication benefits as Easy DKIM

---

## Prerequisites

- Access to the DNS provider for `givingshelf.net` (Route 53, Cloudflare, GoDaddy, etc.)
- AWS account with console access
- `openssl` installed (built-in on macOS/Linux)

---

## Part 1: Generate DKIM Key Pair

Do this once. Store the private key securely; you will paste it into SES. The public key goes into DNS.

### Step 1.1: Generate Private Key

```bash
# 2048-bit RSA key (1024–2048 supported)
openssl genrsa -f4 -out givingshelf-dkim-private.pem 2048
```

### Step 1.2: Generate Public Key

```bash
openssl rsa -in givingshelf-dkim-private.pem -outform PEM -pubout -out givingshelf-dkim-public.pem
```

### Step 1.3: Choose a Selector

Pick a short name for your DKIM selector (e.g. `ses`, `mail`, `dkim1`). We'll use `ses` in this guide.

---

## Part 2: Add DNS TXT Record

Add the public key to your domain's DNS before configuring SES.

### Step 2.1: Prepare the Public Key Value

The DNS TXT value must be a single line in the format `p=<public_key>`.

1. Open `givingshelf-dkim-public.pem`
2. Remove the lines `-----BEGIN PUBLIC KEY-----` and `-----END PUBLIC KEY-----`
3. Remove all line breaks so the key is one continuous string
4. Prefix with `p=` (no space)

**Example format:**
```
p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
```

### Step 2.2: Create TXT Record

| Field   | Value                                                                 |
|---------|-----------------------------------------------------------------------|
| **Name**  | `ses._domainkey.givingshelf.net` (or `ses._domainkey` if your DNS auto-appends the domain) |
| **Type**  | TXT                                                                   |
| **Value** | `p=<your_single_line_public_key>`                                     |
| **TTL**   | 300 (or default)                                                      |

**Route 53 example:** Hosted zone → Create record → Name: `ses._domainkey` → Type: TXT → Value: `p=MIIB...`

Wait a few minutes and verify with:
```bash
dig TXT ses._domainkey.givingshelf.net +short
```

---

## Part 3: Create Domain Identity in SES with BYODKIM

### Step 3.1: Open SES Console

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Set region to **us-west-2** (Oregon) to match your app
3. Go to **Services** → **Simple Email Service** (or search "SES")
4. In the left nav: **Configuration** → **Verified identities**

### Step 3.2: Create Identity

1. Click **Create identity**
2. **Identity type:** Domain
3. **Domain:** `givingshelf.net` (no `www`)
4. Leave **Assign a default configuration set** unchecked (unless you use one)
5. Leave **Use a custom MAIL FROM domain** unchecked (optional, can add later)

### Step 3.3: Configure BYODKIM

Under **Verifying your domain**, expand **Advanced DKIM settings**:

1. **Identity type:** Select **Provide DKIM authentication token (BYODKIM)**

2. **Private key:**
   - Open `givingshelf-dkim-private.pem`
   - Remove `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
   - Remove all line breaks (single continuous string)
   - Paste into the field

3. **Selector name:** `ses` (must match the DNS record: `ses._domainkey.givingshelf.net`)

4. **DKIM signatures:** Ensure **Enabled** is checked

5. Click **Create identity**

---

## Part 4: Verify Domain

SES will check DNS for your TXT record. Verification can take up to **72 hours**; often completes within minutes.

1. In **Verified identities**, click `givingshelf.net`
2. On the **Authentication** tab, find **DomainKeys Identified Mail (DKIM)**
3. **DKIM configuration** should show **Successful** when verified
4. **Identity status** in the Summary pane should show **Verified**

If it stays **Pending**, confirm:
- DNS record name is `ses._domainkey.givingshelf.net`
- TXT value is exactly `p=<public_key>` with no extra spaces or line breaks

---

## Part 5: Create SMTP Credentials

Your Rails app connects to SES over SMTP. You need SMTP credentials for `us-west-2`.

### Step 5.1: Create SMTP User

1. In SES, left nav: **Account dashboard** or **SMTP settings**
2. Click **SMTP settings** in the left nav
3. Click **Create SMTP Credentials** (opens IAM console)

### Step 5.2: IAM User

1. **User name:** `givingshelf-ses-smtp` (or similar)
2. Click **Create user**
3. Click **Show** under SMTP password
4. **Download .csv** or copy credentials to a secure place (you won't see the password again)

The CSV contains:
- **SMTP username** (IAM Access Key ID)
- **SMTP password** (not your normal AWS secret key)

### Step 5.3: SMTP Endpoint

For **us-west-2**:
- **Server:** `email-smtp.us-west-2.amazonaws.com`
- **Port:** 587 (STARTTLS)

---

## Part 6: Request Production Access (If in Sandbox)

New SES accounts start in **sandbox**:
- 200 messages per 24 hours
- 1 message per second
- Can only send to verified identities

To send to any recipient:

1. SES console → **Account dashboard**
2. Click **View Get set up page** → **Request production access**
3. Fill out the form:
   - **Mail type:** Transactional (for app notifications)
   - **Website URL:** `https://givingshelf.net`
   - **Use case:** Describe Givingshelf (book sharing, notifications, etc.)
4. Submit

Initial response typically within 24 hours via an AWS Support case.

---

## Part 7: Environment Variables

Store these in AWS Secrets Manager (or your secrets store) and load them on the EC2 instance.

| Variable        | Value                                      |
|-----------------|--------------------------------------------|
| `SMTP_ADDRESS`  | `email-smtp.us-west-2.amazonaws.com`       |
| `SMTP_USER_NAME`| Your SMTP username (Access Key ID)         |
| `SMTP_PASSWORD` | Your SMTP password                         |

### Add to Secrets Manager

Ensure your secret `givingshelf/prod/env` includes:

```json
{
  "SMTP_ADDRESS": "email-smtp.us-west-2.amazonaws.com",
  "SMTP_USER_NAME": "AKIA...",
  "SMTP_PASSWORD": "your-smtp-password"
}
```

The deploy flow uses `deploy/fetch-givingshelf-secrets.sh` to pull these into `/etc/givingshelf/.env.production`. Rails reads them in `config/environments/production.rb`.

---

## Part 8: Add BYODKIM to an Existing Domain

If `givingshelf.net` is already verified with Easy DKIM and you want to switch to BYODKIM:

1. SES → **Verified identities** → select `givingshelf.net`
2. **Authentication** tab → **DomainKeys Identified Mail (DKIM)** → **Edit**
3. **Identity type:** Select **Provide DKIM authentication token (BYODKIM)**
4. Paste the private key (single line, no PEM headers)
5. **Selector name:** `ses`
6. **DKIM signatures:** Enabled
7. **Save changes**

**Note:** During the switch, emails may be sent without DKIM until verification completes. Consider doing this during low-traffic periods.

---

## Verification Checklist

- [ ] DKIM TXT record added for `ses._domainkey.givingshelf.net`
- [ ] Domain identity created in SES with BYODKIM
- [ ] DKIM configuration shows **Successful**
- [ ] Identity status shows **Verified**
- [ ] SMTP credentials created and stored securely
- [ ] `SMTP_ADDRESS`, `SMTP_USER_NAME`, `SMTP_PASSWORD` in production secrets
- [ ] Production access requested if needed

---

## References

- [AWS: Provide your own DKIM (BYODKIM)](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dkim-bring-your-own.html)
- [AWS: SES SMTP credentials](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html)
- [AWS: Request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html)
