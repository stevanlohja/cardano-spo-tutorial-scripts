#!/bin/bash

# Launch multipass instances
echo "✨ Creating cute little instances! ✨"
multipass launch -n cn1 -c 2 -m 4gb -d 40gb
multipass launch -n cn2 -c 2 -m 4gb -d 40gb
echo "🐾 Instances are born! 🐾"

instances=("cn1" "cn2")

# Function to check if architecture is ARM
is_arm_architecture() {
    if uname -m | grep -q "arm" || uname -m | grep -q "aarch64"; then
        return 0  # True (ARM detected)
    else
        return 1  # False (not ARM)
    fi
}

for instance in "${instances[@]}"; do
    echo "🚀 Running commands on $instance... 🌟"

    multipass exec "$instance" -- bash -c '
        # Always run the standard setup first
        echo "🐼 Running standard setup for all architectures... 🐼"
        sudo apt update -y && sudo apt upgrade -y
        mkdir -p "$HOME/tmp" && cd "$HOME/tmp"
        sudo apt -y install curl
        echo "🐸 Downloading guild-deploy script..."
        curl -sS -o guild-deploy.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/guild-deploy.sh
        chmod 755 guild-deploy.sh
        ./guild-deploy.sh -b master -n preview -t cnode -s pdlcowx
        . "${HOME}/.bashrc"
        cd ~/git || mkdir -p ~/git && cd ~/git
        echo "🦋 Cloning cardano-node repository..."
        git clone https://github.com/intersectmbo/cardano-node || (cd cardano-node && git fetch --tags --recurse-submodules --all && git pull)
        cd cardano-node
        git checkout $(curl -sLf https://api.github.com/repos/intersectmbo/cardano-node/releases/latest | jq -r .tag_name)
        $CNODE_HOME/scripts/cabal-build-all.sh

        # Check architecture and run additional ARM-specific steps if needed
        if uname -m | grep -q "arm" || uname -m | grep -q "aarch64"; then
            # ARM-specific additional commands
            echo "🐙 Detected ARM architecture, running additional ARM-specific setup... 🐙"
            ARCHIVE_URL="https://github.com/armada-alliance/cardano-node-binaries/raw/refs/heads/main/static-binaries/cardano-10_1_4-aarch64-static-musl-ghc_966.tar.zst"
            ADDRESS_URL="https://github.com/armada-alliance/cardano-node-binaries/raw/refs/heads/main/miscellaneous/cardano-address.zip"
            DEST_DIR="$HOME/.local/bin"
            mkdir -p "$DEST_DIR"
            
            echo "🐳 Downloading cardano-node archive..."
            curl -L "$ARCHIVE_URL" -o cardano-10_1_4.tar.zst
            if [ $? -ne 0 ]; then
                echo "😿 Failed to download the cardano-node archive."
                exit 1
            fi
            
            echo "🦄 Downloading cardano-address archive..."
            curl -L "$ADDRESS_URL" -o cardano-address.zip
            if [ $? -ne 0 ]; then
                echo "😿 Failed to download the cardano-address archive."
                exit 1
            fi

            if ! command -v zstd &> /dev/null; then
                sudo apt-get update -y
                sudo apt-get install -y zstd unzip
            elif ! command -v unzip &> /dev/null; then
                sudo apt-get install -y unzip
            fi

            echo "🐰 Extracting cardano-node archive..."
            zstd -d -c cardano-10_1_4.tar.zst | tar -x -C "$DEST_DIR" --strip-components=1
            if [ $? -ne 0 ]; then
                echo "😿 Failed to extract the cardano-node archive."
                exit 1
            fi

            echo "🦊 Extracting cardano-address archive..."
            unzip -d "$DEST_DIR" cardano-address.zip
            if [ $? -ne 0 ]; then
                echo "😿 Failed to extract the cardano-address archive."
                exit 1
            fi

            rm cardano-10_1_4.tar.zst cardano-address.zip
            echo "🌈 Additional ARM archives downloaded and extracted successfully to $DEST_DIR"
        fi
    '

    echo "🎉 Finished running commands on $instance! 🐾✨"
done