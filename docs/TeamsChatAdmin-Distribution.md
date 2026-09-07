# Teams Chat Admin Distribution Runbook

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

For deletion workflows, reconnect with deletion permissions after required tenant/admin consent is in place:

```powershell
Connect-MgGraph -Scopes Chat.ManageDeletion.All
```

The extracted package must keep `ChatManagementInterface.ps1` beside the `src` folder.

## Requirements

- Windows PC for GUI mode.
- PowerShell 7 or later.
- Microsoft Graph PowerShell SDK.
- A Microsoft Graph connection with permissions appropriate to the workflow.

Install PowerShell 7 from Microsoft if `pwsh` is not available. Install the Graph SDK for the current user:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

If execution policy blocks local scripts, allow scripts only for the current process:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Connect to Microsoft Graph

Read-only inspection example:

```powershell
Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All
```

Deletion-capable example, subject to tenant policy and admin consent:

```powershell
Connect-MgGraph -Scopes Chat.ManageDeletion.All
```

The tool does not store credentials and does not call `Connect-MgGraph` automatically.

## Launch

From the package folder:

```powershell
.\ChatManagementInterface.ps1
```

Force terminal mode:

```powershell
.\ChatManagementInterface.ps1 -UiMode Terminal
```

Force Windows GUI mode:

```powershell
.\ChatManagementInterface.ps1 -UiMode Windows
```

Noninteractive capability check:

```powershell
.\ChatManagementInterface.ps1 -NonInteractive
```

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