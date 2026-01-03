#!/usr/bin/env bash
set -euo pipefail

# Usage: fix_deployer_ssh.sh /path/to/new_keys.pub
# If a file is provided, it will replace /home/deployer/.ssh/authorized_keys
# after creating a timestamped backup and normalizing the file (remove CRLF,
# remove duplicate public keys, ensure safe quoting for command= option).

AUTH_DIR=/home/deployer/.ssh
AUTH_FILE=${AUTH_DIR}/authorized_keys

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 /path/to/new_keys.pub"
  echo "Create the new keys file on the server (or scp it) and pass its path."
  exit 1
fi

NEW_KEYS_FILE="$1"

if [[ ! -f "$NEW_KEYS_FILE" ]]; then
  echo "New keys file not found: $NEW_KEYS_FILE"
  exit 2
fi

mkdir -p "$AUTH_DIR"

ts=$(date +%s)
if [[ -f "$AUTH_FILE" ]]; then
  cp -p "$AUTH_FILE" "${AUTH_FILE}.bak.${ts}"
  echo "Backup created: ${AUTH_FILE}.bak.${ts}"
fi

# Normalize: remove CRLF, trim lines, remove empty lines
tmp=$(mktemp)
tr -d '\r' < "$NEW_KEYS_FILE" | sed 's/[[:space:]]*$//' | sed '/^$/d' > "$tmp"

# Remove duplicate keys by key body (field 2)
awk '!seen[$2]++ {print}' "$tmp" > "${tmp}.uniq"

# Fix basic malformed command= option lines: ensure command="..." is used
awk '
  BEGIN{ OFS=FS=" "; }
  {
    line=$0
    if (match(line, /^command=/)) {
      if (match(line, /^command="/)==0) {
        # try to extract the key (first token that looks like ssh-*)
        for(i=1;i<=NF;i++) if ($i ~ /^ssh-/) { key=$i; if(i<NF) comment=$(i+1); break }
        if(key=="") next
        print "command=\"bash -lc '\''cd /opt/iranvault && /opt/iranvault/deploy.sh'\" " key " " comment
      } else {
        print line
      }
    } else {
      print line
    }
  }
' "${tmp}.uniq" > "${AUTH_FILE}.new"

mv "${AUTH_FILE}.new" "$AUTH_FILE"
chown deployer:deployer "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
echo "Updated $AUTH_FILE"

rm -f "$tmp" "${tmp}.uniq"

echo "Done. Backup kept at ${AUTH_FILE}.bak.${ts}"
