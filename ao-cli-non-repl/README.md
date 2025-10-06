# AO CLI Non-REPL

Universal AO CLI tool for testing and automating any AO dApp (replaces AOS REPL)

## Overview

This is a non-interactive command-line interface for the AO (Arweave Offchain) ecosystem. Unlike the official `aos` REPL tool, this CLI exits after each command completes, making it perfect for automation, testing, and CI/CD pipelines.

## Features

- ✅ **Non-REPL Design**: Each command executes and exits immediately
- ✅ **Full AO Compatibility**: Works with all AO processes and dApps
- ✅ **Automatic Module Loading**: Resolves and bundles Lua dependencies (equivalent to `.load` in AOS)
- ✅ **Rich Output Formatting**: Clean JSON parsing and readable results
- ✅ **Proxy Support**: Automatic proxy detection and configuration
- ✅ **Comprehensive Commands**: spawn, eval, load, message, inbox operations

## Installation

### Prerequisites

- Node.js 18+
- npm
- AO wallet file (`~/.aos.json`)

### Setup

```bash
cd ao-cli-non-repl
npm install
npm link  # Makes 'ao-cli' available globally
```

### Verify Installation

```bash
ao-cli --version
ao-cli --help
```

## Publishing to npm

This package is published as a scoped package for security and professionalism.

### For Maintainers

```bash
# 1. Login to npm
npm login

# 2. Test package
npm run prepublishOnly

# 3. Publish (scoped package requires --access public)
npm publish --access public

# 4. Update version for new releases
npm version patch  # or minor/major
npm publish --access public
```

### For Users

```bash
# Install globally
npm install -g @dddappp/ao-cli

# Or use with npx
npx @dddappp/ao-cli --help
```

> **Security Note**: Always verify package downloads and check the official npm page at https://www.npmjs.com/package/@dddappp/ao-cli

## Usage

### Basic Commands

#### Spawn a Process
```bash
# Spawn with default module
ao-cli spawn default --name "my-process-$(date +%s)"

# Spawn with custom module
ao-cli spawn <module-id> --name "my-process"
```

#### Load Lua Code with Dependencies
```bash
# Load a Lua file (equivalent to '.load' in AOS REPL)
ao-cli load <process-id> path/to/app.lua --wait
```

> **注意**：如果进程ID以 `-` 开头，您可以使用以下任一种方法：
> - 使用 `--` 分隔符：`ao-cli load -- <process-id> path/to/app.lua --wait`
> - 或者引号包裹：`ao-cli load "<process-id>" path/to/app.lua --wait`

#### Send Messages
```bash
# Send a message and wait for result
ao-cli message <process-id> ActionName --data '{"key": "value"}' --wait

# Send without waiting
ao-cli message <process-id> ActionName --data "hello"
```

> **注意**：如果进程ID以 `-` 开头，您可以使用以下任一种方法：
> - 使用 `--` 分隔符：`ao-cli message -- <process-id> ActionName ...`
> - 或者引号包裹：`ao-cli message "<process-id>" ActionName ...`

#### Evaluate Lua Code
```bash
# Evaluate code from file
ao-cli eval <process-id> --file script.lua --wait

# Evaluate code string
ao-cli eval <process-id> --code 'return "hello"' --wait
```

> **注意**：如果进程ID以 `-` 开头，您可以使用以下任一种方法：
> - 使用 `--` 分隔符：`ao-cli eval -- <process-id> --file script.lua --wait`
> - 或者引号包裹：`ao-cli eval "<process-id>" --file script.lua --wait`

#### Check Inbox
```bash
# Get latest message
ao-cli inbox <process-id> --latest

# Get all messages
ao-cli inbox <process-id> --all

# Wait for new messages
ao-cli inbox <process-id> --wait --timeout 30
```

> **📋 Inbox机制说明**：Inbox是进程内部的全局变量，记录所有接收到的消息。要让消息进入Inbox，需要在进程内部执行Send操作（使用`ao-cli eval`），外部API调用不会让消息进入Inbox。
>
> **注意**：如果进程ID以 `-` 开头，您可以使用以下任一种方法：
> - 使用 `--` 分隔符：`ao-cli inbox -- <process-id> --latest`
> - 或者引号包裹：`ao-cli inbox "<process-id>" --latest`

### Advanced Usage

#### Environment Variables

```bash
# Proxy settings (auto-detected if not set)
export HTTPS_PROXY=http://proxy:port
export HTTP_PROXY=http://proxy:port

# Gateway and scheduler
export GATEWAY_URL=https://arweave.net
export SCHEDULER=http://scheduler.url

# Wallet location
export WALLET_PATH=/path/to/wallet.json
```

#### Custom Wallet

```bash
ao-cli spawn default --name test --wallet /path/to/custom/wallet.json
```

## Examples

### Complete Blog dApp Test

```bash
#!/bin/bash

# 1. Spawn process
PROCESS_ID=$(ao-cli spawn default --name "blog-test-$(date +%s)" | grep "Process ID:" | awk '{print $4}')

# 2. Load application
ao-cli load "$PROCESS_ID" src/a_ao_demo.lua --wait

# 3. Create article
ao-cli message "$PROCESS_ID" CreateArticle --data '{"title": "My Title", "body": "My Content"}' --wait

# 4. Get article
ao-cli message "$PROCESS_ID" GetArticle --data '1' --wait

# 5. Check inbox
ao-cli inbox "$PROCESS_ID" --latest
```

### Automated Testing

See `tests/run-blog-tests.sh` for a complete automated test suite that reproduces the official AO testing documentation.

## Command Reference

### `spawn <moduleId> [options]`

Spawn a new AO process.

**Options:**
- `--name <name>`: Process name
- `--wallet <path>`: Custom wallet file path

### `load <processId> <file> [options]`

Load Lua file with automatic dependency resolution.

**Options:**
- `--wait`: Wait for evaluation result

### `eval <processId> [options]`

Evaluate Lua code.

**Options:**
- `--file <path>`: Lua file to evaluate
- `--code <string>`: Lua code string
- `--wait`: Wait for result

### `message <processId> <action> [options]`

Send a message to a process.

**Options:**
- `--data <json>`: Message data
- `--tags <json>`: Additional tags
- `--wait`: Wait for result

### `inbox <processId> [options]`

Check process inbox.

**Options:**
- `--latest`: Get latest message
- `--all`: Get all messages
- `--wait`: Wait for new messages
- `--timeout <seconds>`: Wait timeout (default: 30)

## Output Format

All commands provide clean, readable output:

```
📋 MESSAGE #1 RESULT:
⛽ Gas Used: 0
📨 Messages: 1 item(s)
   1. From: Process123
      Target: Process456
      Data: {
        "result": {
          "article_id": 1,
          "title": "My Article",
          "body": "Content here..."
        }
      }
```

## Comparison with AOS REPL

| Operation               | AOS REPL                | AO CLI                                   |
| ------------------------ | ----------------------- | ---------------------------------------- |
| Spawn                    | `aos my-process`        | `ao-cli spawn default --name my-process` |
| Load Code                | `.load app.lua`         | `ao-cli load <pid> app.lua --wait`       |
| Send Message             | `Send({Action="Test"})` | `ao-cli message <pid> Test --wait`       |
| Send Message (Inbox测试) | `Send({Action="Test"})` | `ao-cli eval <pid> --data "Send({Action='Test'})" --wait` |
| Check Inbox              | `Inbox[#Inbox]`         | `ao-cli inbox <pid> --latest`            |
| Eval Code                | `eval code`             | `ao-cli eval <pid> --code "code" --wait` |

> **💡 重要说明**：
> - 要测试Inbox功能，必须使用`ao-cli eval`在进程内部执行Send操作。直接使用`ao-cli message`不会让回复消息进入Inbox，因为那是外部API调用。
> - 如果进程ID以 `-` 开头，您可以使用 `--` 分隔符或引号包裹，例如：`ao-cli load -- <pid> app.lua --wait` 或 `ao-cli load "<pid>" app.lua --wait`。

## Future Improvements (TODOs)

### 🔄 Planned Enhancements

1. **Dependency Updates**
   - Regularly update `@permaweb/aoconnect` and other dependencies to latest versions
   - Add automated dependency vulnerability scanning

2. **Enhanced Error Handling**
   - Add more granular error messages for different failure scenarios
   - Implement retry logic for network timeouts
   - Add better validation for process IDs and message formats

3. **Performance Optimizations**
   - Add module caching to speed up repeated code loading
   - Implement parallel processing for batch operations
   - Add connection pooling for multiple AO operations

4. **Testing Improvements**
   - Add unit tests for individual CLI commands
   - Implement integration tests with different AO dApps
   - Add performance benchmarking tests

5. **Developer Experience**
   - Add shell completion scripts (bash/zsh/fish)
   - Create VS Code extension for AO development
   - Add interactive mode option alongside non-REPL design

6. **Documentation**
   - Add video tutorials for common use cases
   - Create cookbook with real-world AO dApp examples
   - Add API reference documentation

7. **CI/CD Integration**
   - Add GitHub Actions workflows for automated testing
   - Create Docker images for easy deployment
   - Add pre-built binaries for multiple platforms

8. **Monitoring & Observability**
   - Add metrics collection for operation performance
   - Implement structured logging with log levels
   - Add health check endpoints for monitoring

### 🤝 Contributing

We welcome contributions! Please see our contribution guidelines and feel free to submit issues or pull requests.

## Troubleshooting

### Common Issues

1. **"fetch failed"**
   - Check proxy settings
   - Verify network connectivity

2. **"Wallet file not found"**
   ```bash
   # Ensure wallet exists
   ls -la ~/.aos.json
   ```

3. **"Module not found" errors**
   - Check Lua file paths
   - Ensure dependencies are in the same directory

4. **Empty inbox results**
   - Use `--wait` option
   - Increase timeout with `--timeout`

### Debug Mode

Enable verbose logging:
```bash
export DEBUG=ao-cli:*
```

## Development

### Project Structure

```
ao-cli-non-repl/
├── ao-cli.js          # Main CLI implementation
├── package.json       # Dependencies and scripts
├── tests/            # Test suite
│   ├── run-blog-tests.sh  # Complete test automation
│   └── README.md     # Test documentation
└── README.md         # This file
```

### Adding New Commands

1. Add command definition in `ao-cli.js`
2. Implement handler function
3. Update this README

### Running Tests

```bash
cd tests
./run-blog-tests.sh
```

## License

ISC
