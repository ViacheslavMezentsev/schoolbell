# Collaboration workflow

[Русский](WORKFLOW.md) · [Rules](../AGENTS.md) · [Migration](MIGRATION.md)

The owner selects and accepts stages, pushes and lands branches, and publishes
releases and Pages. Codex prepares changes, checks, documentation and signed
commits. No new pull requests. Preserve other people's work.

1. Verify the clean worktree and remote main HEAD; branch as codex/<task>.
2. Agree scope and observable outcomes. Documentation migration changes no runtime contract.
3. Update relevant documents, TODO and bilingual changelogs; run focused checks
   and git diff --check. `make all` checks archive, build and Lua/C/UI/IPK behavior; it does not
   cross-build MIPS dependencies or perform hardware acceptance.
4. Edit/test in WSL; sign using Windows Git against the same UNC worktree and
   its configured SSH key. Never copy private keys, disable signing or substitute
   an unsigned commit. Verify with git verify-commit HEAD and %G?, then check
   Linux Git status and file modes as well.
5. Owner pushes the branch; Schoolbell CI must pass for that exact HEAD before
   a fast-forward merge. A previous green run does not count.
6. Device installation requires its own scope, verified backup and rollback
   artifacts. Distinguish development and acceptance targets. Do not enable
   automatic bells, sound or change time/NTP/network without authorization.
7. Give short UI steps, preserve unsaved edits and resolve unknown write outcomes
   before retrying. Source synchronization is not Pages publication or hardware testing.
8. Keep raw experiments, failures, backups and identifiers private; publish
   verified conclusions. Refresh TODO and recheck Git after owner reports a merge.

Push with `git push -u origin BRANCH`; inspect `gh run list --branch BRANCH`,
`gh run view RUN_ID --json headSha,conclusion` and `gh run watch RUN_ID --exit-status`.
After exact-HEAD CI passes: `git switch main`, `git pull --ff-only origin main`,
`git merge --ff-only BRANCH`, `git push origin main`.
The WSL git land helper is tested in temporary local repositories: main,
fast-forward, atomic push and topic deletion. After exact-HEAD CI, `git land BRANCH`
is supported. It does not check CI itself and deletes the completed topic branch.
Never run it with a dirty tree or a mismatched CI SHA.
If fast-forward fails, resolve integration explicitly and rerun CI.

After migration verification the owner creates a separate schoolbell workspace.
The current workspace then continues the core project. For now schoolbell work
remains in this conversation but is edited only in its own WSL checkout.
