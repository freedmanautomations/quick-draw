# Security

## Boundaries

This is a local launcher with no server, account system or remote command interface. It accepts two tool types: installed application bundles and http or https websites. App bundle identifier and path are checked again before launch. This does not pin the executable contents or the publisher signing identity; updates and local replacement code remain subject to macOS security and the user's trust in the chosen app. Website addresses with credentials or other schemes are rejected.

There is no shell-command action, executable-path action, imported action pack or plugin execution. Configurations are validated, bounded in size, and never run automatically. Local apps and websites explicitly chosen by a user can still be malicious. Quick Draw is not an application sandbox or a replacement for macOS security checks.

Settings use private permissions, bounded reads and atomic replacement. Symlink settings files and directories are refused. Cooperating instances use a shared write lock, and stale settings are refused. A different program that ignores the lock can still race a write; hostile same-user file modification is outside this app's security boundary. Unreadable originals are retained, and recovery requires an explicit action.

## Reporting

Use the repository's private vulnerability reporting feature when it is available. Otherwise, open an issue that describes the affected behavior without posting tokens, private paths, settings files, or user data. Do not include secrets in a public issue.

## Release status

Version 0.1.0 is a preview with a local ad-hoc signature, not an Apple notarized installer. Do not weaken system security settings to open a downloaded preview. Public source can be built locally with Apple's tools.

Automated checks cover validation, settings preservation, launch routing with isolated fixtures, source/archive inventory and native hidden-view rendering. A passing check is not a guarantee against every defect or a claim of testing every Mac, selected app, website or display configuration.
