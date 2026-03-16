#!/usr/bin/env bash

# Sets up ~/.claude by symlinking configs from this repo

set -euo pipefail

# Install gh CLI for GitHub Enterprise interaction
if ! command -v gh &>/dev/null; then
    sudo apt install -yq gh
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR"

for item in agents commands hooks skills CLAUDE.md settings.json statusline-command.sh; do
    if [ -e "$REPO_DIR/$item" ]; then
        # Remove existing directory (of per-file symlinks) so ln -sf can create a directory symlink
        if [ -d "$CLAUDE_DIR/$item" ] && [ ! -L "$CLAUDE_DIR/$item" ]; then
            rm -rf "$CLAUDE_DIR/$item"
        fi
        ln -sfn "$REPO_DIR/$item" "$CLAUDE_DIR/$item"
    fi
done

echo "Claude configs linked to $CLAUDE_DIR"

# Add MCP servers (writes to ~/.claude.json, which isn't symlinked)
# Uses jq directly instead of `claude mcp add` to avoid nesting detection errors
CLAUDE_JSON="$HOME/.claude.json"
MCP_SERVERS='{
  "agent_memory": {
    "command": "${TOOLSHED_STDIO_SHIM}",
    "args": ["agent_memory"],
    "env": {},
    "type": "stdio"
  },
  "toolshed_extras": {
    "command": "${TOOLSHED_STDIO_SHIM}",
    "args": ["google_drive.org_info.write_markdown_scratchpad.slack.web_search.compass.logscale.code_get_commit_metadata.code_get_git_file.code_get_last_commit_to_file"],
    "env": {},
    "type": "stdio"
  }
}'
if command -v jq &>/dev/null; then
    if [ -f "$CLAUDE_JSON" ]; then
        jq --argjson servers "$MCP_SERVERS" '.mcpServers = (.mcpServers // {}) + $servers' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
            && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    else
        echo "{\"mcpServers\": $MCP_SERVERS}" | jq . > "$CLAUDE_JSON"
    fi
    echo "MCP servers configured in $CLAUDE_JSON"
fi

# Fix plugin paths for devbox (only runs on devbox, not Mac)
PLUGINS_DIR="$CLAUDE_DIR/plugins"
if [ -d "$PLUGINS_DIR" ] && [ -d "/pay/home" ]; then
    DEVBOX_HOME="/pay/home/$(whoami)"
    for json_file in "$PLUGINS_DIR"/installed_plugins.json "$PLUGINS_DIR"/known_marketplaces.json; do
        if [ -f "$json_file" ]; then
            sed -i "s|/Users/[^/]*/\.claude|$DEVBOX_HOME/.claude|g" "$json_file"
        fi
    done
    echo "Plugin paths fixed for devbox"
fi
