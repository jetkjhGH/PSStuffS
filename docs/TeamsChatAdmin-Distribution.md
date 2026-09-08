# Teams Chat Admin Distribution Runbook | [Download current ZIP](https://github.com/jetkjhGH/PSStuffS/blob/main/dist/TeamsChatAdmin-0.2.0.zip)

This package contains the Teams Chat Admin PowerShell 7 tool for Microsoft Teams chat inspection, reporting, and guarded administrative actions through Microsoft Graph.

## Package Contents

Keep this folder structure intact:

```text
TeamsChatAdmin-<version>/
  ChatManagementInterface.ps1
  README_DISTRIBUTION.md
  src/
    TeamsChatAdmin.psd1
    TeamsChatAdmin.psm1
    Authentication/
    Audit/
    Domain/
    Graph/
    Private/
    Public/
    Reporting/
    UI/
```

`ChatManagementInterface.ps1` is the supported launcher.

## Admin Quick Start

1. Download `TeamsChatAdmin-<version>.zip` to the admin workstation.
2. Right-click the zip file, select **Properties**, choose **Unblock** if it is present, then select **OK**.
3. Extract the zip to a local folder such as `C:\Tools\TeamsChatAdmin`.
4. Open PowerShell 7 in the extracted folder:

  ```powershell
  cd C:\Tools\TeamsChatAdmin
  ```

5. If script execution is blocked, allow scripts only for this PowerShell process:

  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

6. Install the Microsoft Graph PowerShell SDK if it is not already installed:

  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser
  ```

7. Connect to Microsoft Graph with read-only chat scopes:

  ```powershell
  Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All
  ```

8. Run the tool:

  ```powershell
  .\ChatManagementInterface.ps1
  ```

9. Choose terminal or Windows GUI when prompted. To force GUI mode:

  ```powershell
  .\ChatManagementInterface.ps1 -UiMode Windows
  ```

The extracted package must keep `ChatManagementInterface.ps1` beside the `src` folder.

## Launch Options

| Mode | Command | When to use |
| --- | --- | --- |
| Prompt for UI | `.\ChatManagementInterface.ps1` | Normal admin launch. |
| Terminal | `.\ChatManagementInterface.ps1 -UiMode Terminal` | Fallback for any PC or when GUI mode is unavailable. |
| Windows GUI | `.\ChatManagementInterface.ps1 -UiMode Windows` | Windows desktop inspection experience. |
| Capability check | `.\ChatManagementInterface.ps1 -NonInteractive` | Confirms module loading and current Graph capability without opening a menu. |

From the terminal menu, enter `G` to open the Windows GUI without restarting. Enter `10` to search for shared chat threads between two users; those results become the current row-number list for inspection or deletion.

The Windows GUI includes dedicated List Chats, Inspect One Chat, Inspect Multiple, Delete Chat, Restore Chat, Audit Log, and Help panels. Enable deletion and restore workflows from the Status panel. Delete and restore actions still require the correct Graph permission, session enablement, preview, and exact typed confirmation in a full-width dialog that handles long chat IDs.

## Permissions

Read-only inspection uses chat read permissions. Start with:

```powershell
Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All
```

Direct inspection checks active chats first. If an active chat lookup returns not found and the current Graph context has deletion permission, the tool also checks `GET /teamwork/deletedChats/{deletedChatId}` and reports deleted threads as `ChatStatus = Deleted`.

Deletion workflows require separate tenant approval and stronger permissions. Connect with deletion permission only when deletion is explicitly required and approved:

```powershell
Connect-MgGraph -Scopes Chat.ManageDeletion.All
```

The tool does not store credentials, install modules, or call `Connect-MgGraph` automatically. App-only use requires equivalent application permissions consented in Entra ID.

Interactive deletion workflows show a target preview and then require explicit typed confirmation. Direct command use still supports `-WhatIf`; it previews deletion requests only and does not create the audit directory or write an audit CSV because no deletion request was sent.

## What Admins Can Change

| Need | How to change it | Warning |
| --- | --- | --- |
| Use GUI or terminal | Choose at launch or pass `-UiMode` | GUI mode requires Windows Forms; terminal mode remains the fallback. |
| Run from another folder | Move the whole extracted folder | Do not separate `ChatManagementInterface.ps1` from `src`. |
| Execution policy | Use `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` | Avoid machine-wide policy changes unless your organization requires them. |
| Graph permissions | Reconnect with the scopes needed for the task | Deletion scopes should be used only after approval and admin consent. |
| Audit retention | Copy `%TEMP%\EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv` to an approved location | `%TEMP%` is not a durable retention location. |

Changing module files, Graph endpoints, permission gates, deletion confirmation, throttling, or restore behavior is a developer change. Test those changes in a non-production tenant before use.

## Restore Deleted Chats

Deleted-chat restore uses the Microsoft Graph `undoDelete` API:

```http
POST /teamwork/deletedChats/{deletedChatId}/undoDelete
```

In the terminal interface, option 7 lists restore candidates from the current audit log and `*TeamsChatAdminAudit*.csv` files in the working folder. You can also paste a deleted chat ID directly. Restore requires deletion permission, deletion/restore mode enabled for the session, execution confirmation, and typing the exact deleted chat ID.

The restore window is seven days after soft-delete. Restore operations are not supported for non-admin users.

## Output and Audit Path

Deletion attempts write audit rows to:

```text
%TEMP%\EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv
```

Copy this audit file to a durable approved location if retention is required.

## Troubleshooting

If Graph calls fail with an expired token, reconnect with `Connect-MgGraph` and rerun the operation. `Get-MgContext` can still show a context after the underlying access token expires, so the tool also checks live Graph request failures.

If GUI mode is unavailable, rerun in terminal mode:

```powershell
.\ChatManagementInterface.ps1 -UiMode Terminal
```

If the launcher cannot find the module manifest, confirm `ChatManagementInterface.ps1` is beside the `src` folder.