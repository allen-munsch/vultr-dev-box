#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo "🚀 Vultr Instance Setup Script"
echo "==============================="
export VULTR_API_KEY=$(cat ~/.auth/vultr)
#####################################
# Settings - adjust as needed
#####################################
INSTANCE_LABEL="tiny-box-$(date +%s)"
REGION="ewr"                          # New Jersey (use: vultr-cli regions list)
PLAN="vc2-1c-1gb"                     # $5/mo 1 CPU, 1GB RAM (use: vultr-cli plans list)
OS_ID="2284"                          # Ubuntu 24.04 LTS (use: vultr-cli os list)

SSH_KEY_DIR="$HOME/.ssh/vultr"
SSH_KEY_PATH="$SSH_KEY_DIR/$INSTANCE_LABEL"

#####################################
# Check for API key
#####################################
if [[ -z "${VULTR_API_KEY:-}" ]] && [[ ! -f "$HOME/.vultr-cli.yaml" ]]; then
    echo "❌ No Vultr API key found."
    echo "   Set VULTR_API_KEY environment variable or create ~/.vultr-cli.yaml"
    echo "   Get your API key from: https://my.vultr.com/settings/#settingsapi"
    exit 1
fi

#####################################
# Generate new SSH key for this instance
#####################################
mkdir -p "$SSH_KEY_DIR"
chmod 700 "$SSH_KEY_DIR"

echo "🔑 Generating SSH key for $INSTANCE_LABEL..."
ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "$INSTANCE_LABEL" -q
chmod 600 "$SSH_KEY_PATH"
chmod 644 "${SSH_KEY_PATH}.pub"

SSH_PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")
echo "✅ SSH key created: $SSH_KEY_PATH"

#####################################
# Add SSH key to Vultr
#####################################
echo "📤 Uploading SSH key to Vultr..."
SSH_KEY_ID=$(vultr-cli ssh-key create --name "$INSTANCE_LABEL" --key "$SSH_PUB_KEY" -o json | jq -r '.ssh_key.id')
echo "✅ SSH key uploaded (ID: $SSH_KEY_ID)"

#####################################
# Create instance
#####################################
echo "🏗️  Creating instance..."
echo "   Label:  $INSTANCE_LABEL"
echo "   Region: $REGION"
echo "   Plan:   $PLAN"
echo "   OS:     Ubuntu 24.04 LTS"

INSTANCE_JSON=$(vultr-cli instance create \
    --label "$INSTANCE_LABEL" \
    --region "$REGION" \
    --plan "$PLAN" \
    --os "$OS_ID" \
    --ssh-keys "$SSH_KEY_ID" \
    -o json)

INSTANCE_ID=$(echo "$INSTANCE_JSON" | jq -r '.instance.id')
echo "✅ Instance created (ID: $INSTANCE_ID)"

#####################################
# Wait for instance to be ready
#####################################
echo "⏳ Waiting for instance to be ready..."
while true; do
    STATUS=$(vultr-cli instance get "$INSTANCE_ID" -o json | jq -r '.instance.status')
    POWER=$(vultr-cli instance get "$INSTANCE_ID" -o json | jq -r '.instance.power_status')
    
    if [[ "$STATUS" == "active" && "$POWER" == "running" ]]; then
        break
    fi
    
    echo "   Status: $STATUS, Power: $POWER - waiting..."
    sleep 5
done

#####################################
# Get instance details
#####################################
INSTANCE_INFO=$(vultr-cli instance get "$INSTANCE_ID" -o json)
IP_ADDRESS=$(echo "$INSTANCE_INFO" | jq -r '.instance.main_ip')

#####################################
# Add to SSH config
#####################################
SSH_CONFIG="$HOME/.ssh/config"
echo "" >> "$SSH_CONFIG"
echo "# Vultr: $INSTANCE_LABEL" >> "$SSH_CONFIG"
echo "Host $INSTANCE_LABEL" >> "$SSH_CONFIG"
echo "    HostName $IP_ADDRESS" >> "$SSH_CONFIG"
echo "    User root" >> "$SSH_CONFIG"
echo "    IdentityFile $SSH_KEY_PATH" >> "$SSH_CONFIG"
echo "    StrictHostKeyChecking no" >> "$SSH_CONFIG"

echo ""
echo "==============================="
echo "✅ Instance Ready!"
echo "==============================="
echo "ID:       $INSTANCE_ID"
echo "Label:    $INSTANCE_LABEL"
echo "IP:       $IP_ADDRESS"
echo "Key:      $SSH_KEY_PATH"
echo ""
echo "SSH Commands:"
echo "  ssh $INSTANCE_LABEL"
echo "  ssh -i $SSH_KEY_PATH root@$IP_ADDRESS"
echo ""

#####################################
# Wait for SSH to be available
#####################################
echo "⏳ Waiting for SSH to be available..."
for i in {1..30}; do
    if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$IP_ADDRESS" exit 2>/dev/null; then
        echo ""
        echo "🎉 SSH is ready! Connecting..."
        echo ""
        exec ssh "$INSTANCE_LABEL"
    fi
    echo "   Attempt $i/30 - SSH not ready yet..."
    sleep 5
done

echo "⚠️  SSH didn't become available in time. Try manually:"
echo "  ssh $INSTANCE_LABEL"
```

**Changes:**

1. **Dedicated key per instance** — Keys stored in `~/.ssh/vultr/<instance-label>`
2. **Auto-adds to SSH config** — So you can just `ssh tiny-box-1234567890` 
3. **Key named after instance** — Easy to identify and clean up later

After running, you'll have:
```
~/.ssh/vultr/
└── tiny-box-1734567890
└── tiny-box-1734567890.pub
```

And in `~/.ssh/config`:
```
Host tiny-box-1734567890
    HostName 123.45.67.89
    User root
    IdentityFile ~/.ssh/vultr/tiny-box-1734567890
