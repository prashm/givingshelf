# /usr/local/bin/fetch-givingshelf-secrets.sh
#!/usr/bin/env bash
set -e
SECRET_NAME="givingshelf/prod/env"
REGION="us-west-2"

TMP_JSON="/tmp/givingshelf_secret.json"
DEST="/etc/givingshelf/.env.production"

mkdir -p /etc/givingshelf
aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" \
  --query SecretString --output text > $TMP_JSON

# Assume the secret is a JSON map of keys to values
jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' $TMP_JSON > $DEST
chmod 600 $DEST
rm $TMP_JSON