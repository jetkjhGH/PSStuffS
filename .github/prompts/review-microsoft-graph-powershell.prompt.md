---
description: "Review Microsoft Graph PowerShell changes for correctness, compatibility, safety, and missing tests"
name: "Review Microsoft Graph PowerShell Change"
argument-hint: "Describe the change, or leave blank to review the current diff"
agent: "agent"
---
Review the Microsoft Graph PowerShell change described below. If no specific change is provided, inspect the current working-tree diff and the nearby implementation. Treat the repository's `AGENTS.md` as authoritative guidance.

Change to review: ${input:change:Current diff and related Microsoft Graph PowerShell change}

Prioritize actionable findings over summaries. Check for:
- Incorrect Microsoft Graph PowerShell SDK commands, parameter usage, module assumptions, scopes, resource types, or API behavior.
- Authentication and connection handling that violates the repository convention that scripts use existing sessions and do not connect automatically.
- Tenant-writing operations, `SupportsShouldProcess`, `-WhatIf` behavior, confirmation flow, destructive actions, and accidental execution against an unconfirmed tenant.
- Error handling, validation, pagination, null or empty results, idempotency, per-item failures, and whether recoverable problems are reported clearly.
- Tenant-sensitive SDS extension attributes, Graph or SharePoint resource behavior values, and hard-coded tenant-specific identifiers.
- Regression risks to existing parameters, CSV output paths or columns, interactive validation loops, and documented script behavior.
- Focused tests or parse checks that are missing for the changed behavior.

Report findings first, ordered by severity: critical, high, medium, then low. For each finding, include the issue, why it matters, and a concrete fix. Use workspace-relative clickable file links with line numbers when possible. Do not report stylistic preferences unless they create a correctness, safety, compatibility, or maintainability risk.

After the findings, include brief sections for open questions or assumptions, recommended focused validation, and a concise change summary. If no findings are present, say so clearly and identify any remaining test or environment gaps. Do not modify files unless explicitly requested.
