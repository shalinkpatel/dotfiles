# Secrets and Service Accounts: Explicit Approval Required

NEVER create, overwrite, rotate, revoke, delete, or otherwise change secrets,
credentials, API keys, tokens, passwords, certificates, or secret-store entries
without the user's explicit approval for the specific operation and target.
The same rule applies to service-account configuration, roles, permissions,
scopes, and access policies, and to changing which credentials a service uses.

Shared service accounts, especially **FDE Internal** and **Model APIs**, are
production-sensitive. Never use them for experiments, credential resets, or
"fixes" that could affect other users or services without explicit approval.

Before any such change:
1. Identify the exact account, environment, and resource by name or identifier
   (never expose secret values), the proposed operation, and its expected impact.
2. Present that scope to the user and wait for explicit approval. General
   permission to investigate, fix, test, deploy, or set up a service is NOT
   permission to change its secrets or service-account access.
3. Execute only the approved change. Ask again if the target or scope changes.

This applies to direct edits and indirect effects of commands, scripts, tests,
installers, deployments, and API calls. If their effects are uncertain, STOP:
inspect read-only or ask first. Never rotate or replace credentials as an
unapproved workaround. Never print, log, commit, or copy secret values into
chat, source code, or other unapproved locations.

# Repository Workflow

## Worktrees

When working on a repository, do your work in a worktree rather than directly in the main checkout. Use `jj` workspaces (`jj workspace add`) when the repo is jj-enabled or `jj` is available; otherwise fall back to `git worktree`. This applies to any agent (including subagents) making changes in a repo.

## Directory layout

`$WORKSPACE_ROOT` (default `$HOME/dev`, e.g. `~/dev`; override per machine,
e.g. `/workspace`) is organized under two roots:

- `$WORKSPACE_ROOT/repos/` — main checkouts (baseten, dynamo, ...). Clone new repos here.
- `$WORKSPACE_ROOT/workspaces/<feature>/` — workspaces grouped by session or
  feature. Each `<feature>` folder holds the worktree for every repo that
  feature touches, so multi-repo work (or several trees of one repo) stays in
  one place. Create one with
  `cd $WORKSPACE_ROOT/repos/<repo> && jj workspace add --name <feature> $WORKSPACE_ROOT/workspaces/<feature>/<repo>`.
  A feature spanning dotfiles and baseten looks like:

  ```
  $WORKSPACE_ROOT/workspaces/my-feature/
  ├── dotfiles/   # jj workspace (name: my-feature) of the dotfiles repo
  └── baseten/    # jj workspace (name: my-feature) of the baseten repo
  ```

  Need a second tree of the same repo within one feature? Give it a distinct
  workspace name and path, e.g. `--name my-feature-2 $WORKSPACE_ROOT/workspaces/my-feature/dotfiles-2`.

Gotcha when a workspace moves or the layout changes: jj records the workspace-to-repo link as a RELATIVE path in `<workspace>/.jj/repo`, so a moved workspace breaks with "Cannot access ../..../.jj/repo". Fix by rewriting that file with the absolute path to the main repo's `.jj/repo`. When a workspace directory is deleted without `jj workspace forget`, clear the stale registration from the main repo (`jj workspace forget <name>`).

## Stacked PRs (stack-pr)

Use `stack-pr` to turn a linear series of local commits into a native GitHub
stack — one non-merge commit per pull request layer. The paired `gh stack`
extension (dukebw/gh-stack) handles remote stack state, branch pushes,
reordering, removal, and merge state.

Workflow:

1. Make one commit per reviewable layer (each commit becomes one PR).
2. `stack-pr view` — inspect the reconciliation plan. It fetches the remote
   and replays local layers in a disposable worktree; it does not change the
   source branch or GitHub.
3. `stack-pr export` — with a clean working tree, adds stable branch
   identities to commits that lack them, replays active patches onto the
   latest target, and invokes the native reconciler to create the stack. The
   source branch is never pushed.

Notes:

- `export` requires a clean working tree.
- Adding a branch identity rewrites that commit and its descendants, which
  invalidates existing commit signatures.
- The only commit metadata owned by stack-pr is the `stack-pr-branch:`
  trailer; legacy `stack-info:` trailers are rejected.

# External Communication

Never post replies to pull request reviews, Slack messages, or any other
external channel without the user's express consent. The default is to draft
a suggested reply and present it for approval — do not send anything on the
user's behalf.

This applies to anything visible to other people: PR review comments and
replies, Slack threads and DMs, GitHub issue comments, emails, and similar.

When asked to reply to something:

1. Draft the reply in the user's voice and tone.
2. Show the target (which PR, thread, or message) so the user knows exactly
   what would be sent and where.
3. Wait for explicit approval before sending. "Go ahead" or "send it" is
   approval; silence, "here's a draft", or a suggested reply is not.
