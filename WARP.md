# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview
This repository implements a decentralized application (Dapp) on the **AO (Arweave Overlay)** platform using a low-code approach with **DDDML (Domain-Driven Design Modeling Language)**.

**Key Architecture:**
- **Language**: Lua (for AO processes).
- **Framework**: AO, DDDML.
- **Pattern**: Microservices Architecture with **Saga Pattern** for eventual consistency.
- **Data flow**: Models (`dddml/*.yaml`) -> Generated Code (`src/`) -> Business Logic Implementation (`src/*_logic.lua`).

## Project Structure
- `dddml/`: Contains the Domain definitions (`.yaml`). This is the source of truth.
- `src/`: Contains Lua code for AO processes.
  - `*_main.lua`, `*_aggregate.lua`: **Auto-generated. DO NOT EDIT.**
  - `*_logic.lua`: Business logic implementation. **EDIT THESE.**
  - `*_config.lua`: Configuration (e.g., process IDs). **EDIT THESE.**
  - `*_mock.lua`: Mock implementations for testing. **EDIT THESE.**
- `ao-cli-non-repl/tests/`: Shell scripts for automated testing.

## Development Workflow

### 1. Modifying the Domain Model
Edit the YAML files in `dddml/` to change the schema or service definitions.

### 2. Generating Code
Run the following Docker command from the repository root to regenerate the Lua code in `src/`.
**Note**: This overwrites generated files but preserves `*_logic.lua` files if they exist.

```bash
docker run --rm \
-v .:/myapp \
wubuku/dddappp-ao:latest \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```

To generate code for **multi-process** architecture (recommended for production):

```bash
docker run --rm \
-v .:/myapp \
wubuku/dddappp-ao:master \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src \
--exposeBaseDddmlFiles \
--enableMultipleAOLuaProjects
```

### 3. Implementing Logic
Fill in the business logic in `src/*_logic.lua` files.
- **Saga Steps**: Functions usually return a closure accepting a `commit` boolean. Only modify state when `commit` is true.
- **Validation**: Perform checks before returning the closure.

## Coding Rules & Best Practices

### Data Types & Serialization
- **Messages**: All data sent via `ao.send` or `Send` MUST be JSON serializable.
  - ❌ `userdata` (e.g., `bint` objects).
  - ✅ `string`, `number`, `boolean`, `table` (arrays/objects).
- **Numbers**:
  - Transmit as **Strings** in JSON messages to preserve precision.
  - Compute as **bint** (Big Integer) internally.
  - Store as **Strings** or **bint** (if state persistence supports it, but string is safer for JSON export).
  - Example: `Quantity = "1000"` (in message) -> `bint("1000")` (in logic).

### Table Keys
- Lua tables used as maps must have keys of type: `string`, `number`, or `boolean`.
- **Complex Keys**: If a key is a composite object, `json.encode` it into a string first.
  - ❌ `InventoryTable[{productId=1, loc="A"}] = ...`
  - ✅ `InventoryTable[json.encode({productId=1, loc="A"})] = ...`

### Async & Saga
- **Handlers**: Use `Handlers.utils.hasMatchingTag("Action", "ActionName")`.
- **Error Handling**: Wrap logic in `pcall`. Use `messaging.respond` to return status.
- **State Changes**: In Saga steps, ensure state is only mutated if the transaction is committed.

## Testing

### Automated Scripts
- **Two-Process Saga Test** (Simple):
  ```bash
  ./ao-cli-non-repl/tests/run-saga-tests.sh
  ```
- **Multi-Process Saga Test** (Modules):
  ```bash
  ./ao-cli-non-repl/tests/run-saga-tests-v2.sh
  ```
- **Blog Example Test**:
  ```bash
  ./ao-cli-non-repl/tests/run-blog-tests.sh
  ```
- **Token Blueprint Test** (Mainnet):
  ```bash
  ./ao-cli-non-repl/tests/run-official-token-tests.sh
  ```
- **Legacy Token Test** (Legacy Network):
  ```bash
  ./ao-cli-non-repl/tests/run-legacy-token-tests.sh
  ```

### Manual Testing with `aos`
1. Start a process: `aos process_name`
2. Load code: `.load src/file.lua`
3. Send messages:
   ```lua
   Send({ Target = "TARGET_PID", Tags = { Action = "ActionName" }, Data = json.encode({ ... }) })
   ```
4. Debug: `Inbox[#Inbox]` to see latest message.
