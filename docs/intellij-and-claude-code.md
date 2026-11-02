# IntelliJ IDEA setup, with Claude Code

## 1. Install once

| Tool | Why | Get it |
|---|---|---|
| IntelliJ IDEA (Ultimate or Community) | Java services | jetbrains.com/idea |
| JDK 21 | Spring Boot 3.5 services | IntelliJ: File > Project Structure > SDKs > Download JDK > 21 (Temurin) |
| Docker Desktop | Db2 and the one command stack | docker.com. Give it at least 6 GB of memory |
| Node.js 22 | Angular UI | nodejs.org |
| Git | | git-scm.com |

On Apple Silicon Db2 runs under x86 emulation. It works, it is just slower to start.

## 2. Open the workspace

Keep the six repos side by side in one folder:

```
novabank/
  novabank-platform/
  novabank-api-gateway/
  novabank-auth-service/
  novabank-account-service/
  novabank-transaction-service/
  novabank-ui/
```

1. **File > Open** and pick the `novabank` folder.
2. For each service folder, right click its `pom.xml` and choose **Add as Maven Project**
   (IntelliJ usually offers this in a popup). You now have four Maven modules in one window.
3. **File > Project Structure > Project**: SDK 21, language level 21.
4. The run configurations in each repo's `.run/` folder appear in the Run menu automatically:
   *Auth Service (local)*, *Account Service (local)*, *Transaction Service (local)*, *API Gateway (local)*.

The Angular UI works in IntelliJ Ultimate (or WebStorm / VS Code). In the IntelliJ terminal:

```bash
cd novabank-ui && npm install && npm start      # http://localhost:4200
```

## 3. Daily loop

| You want | Do this |
|---|---|
| Everything running, no IDE | `./dev.sh up` in novabank-platform (Windows: `dev.cmd`) |
| Debug one service in IntelliJ | `./dev.sh db`, then Debug its run configuration. Start the others the same way or leave them in Docker (`docker compose up -d account-service`) |
| Try the UI without any backend | `cd novabank-ui && npm run start:mock` |
| Wipe the data back to the sample set | `./dev.sh reset` then `./dev.sh up` |

If one service runs in Docker and another in IntelliJ, both use `localhost` ports, so they find
each other with the default `local` profile settings.

## 4. Browse Db2 from the IDE

IntelliJ Ultimate: **Database** tool window > **+** > **Data Source** > **IBM Db2 LUW**.

| Field | Value |
|---|---|
| Host / Port | `localhost` / `50000` |
| Database | `NOVABANK` |
| User / Password | `db2inst1` / value of `DB_PASSWORD` in `novabank-platform/.env` (default `NovaBank2026`) |

Community edition: use DBeaver Community with the same settings. Schemas to look at:
`NB_AUTH.USERS`, `NB_ACCT.ACCOUNTS`, `NB_TXN.TRANSACTIONS`, `NB_TXN.V_DAILY_VOLUME`.

## 5. Claude Code in IntelliJ (works with your Claude Pro plan)

Claude Code runs as a CLI in IntelliJ's terminal; the JetBrains plugin connects the two so you
get diffs in the IDE diff viewer, your current selection as context, and IDE inspections.

**Install the CLI** (one of):

```bash
# macOS / Linux / WSL
curl -fsSL https://claude.ai/install.sh | bash
```
```powershell
# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
```
```bash
# or Homebrew / WinGet
brew install --cask claude-code
winget install Anthropic.ClaudeCode
```

Open a new terminal and check: `claude --version`.

**Install the plugin**: IntelliJ **Settings > Plugins > Marketplace**, search **Claude Code**
(the plugin is listed as "Claude Code [Beta]" by Anthropic), install, restart IntelliJ.

**First run**

1. Open IntelliJ's terminal at the repo you are working in, e.g. `novabank-transaction-service`.
2. Run `claude` and sign in with your Claude Pro account when the browser opens. No API key needed.
3. Use it:
   * `Ctrl+Esc` (Windows/Linux) or `Cmd+Esc` (Mac) opens Claude Code from the editor.
   * `Alt+Ctrl+K` (Windows/Linux) or `Cmd+Option+K` (Mac) inserts a reference to the current file and lines.
   * Proposed edits open in IntelliJ's diff viewer. Change this with `/config` > Diff tool.
   * Started `claude` in an external terminal? Type `/ide` to connect it to IntelliJ.

**What is already set up for Claude in these repos**

* `CLAUDE.md` in every repo: commands, conventions and the Db2 gotchas, so Claude follows the
  project rules without you repeating them.
* `.claude/settings.json` in every repo: blocks Claude from reading `.env` files.

**Good first prompts**

```text
explain how a transfer flows from the UI to Db2 in this project
add a "beneficiaries" table to NB_TXN and an endpoint to save a payee; update the Db2 scripts too
write a Testcontainers integration test for AccountService.transfer against Db2
```

**If something does not work**

* "Cannot launch Claude Code": `claude` is not on IntelliJ's PATH. Set the full path in
  **Settings > Tools > Claude Code [Beta] > Claude command**.
* Esc does not interrupt Claude: **Settings > Tools > Terminal**, untick "Move focus to the editor with Escape".
* Windows with WSL: set the Claude command to `wsl -d Ubuntu -- bash -lic "claude"`.
* Prefer approving each edit yourself (manual mode) in IntelliJ, since auto-accepting edits can
  also change IDE config files.

Official guide: https://code.claude.com/docs/en/jetbrains

## 6. Postman or Hoppscotch

* **Postman**: Import `api/postman/NovaBank.postman_collection.json` and the three
  `NovaBank-*.postman_environment.json` files. Pick **NovaBank local**, run the two login requests
  in folder 1, then anything else.
* **Hoppscotch** (hoppscotch.io or the desktop app): **Collections > Import > Postman collection**,
  choose the same file, then create an environment with `baseUrl = http://localhost:8080`.
  Hoppscotch in the browser cannot reach localhost directly; use the Hoppscotch desktop app or
  enable its browser extension / proxy for local calls.
