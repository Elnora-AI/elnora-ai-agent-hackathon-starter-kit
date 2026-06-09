# RECOVERY.md — Common Failures and Fixes

If something went wrong during install, find your symptom below. Each fix
takes 1–5 minutes. If your problem isn't listed, ask Claude or share
`~/claude-starter-install.log` (macOS) / `%USERPROFILE%\claude-starter-install.log`
(Windows) with whoever is supporting you.

---

## 1. "Claude says I need a Pro/Max plan to use it"

**Symptom:** `claude` runs but says "subscription required" or similar after
browser login.

**Fix:** the workshop and this kit assume you have an active **Claude Pro or
Max subscription**. Visit `https://claude.com/upgrade`, subscribe, then run
`claude` again to log back in. Once `claude` opens normally, re-run the install
one-liner — it'll pick up where it left off (already-installed tools are
skipped).

---

## 2. "Xcode dialog popped up and I closed it" (macOS)

**Symptom:** the install script paused on a step like "Installing Git" and
then errored with `xcode-select: error: command line tools are missing`.

**Fix:** trigger the install again and click **Install** when the system
dialog appears. It takes 5–10 minutes.

```
xcode-select --install
```

When it finishes, re-run the install one-liner.

---

## 3. "Nothing downloads / network seems blocked"

**Symptom:** the install hangs or errors with `Could not resolve host` /
`SSL handshake failed` / `407 Proxy Authentication`.

**Fix:** something between you and the internet is blocking the install — a
corporate firewall, a Wi-Fi captive portal, or VPN. Try in this order:

1. Open a browser and confirm you can reach `https://claude.ai` and
   `https://github.com`. If any are blocked, that's your problem — switch to a
   personal Wi-Fi or hotspot.
2. If you're behind a corporate proxy and you know the URL, tell your shell:
   ```
   export HTTPS_PROXY=http://your-proxy:port
   export HTTP_PROXY=http://your-proxy:port
   ```
   On Windows PowerShell:
   ```
   $env:HTTPS_PROXY = "http://your-proxy:port"
   $env:HTTP_PROXY  = "http://your-proxy:port"
   ```
   Then re-run the install one-liner.
3. If you're at a workshop, ask the facilitator — they may have a hotspot.

---

## 4. "GitHub auth fails" (Phase 2 step 6b)

**Symptom:** Claude is walking you through `gh auth login` and something
goes wrong — the browser doesn't open, the one-time code expired, or
`gh auth status` keeps reporting "not logged in" after you finished the
flow.

**Fix — pick the matching scenario:**

- **Browser doesn't open / your network blocks `github.com` OAuth.** Fall
  back to a personal access token. Create one at
  `https://github.com/settings/tokens?type=beta` with `repo` and `workflow`
  scope, then:
  ```
  echo <your-token> | gh auth login --hostname github.com --git-protocol https --with-token
  ```
- **One-time code expired.** Just re-run:
  ```
  gh auth login --hostname github.com --git-protocol https --web
  ```
- **Wrong GitHub account selected in the browser.** Log out and start fresh:
  ```
  gh auth logout --hostname github.com
  gh auth login --hostname github.com --git-protocol https --web
  ```
- **`gh auth status` keeps saying "not logged in" after a successful flow.**
  Check that `~/.config/gh/hosts.yml` exists and is readable. On locked-down
  corporate machines the config dir may be unwriteable; ask IT or run from
  a personal account.

Once `gh auth status` reports "Logged in to github.com" with
`git_protocol: https`, tell Claude "I'm logged in" and it'll continue from
where it stopped.

---

## 5. "GitHub repo creation fails" (Phase 2 step 6c)

**Symptom:** `gh repo create` errors out, or the repo is created but the
push didn't land on `origin/main`.

**Fix:**

- **`name already exists on this account`.** Pick a different name and tell
  Claude. `gh repo create` doesn't partially create state, so retries are
  safe. Suggestions: `<your-username>-agents-2`, `<your-username>-elnora`,
  `<your-username>-lab`.
- **`permission denied` pushing to the new repo.** The `gh` token is
  missing the `repo` scope. Refresh it:
  ```
  gh auth refresh -s repo
  ```
- **Push appeared to succeed but `git rev-parse HEAD` doesn't match
  `git rev-parse origin/main`.** Push explicitly:
  ```
  git push -u origin main
  ```
  If that fails with `non-fast-forward`, the GitHub repo was pre-seeded
  (e.g. you accidentally added a README from the web UI). The cleanest fix
  is to delete and recreate from the same local state:
  ```
  gh repo delete <repo-name> --yes
  gh repo create <repo-name> --private --source=. --push
  ```

---

## 6. "VS Code opened but Claude never started" (auto-task prompt missed)

**Symptom:** Phase 1 said `Opening VS Code - Claude will continue Phase 2
setup there`, your bootstrap terminal exited cleanly, VS Code came up at
the starter-kit folder, but no terminal panel ever opened with Claude
running. You may have seen a yellow popup at the bottom-right and dismissed
it without reading.

**What happened:** VS Code has *two* one-time security prompts on first
open of a workspace with auto-running tasks:

1. **"Do you trust the authors of the files in this folder?"** — Workspace
   Trust. Without this, no task can run at all.
2. **"This workspace has tasks ... that can launch processes automatically.
   Do you want to allow automatic tasks ...?"** — the `task.allowAutomaticTasks`
   gate. Without this, even trusted workspaces don't auto-fire `runOn`
   tasks. **This is the prompt people miss** because it appears as a small
   notification, not a blocking dialog.

If you clicked **Disallow**, dismissed the prompt, or just didn't notice
it, the handoff task is configured but inert.

**Fix — pick whichever you prefer:**

- **Just run the handoff manually (fastest).** Open the integrated terminal
  in VS Code (Ctrl+backtick, or `View → Terminal`) and run:
  ```
  bash .vscode/run-handoff.sh           # macOS / Linux
  ```
  ```
  powershell -ExecutionPolicy Bypass -File .vscode\run-handoff.ps1   # Windows
  ```
  This is the same script the auto-task fires; it consumes the same
  one-shot sentinel and starts Claude on the Phase 2 prompt.

- **Re-arm the auto-task for next time.** Open VS Code's command palette
  (`Cmd+Shift+P` / `Ctrl+Shift+P`) and run **`Tasks: Manage Automatic Tasks`**.
  Pick **Allow Automatic Tasks**. VS Code remembers this globally, so every
  future trusted workspace (including future starter-kit installs) will
  auto-fire without prompting.

- **Just open Claude in the terminal yourself.** If you'd rather skip the
  task system entirely, run:
  ```
  claude "Phase 1 of the Elnora AI Agent Hackathon Starter Kit install just completed. Please read INSTALL_FOR_AGENTS.md in this directory and finish Phase 2 setup."
  ```
  This is byte-identical to what the helper does.

Any of the three gets you to the same place: Claude reading
`INSTALL_FOR_AGENTS.md` and finishing Phase 2.

---

## 7. "The setup script stopped or half-failed — how do I continue?"

**Symptom:** the script exited part-way through (most often at the **Claude
Code sign-in step**, the single most common place people stop), or it finished
but printed `⚠ N step(s) failed — remediation below`.

**Fix:** just run it again. The script **resumes where it left off** — it
remembers your progress in a small checkpoint file, so already-installed tools
and finished steps are skipped instantly, and you land right back at the step
that stopped you. Nothing you already did is repeated or lost.

1. If a step errored, read the remediation hints it printed and fix the
   underlying issue (most often: a system dialog you missed, a network
   timeout, or a Claude sign-in you didn't complete).
2. Re-run the **same command you started with**:
   - macOS: `bash setup-mac.sh`
   - Windows: `.\setup-windows.ps1`
   When it reaches the top it prints `Resuming where a previous run left
   off` so you know it's continuing, not starting over.

**Want a completely clean run instead?** Start from scratch with the `--fresh`
flag, which clears the saved progress:

- macOS: `bash setup-mac.sh --fresh`
- Windows: `.\setup-windows.ps1 --fresh`

If the same step fails three times in a row, stop and ask for help. Email or
share `~/claude-starter-install.log` so someone can see what's going wrong.

---

## 8. "Windows: claude launches, but doesn't update with new releases"

**Symptom:** during install you saw a yellow message about User PATH not
containing `.local\bin`, followed by "copying claude.exe to WindowsApps."

**What happened:** the upstream installer puts the exe in
`%USERPROFILE%\.local\bin` and updates User PATH so a new shell can find it.
That PATH update can fail to stick — corporate Group Policy reverting User
PATH, antivirus blocking the registry change, or a non-interactive shell that
can't refresh environment broadcast. As a fallback, `setup-windows.ps1`
**copies** the exe into `%LOCALAPPDATA%\Microsoft\WindowsApps` (always in the
default user PATH on Win10/11) so the tool launches.

The trade-off: that copy is **frozen at install time**. The upstream
auto-update path writes to `.local\bin`, which the copy ignores. So `claude`
will keep running the install-time version even after upstream releases ship.

**Fix:** re-run the installer when you want the latest version:

- **Claude Code:** `irm https://claude.ai/install.ps1 | iex`
- **Re-attempt everything else too:** re-run `setup-windows.ps1` from the kit.

**Or fix the underlying PATH issue** so the WindowsApps fallback isn't
needed at all. Open PowerShell as Administrator and check:

```
[Environment]::GetEnvironmentVariable("Path", "User")
```

If `.local\bin` is missing, add it once:

```
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$d = "$env:USERPROFILE\.local\bin"
if ($user -notlike "*$d*") {
    [Environment]::SetEnvironmentVariable("Path", "$user;$d", "User")
}
```

Then close every shell and reopen. If the addition disappears in a new
shell, your machine has a Group Policy revert active — talk to IT or
keep using the WindowsApps fallback and re-run the installer
periodically.

---

## Still stuck?

Send `~/claude-starter-install.log` (Mac/Linux) or
`%USERPROFILE%\claude-starter-install.log` (Windows) to whoever is supporting
you. That file has the full transcript — what was attempted, what failed,
exit codes, and the order things happened.
