# Test ContextStream MCP Server
$env:CONTEXTSTREAM_API_KEY = "test"
$env:CONTEXTSTREAM_API_URL = "https://api.contextstream.io"

# Initialize
$initMsg = @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2024-11-05"
        capabilities = @{}
        clientInfo = @{
            name = "test"
            version = "1.0"
        }
    }
}

# Call init tool
$initToolMsg = @{
    jsonrpc = "2.0"
    id = 2
    method = "tools/call"
    params = @{
        name = "init"
        arguments = @{
            folder_path = "C:\Users\user\Documents\GitHub\HeelKawn1"
            context_hint = "game colony simulation"
            allow_no_workspace = $true
        }
    }
}

$initJson = $initMsg | ConvertTo-Json -Depth 10 -Compress
$initToolJson = $initToolMsg | ConvertTo-Json -Depth 10 -Compress

$input = "$initJson`n$initToolJson"
$input | npx -y @contextstream/mcp-server@latest 2>&1
