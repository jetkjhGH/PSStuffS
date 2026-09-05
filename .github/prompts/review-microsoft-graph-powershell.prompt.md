---
description: "Review an active Microsoft Graph PowerShell script independently, or explicitly review a requested diff or change"
name: "Review Microsoft Graph PowerShell Script"
argument-hint: "Review the active script, selection, or specify a diff/change review"
agent: "agent"
---
Review the Microsoft Graph PowerShell script or change as a production-oriented utility intended to be tested before use in a customer tenant. Distinguish genuine portability or safety defects from intentional Microsoft or SDS service-defined constants.

Use this priority:

1. If the user supplies a review target or description, follow that description.
2. If an active editor selection is present, review the selection in the context of its containing file.
3. Otherwise, review the complete active editor file as a standalone script.
4. Inspect the working-tree diff only when the user explicitly asks to review changes, a diff, or a patch.

Do not infer that the active file is related to the current conversation. Treat it as an independent review target unless the user says otherwise. Treat the repository's `AGENTS.md` as authoritative guidance.

Review target: ${input:target:Review the active script as a standalone file}
Active file:
${file}
Active editor selection:
${selection}

Prioritize actionable findings over summaries. Check for:
- Incorrect Microsoft Graph PowerShell SDK commands, parameter usage, module assumptions, scopes, resource types, or API behavior.
- Authentication and connection handling that violates the repository convention that scripts use existing sessions and do not connect automatically.
- Tenant-writing operations, `SupportsShouldProcess`, `-WhatIf` behavior, confirmation flow, destructive actions, and accidental execution against an unconfirmed tenant.
- Error handling, validation, pagination, null or empty results, idempotency, per-item failures, and whether recoverable problems are reported clearly.
- Customer-tenant-specific identifiers, such as tenant, user, group, or subscription IDs, embedded in production scripts instead of being resolved or supplied as input.
- Preserve the established SDS education extension attribute, `Section` marker, and standard SDS `resourceBehaviorOptions` and `creationOptions`. Do not flag these service-defined constants or recommend replacing them with values from Teams-client-created classes unless the script changes the SDS provisioning model or the user explicitly requests that change.
- Regression risks to existing parameters, CSV output paths or columns, interactive validation loops, and documented script behavior.
- Focused tests or parse checks that are missing for the reviewed behavior.

Report findings first, ordered by severity: critical, high, medium, then low. For each finding, include the issue, why it matters, and a concrete fix. Use workspace-relative clickable file links with line numbers when possible. Do not report stylistic preferences unless they create a correctness, safety, compatibility, or maintainability risk.

After the findings, include brief sections for open questions or assumptions, recommended focused validation, and a concise review summary. If no findings are present, say so clearly and identify any remaining test or environment gaps. Do not modify files unless explicitly requested.
