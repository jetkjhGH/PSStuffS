function Read-TeamsChatWindowsConfirmation {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Instruction,

        [Parameter(Mandatory)]
        [string]$ExpectedValue
    )

    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = $Title
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = [System.Drawing.Size]::new(1280, 178)
    $dialog.Padding = [System.Windows.Forms.Padding]::new(16)

    $layout = [System.Windows.Forms.TableLayoutPanel]::new()
    $layout.Dock = 'Fill'
    $layout.ColumnCount = 1
    $layout.RowCount = 4
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 34)) | Out-Null
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 38)) | Out-Null
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 38)) | Out-Null
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $dialog.Controls.Add($layout)

    $instructionLabel = [System.Windows.Forms.Label]::new()
    $instructionLabel.Text = $Instruction
    $instructionLabel.Dock = 'Fill'
    $instructionLabel.TextAlign = 'MiddleLeft'
    $instructionLabel.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $layout.Controls.Add($instructionLabel, 0, 0)

    $expectedBox = [System.Windows.Forms.TextBox]::new()
    $expectedBox.Dock = 'Fill'
    $expectedBox.ReadOnly = $true
    $expectedBox.Font = [System.Drawing.Font]::new('Consolas', 9)
    $expectedBox.Text = $ExpectedValue
    $layout.Controls.Add($expectedBox, 0, 1)

    $inputBox = [System.Windows.Forms.TextBox]::new()
    $inputBox.Dock = 'Fill'
    $inputBox.Font = [System.Drawing.Font]::new('Consolas', 10)
    $layout.Controls.Add($inputBox, 0, 2)

    $buttonPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
    $buttonPanel.Dock = 'Fill'
    $buttonPanel.FlowDirection = 'RightToLeft'
    $layout.Controls.Add($buttonPanel, 0, 3)

    $okButton = [System.Windows.Forms.Button]::new()
    $okButton.Text = 'OK'
    $okButton.Width = 110
    $okButton.Height = 34
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonPanel.Controls.Add($okButton)

    $cancelButton = [System.Windows.Forms.Button]::new()
    $cancelButton.Text = 'Cancel'
    $cancelButton.Width = 110
    $cancelButton.Height = 34
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttonPanel.Controls.Add($cancelButton)

    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton
    [void]$inputBox.Focus()

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $inputBox.Text
    }

    return ''
}

function Start-TeamsChatWindowsGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$SessionState
    )

    $guiAvailability = Test-TeamsChatWindowsGuiAvailable
    if (-not $guiAvailability.IsAvailable) {
        Write-Warning $guiAvailability.Reason
        Invoke-TeamsChatAdminInteractive -SessionState $SessionState
        return
    }

    if ($SessionState.PSObject.Properties.Match('LastChatResults').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastChatResults' -Value @() -Force
    }
    if ($SessionState.PSObject.Properties.Match('AllowDestructiveActions').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'AllowDestructiveActions' -Value $false -Force
    }
    if ($SessionState.PSObject.Properties.Match('AuditPath').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'AuditPath' -Value (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv') -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastListUserId').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastListUserId' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastListAllPages').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastListAllPages' -Value $false -Force
    }
    if ($SessionState.PSObject.Properties.Match('SelectedChatId').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'SelectedChatId' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastInspectionInput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastInspectionInput' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastInspectionText').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastInspectionText' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastBulkInput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastBulkInput' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastBulkOutput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastBulkOutput' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastDeleteInput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastDeleteInput' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastDeleteReason').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastDeleteReason' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastDeleteOutput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastDeleteOutput' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastRestoreInput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastRestoreInput' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastRestoreReason').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastRestoreReason' -Value '' -Force
    }
    if ($SessionState.PSObject.Properties.Match('LastRestoreOutput').Count -eq 0) {
        Add-Member -InputObject $SessionState -MemberType NoteProperty -Name 'LastRestoreOutput' -Value '' -Force
    }

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = [System.Windows.Forms.Form]::new()
    $form.Name = 'TeamsChatAdminForm'
    $form.Text = 'Teams Chat Admin'
    $form.StartPosition = 'CenterScreen'
    $form.Size = [System.Drawing.Size]::new(1420, 860)
    $form.MinimumSize = [System.Drawing.Size]::new(1220, 740)
    $form.Tag = $SessionState

    $root = [System.Windows.Forms.TableLayoutPanel]::new()
    $root.Dock = 'Fill'
    $root.ColumnCount = 2
    $root.RowCount = 2
    $root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 280)) | Out-Null
    $root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 30)) | Out-Null
    $form.Controls.Add($root)

    $navigationPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
    $navigationPanel.Dock = 'Fill'
    $navigationPanel.FlowDirection = 'TopDown'
    $navigationPanel.WrapContents = $false
    $navigationPanel.Padding = [System.Windows.Forms.Padding]::new(8)
    $navigationPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $root.Controls.Add($navigationPanel, 0, 0)

    $contentPanel = [System.Windows.Forms.Panel]::new()
    $contentPanel.Dock = 'Fill'
    $contentPanel.Padding = [System.Windows.Forms.Padding]::new(12)
    $root.Controls.Add($contentPanel, 1, 0)

    $statusLabel = [System.Windows.Forms.Label]::new()
    $statusLabel.Name = 'TeamsChatStatusLabel'
    $statusLabel.Dock = 'Fill'
    $statusLabel.TextAlign = 'MiddleLeft'
    $statusLabel.Padding = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
    $root.SetColumnSpan($statusLabel, 2)
    $root.Controls.Add($statusLabel, 0, 1)

    $setStatus = {
        param([string]$Message)
        $statusLabel.Text = $Message
        [System.Windows.Forms.Application]::DoEvents()
    }

    $refreshCapability = {
        $SessionState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$SessionState.AllowDestructiveActions
        & $setStatus ('Connected: {0} | Read: {1} | Deletion permission: {2} | Deletion mode: {3} | Audit: {4}' -f $SessionState.CapabilityState.Connected, $SessionState.CapabilityState.SupportsReadReports, $SessionState.CapabilityState.HasDeletionPermission, $SessionState.AllowDestructiveActions, $SessionState.AuditPath)
    }

    $setContent = {
        param([string]$Title)
        $contentPanel.Controls.Clear()
        $layout = [System.Windows.Forms.TableLayoutPanel]::new()
        $layout.Dock = 'Fill'
        $layout.ColumnCount = 1
        $layout.RowCount = 2
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 58)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $contentPanel.Controls.Add($layout)

        $titleLabel = [System.Windows.Forms.Label]::new()
        $titleLabel.Text = $Title
        $titleLabel.Dock = 'Fill'
        $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
        $layout.Controls.Add($titleLabel, 0, 0)

        $bodyPanel = [System.Windows.Forms.Panel]::new()
        $bodyPanel.Dock = 'Fill'
        $layout.Controls.Add($bodyPanel, 0, 1)
        return $bodyPanel
    }

    $formatChatDetails = {
        param([pscustomobject]$Chat)
        if (-not $Chat) {
            return 'No chat selected.'
        }

        $lines = @(
            ('Index: {0}' -f $Chat.Index),
            ('Status: {0}' -f $Chat.ChatStatus),
            ('Chat type: {0}' -f $Chat.ChatType),
            ('Participants: {0}' -f $Chat.ParticipantDetails),
            ('Topic: {0}' -f $Chat.Topic),
            ('Last updated: {0}' -f $Chat.LastUpdatedDateTime),
            ('Preview time: {0}' -f $Chat.LastMessagePreviewDateTime),
            ('Preview from: {0}' -f $Chat.LastMessagePreviewFrom),
            ('Preview text: {0}' -f $Chat.LastMessagePreviewText),
            ('Chat ID: {0}' -f $Chat.ChatId)
        )
        return ($lines -join [Environment]::NewLine)
    }

    $convertToIndexedChat = {
        param([object[]]$Chats)
        $indexedChats = for ($index = 0; $index -lt $Chats.Count; $index++) {
            $chat = $Chats[$index]
            [pscustomobject]@{
                Index = $index + 1
                ChatStatus = $chat.ChatStatus
                ChatType = $chat.ChatType
                Participants = $chat.ParticipantDisplayNames
                ParticipantDetails = $chat.ParticipantSummary
                Topic = $chat.Topic
                LastUpdatedDateTime = $chat.LastUpdatedDateTime
                LastMessagePreviewDateTime = $chat.LastMessagePreviewDateTime
                LastMessagePreviewFrom = $chat.LastMessagePreviewFrom
                LastMessagePreviewText = $chat.LastMessagePreviewText
                LastMessagePreviewSnippet = $chat.LastMessagePreviewSnippet
                ChatId = $chat.ChatId
            }
        }
        return @($indexedChats)
    }

    $resolveChatDetails = {
        param([string]$ChatId)
        $cachedChat = $SessionState.LastChatResults | Where-Object { $_.ChatId -eq $ChatId } | Select-Object -First 1
        if ($cachedChat) {
            return $cachedChat
        }

        $directChat = Get-TeamsChatThread -ChatId $ChatId -IncludeMembers -IncludeLastMessagePreview
        return @(& $convertToIndexedChat @($directChat)) | Select-Object -First 1
    }

    $showStatusPanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Status'

        $text = [System.Windows.Forms.TextBox]::new()
        $text.Dock = 'Fill'
        $text.Multiline = $true
        $text.ReadOnly = $true
        $text.ScrollBars = 'Vertical'
        $text.Font = [System.Drawing.Font]::new('Consolas', 10)
        $text.Text = (@(
            ('Auth type: {0}' -f $SessionState.CapabilityState.AuthType),
            ('Connected: {0}' -f $SessionState.CapabilityState.Connected),
            ('Tenant ID: {0}' -f $SessionState.CapabilityState.TenantId),
            ('Client ID: {0}' -f $SessionState.CapabilityState.ClientId),
            ('Read reports: {0}' -f $SessionState.CapabilityState.SupportsReadReports),
            ('Message read: {0}' -f $SessionState.CapabilityState.SupportsMessageRead),
            ('Deletion permission: {0}' -f $SessionState.CapabilityState.HasDeletionPermission),
            ('Deletion workflows enabled: {0}' -f $SessionState.AllowDestructiveActions),
            ('Audit log: {0}' -f $SessionState.AuditPath),
            '',
            $SessionState.CapabilityState.Warning
        ) -join [Environment]::NewLine)
        $bodyPanel.Controls.Add($text)

        $buttonPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $buttonPanel.Dock = 'Bottom'
        $buttonPanel.Height = 54
        $bodyPanel.Controls.Add($buttonPanel)

        $refreshButton = [System.Windows.Forms.Button]::new()
        $refreshButton.Text = 'Refresh Status'
        $refreshButton.AutoSize = $true
        $refreshButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $refreshButton.MinimumSize = [System.Drawing.Size]::new(155, 38)
        $refreshButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $refreshButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            $guiState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$guiState.AllowDestructiveActions
            $text.Text = @(
                ('Auth type: {0}' -f $guiState.CapabilityState.AuthType),
                ('Connected: {0}' -f $guiState.CapabilityState.Connected),
                ('Tenant ID: {0}' -f $guiState.CapabilityState.TenantId),
                ('Client ID: {0}' -f $guiState.CapabilityState.ClientId),
                ('Read reports: {0}' -f $guiState.CapabilityState.SupportsReadReports),
                ('Message read: {0}' -f $guiState.CapabilityState.SupportsMessageRead),
                ('Deletion permission: {0}' -f $guiState.CapabilityState.HasDeletionPermission),
                ('Deletion workflows enabled: {0}' -f $guiState.AllowDestructiveActions),
                ('Audit log: {0}' -f $guiState.AuditPath),
                '',
                $guiState.CapabilityState.Warning
            ) -join [Environment]::NewLine
        }.GetNewClosure())
        $buttonPanel.Controls.Add($refreshButton)

        $deletionButton = [System.Windows.Forms.Button]::new()
        $deletionButton.Text = if ($SessionState.AllowDestructiveActions) { 'Disable Deletion Mode' } else { 'Enable Deletion Mode' }
        $deletionButton.AutoSize = $true
        $deletionButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $deletionButton.MinimumSize = [System.Drawing.Size]::new(220, 38)
        $deletionButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $deletionButton.Enabled = [bool]$SessionState.CapabilityState.HasDeletionPermission
        $deletionButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            $guiState.AllowDestructiveActions = -not $guiState.AllowDestructiveActions
            $guiState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$guiState.AllowDestructiveActions
            $deletionButton.Text = if ($guiState.AllowDestructiveActions) { 'Disable Deletion Mode' } else { 'Enable Deletion Mode' }
            $text.Text = @(
                ('Auth type: {0}' -f $guiState.CapabilityState.AuthType),
                ('Connected: {0}' -f $guiState.CapabilityState.Connected),
                ('Tenant ID: {0}' -f $guiState.CapabilityState.TenantId),
                ('Client ID: {0}' -f $guiState.CapabilityState.ClientId),
                ('Read reports: {0}' -f $guiState.CapabilityState.SupportsReadReports),
                ('Message read: {0}' -f $guiState.CapabilityState.SupportsMessageRead),
                ('Deletion permission: {0}' -f $guiState.CapabilityState.HasDeletionPermission),
                ('Deletion workflows enabled: {0}' -f $guiState.AllowDestructiveActions),
                ('Audit log: {0}' -f $guiState.AuditPath),
                '',
                $guiState.CapabilityState.Warning
            ) -join [Environment]::NewLine
        }.GetNewClosure())
        $buttonPanel.Controls.Add($deletionButton)
    }

    $showListPanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'List Chats'
        $layout = [System.Windows.Forms.TableLayoutPanel]::new()
        $layout.Dock = 'Fill'
        $layout.RowCount = 3
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 56)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 65)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 35)) | Out-Null
        $bodyPanel.Controls.Add($layout)

        $inputPanel = [System.Windows.Forms.TableLayoutPanel]::new()
        $inputPanel.Dock = 'Fill'
        $inputPanel.ColumnCount = 4
        $inputPanel.RowCount = 1
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 70)) | Out-Null
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 100)) | Out-Null
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 120)) | Out-Null
        $layout.Controls.Add($inputPanel, 0, 0)
        $toolTip = [System.Windows.Forms.ToolTip]::new()
        $userLabel = [System.Windows.Forms.Label]@{ Text = 'User:'; Dock = 'Fill'; TextAlign = 'MiddleLeft' }
        $toolTip.SetToolTip($userLabel, 'Enter a user ID or user principal name.')
        $inputPanel.Controls.Add($userLabel, 0, 0)
        $userTextBox = [System.Windows.Forms.TextBox]::new()
        $userTextBox.Dock = 'Fill'
        $userTextBox.Margin = [System.Windows.Forms.Padding]::new(4, 8, 8, 4)
        $userTextBox.Text = [string]$SessionState.LastListUserId
        $toolTip.SetToolTip($userTextBox, 'User ID or UPN, for example user@contoso.edu or an Entra object ID.')
        $inputPanel.Controls.Add($userTextBox, 1, 0)
        $allPagesCheckBox = [System.Windows.Forms.CheckBox]::new()
        $allPagesCheckBox.Text = 'All'
        $allPagesCheckBox.Dock = 'Fill'
        $allPagesCheckBox.Margin = [System.Windows.Forms.Padding]::new(4, 7, 4, 4)
        $allPagesCheckBox.Checked = [bool]$SessionState.LastListAllPages
        $toolTip.SetToolTip($allPagesCheckBox, 'Load all Graph result pages instead of only the first page.')
        $inputPanel.Controls.Add($allPagesCheckBox, 2, 0)
        $loadButton = [System.Windows.Forms.Button]::new()
        $loadButton.Text = 'Load'
        $loadButton.Dock = 'Fill'
        $loadButton.Margin = [System.Windows.Forms.Padding]::new(4, 5, 4, 5)
        $toolTip.SetToolTip($loadButton, 'Load chats for the entered user.')
        $inputPanel.Controls.Add($loadButton, 3, 0)

        $grid = [System.Windows.Forms.DataGridView]::new()
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true
        $grid.AllowUserToAddRows = $false
        $grid.AllowUserToDeleteRows = $false
        $grid.SelectionMode = 'FullRowSelect'
        $grid.MultiSelect = $false
        $grid.AutoSizeColumnsMode = 'Fill'
        $layout.Controls.Add($grid, 0, 1)
        $isLoadingGrid = $false

        $detailsBox = [System.Windows.Forms.TextBox]::new()
        $detailsBox.Dock = 'Fill'
        $detailsBox.Multiline = $true
        $detailsBox.ReadOnly = $true
        $detailsBox.ScrollBars = 'Vertical'
        $detailsBox.Font = [System.Drawing.Font]::new('Consolas', 10)
        $layout.Controls.Add($detailsBox, 0, 2)

        $grid.Add_CellClick({
            param($sender, $eventArgs)

            if ($isLoadingGrid -or $eventArgs.RowIndex -lt 0) {
                return
            }

            $guiState = $sender.FindForm().Tag

            $boundChat = $sender.Rows[$eventArgs.RowIndex].DataBoundItem
            if ($null -eq $boundChat) {
                return
            }

            $selectedChat = @($guiState.LastChatResults) | Where-Object { $_.Index -eq $boundChat.Index } | Select-Object -First 1
            if ($selectedChat) {
                $detailsBox.Text = (@(
                    ('Index: {0}' -f $selectedChat.Index),
                    ('Status: {0}' -f $selectedChat.ChatStatus),
                    ('Chat type: {0}' -f $selectedChat.ChatType),
                    ('Participants: {0}' -f $selectedChat.ParticipantDetails),
                    ('Topic: {0}' -f $selectedChat.Topic),
                    ('Last updated: {0}' -f $selectedChat.LastUpdatedDateTime),
                    ('Preview time: {0}' -f $selectedChat.LastMessagePreviewDateTime),
                    ('Preview from: {0}' -f $selectedChat.LastMessagePreviewFrom),
                    ('Preview text: {0}' -f $selectedChat.LastMessagePreviewText),
                    ('Chat ID: {0}' -f $selectedChat.ChatId),
                    '',
                    'This chat is now selected for Inspect One Chat.'
                ) -join [Environment]::NewLine)
                $guiState.SelectedChatId = $selectedChat.ChatId
                $guiState.LastInspectionInput = $selectedChat.ChatId
                $guiState.LastInspectionText = $detailsBox.Text
            }
        }.GetNewClosure())

        $loadButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            if ($null -eq $guiState) {
                [System.Windows.Forms.MessageBox]::Show('The GUI session state is not available. Close and reopen the Teams Chat Admin window.', 'Teams Chat Admin', 'OK', 'Error') | Out-Null
                return
            }

            $userId = $userTextBox.Text.Trim()
            $guiState.LastListUserId = $userId
            $guiState.LastListAllPages = $allPagesCheckBox.Checked
            if ([string]::IsNullOrWhiteSpace($userId)) {
                [System.Windows.Forms.MessageBox]::Show('Enter a user ID or UPN first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            try {
                $detailsBox.Text = 'Loading chats from Microsoft Graph...'
                [System.Windows.Forms.Application]::DoEvents()
                $chats = @(Get-TeamsChatByUser -UserId $userId -IncludeMembers -IncludeLastMessagePreview -All:$allPagesCheckBox.Checked)
                $indexedChats = for ($index = 0; $index -lt $chats.Count; $index++) {
                    $chat = $chats[$index]
                    [pscustomobject]@{
                        Index = $index + 1
                        ChatStatus = $chat.ChatStatus
                        ChatType = $chat.ChatType
                        Participants = $chat.ParticipantDisplayNames
                        ParticipantDetails = $chat.ParticipantSummary
                        Topic = $chat.Topic
                        LastUpdatedDateTime = $chat.LastUpdatedDateTime
                        LastMessagePreviewDateTime = $chat.LastMessagePreviewDateTime
                        LastMessagePreviewFrom = $chat.LastMessagePreviewFrom
                        LastMessagePreviewText = $chat.LastMessagePreviewText
                        LastMessagePreviewSnippet = $chat.LastMessagePreviewSnippet
                        ChatId = $chat.ChatId
                    }
                }
                if ($guiState.PSObject.Properties.Match('LastChatResults').Count -eq 0) {
                    Add-Member -InputObject $guiState -MemberType NoteProperty -Name 'LastChatResults' -Value @() -Force
                }
                $guiState.LastChatResults = @($indexedChats)
                $isLoadingGrid = $true
                $grid.DataSource = $null
                $grid.DataSource = [System.Collections.ArrayList]@($guiState.LastChatResults)
                $grid.ClearSelection()
                $isLoadingGrid = $false
                $detailsBox.Text = 'Loaded {0} chat(s). Select a row to inspect details.' -f $guiState.LastChatResults.Count
                [System.Windows.Forms.Application]::DoEvents()
            }
            catch {
                $isLoadingGrid = $false
                $graphErrorMessage = '{0} {1}' -f $_.ToString(), $_.Exception.Message
                $isAuthenticationError = (
                    $graphErrorMessage -match '401\s+Unauthorized' -or
                    $graphErrorMessage -match 'InvalidAuthenticationToken' -or
                    $graphErrorMessage -match 'token is expired' -or
                    $graphErrorMessage -match 'Lifetime validation failed' -or
                    $graphErrorMessage -match 'expired or invalid'
                )

                if ($isAuthenticationError) {
                    [System.Windows.Forms.MessageBox]::Show(('{0}{1}{1}Reconnect with Connect-MgGraph, then retry.' -f $_.Exception.Message, [Environment]::NewLine), 'Graph Token Expired', 'OK', 'Warning') | Out-Null
                    $detailsBox.Text = 'Graph token expired or invalid. Reconnect and retry.'
                    [System.Windows.Forms.Application]::DoEvents()
                    return
                }
                $diagnosticMessage = (@(
                    $_.Exception.Message,
                    '',
                    ('Script line: {0}' -f $_.InvocationInfo.ScriptLineNumber),
                    ('Command: {0}' -f $_.InvocationInfo.Line)
                ) -join [Environment]::NewLine)
                [System.Windows.Forms.MessageBox]::Show($diagnosticMessage, 'Load Chats Failed', 'OK', 'Error') | Out-Null
                $detailsBox.Text = $diagnosticMessage
                [System.Windows.Forms.Application]::DoEvents()
            }
        }.GetNewClosure())
    }

    $showInspectPanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Inspect One Chat'
        $layout = [System.Windows.Forms.TableLayoutPanel]::new()
        $layout.Dock = 'Fill'
        $layout.RowCount = 2
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 56)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $bodyPanel.Controls.Add($layout)

        $inputPanel = [System.Windows.Forms.TableLayoutPanel]::new()
        $inputPanel.Dock = 'Fill'
        $inputPanel.ColumnCount = 4
        $inputPanel.RowCount = 1
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 70)) | Out-Null
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 145)) | Out-Null
        $inputPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 125)) | Out-Null
        $layout.Controls.Add($inputPanel, 0, 0)
        $inputPanel.Controls.Add([System.Windows.Forms.Label]@{ Text = 'Chat:'; Dock = 'Fill'; TextAlign = 'MiddleLeft' }, 0, 0)
        $chatTextBox = [System.Windows.Forms.TextBox]::new()
        $chatTextBox.Dock = 'Fill'
        $chatTextBox.Margin = [System.Windows.Forms.Padding]::new(4, 8, 8, 4)
        $chatTextBox.Text = if (-not [string]::IsNullOrWhiteSpace($SessionState.LastInspectionInput)) { [string]$SessionState.LastInspectionInput } else { [string]$SessionState.SelectedChatId }
        $inputPanel.Controls.Add($chatTextBox, 1, 0)
        $useSelectedButton = [System.Windows.Forms.Button]::new()
        $useSelectedButton.Text = 'Use current'
        $useSelectedButton.Dock = 'Fill'
        $useSelectedButton.Margin = [System.Windows.Forms.Padding]::new(4, 5, 4, 5)
        $useSelectedButton.AutoSize = $false
        $inputPanel.Controls.Add($useSelectedButton, 2, 0)
        $inspectButton = [System.Windows.Forms.Button]::new()
        $inspectButton.Text = 'Inspect'
        $inspectButton.Dock = 'Fill'
        $inspectButton.Margin = [System.Windows.Forms.Padding]::new(4, 5, 4, 5)
        $inputPanel.Controls.Add($inspectButton, 3, 0)

        $detailsBox = [System.Windows.Forms.TextBox]::new()
        $detailsBox.Dock = 'Fill'
        $detailsBox.Multiline = $true
        $detailsBox.ReadOnly = $true
        $detailsBox.ScrollBars = 'Vertical'
        $detailsBox.Font = [System.Drawing.Font]::new('Consolas', 10)
        $detailsBox.Text = [string]$SessionState.LastInspectionText
        $layout.Controls.Add($detailsBox, 0, 1)

        $useSelectedButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            if ($null -eq $guiState) {
                [System.Windows.Forms.MessageBox]::Show('The GUI session state is not available. Close and reopen the Teams Chat Admin window.', 'Teams Chat Admin', 'OK', 'Error') | Out-Null
                return
            }

            if ([string]::IsNullOrWhiteSpace($guiState.SelectedChatId)) {
                [System.Windows.Forms.MessageBox]::Show('No chat is selected yet. Select a row on the List Chats page first.', 'Teams Chat Admin', 'OK', 'Information') | Out-Null
                return
            }

            $chatTextBox.Text = [string]$guiState.SelectedChatId
        }.GetNewClosure())

        $inspectButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            if ($null -eq $guiState) {
                [System.Windows.Forms.MessageBox]::Show('The GUI session state is not available. Close and reopen the Teams Chat Admin window.', 'Teams Chat Admin', 'OK', 'Error') | Out-Null
                return
            }

            if ([string]::IsNullOrWhiteSpace($chatTextBox.Text)) {
                [System.Windows.Forms.MessageBox]::Show('Enter a chat ID or row number first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            try {
                $chatInput = $chatTextBox.Text.Trim()
                $guiState.LastInspectionInput = $chatInput
                if ($chatInput -match '^\d+$' -and $guiState.LastChatResults.Count -gt 0) {
                    $chat = $guiState.LastChatResults | Where-Object { $_.Index -eq [int]$chatInput } | Select-Object -First 1
                }
                else {
                    $chat = $guiState.LastChatResults | Where-Object { $_.ChatId -eq $chatInput } | Select-Object -First 1
                    if (-not $chat) {
                        $directChat = Get-TeamsChatThread -ChatId $chatInput -IncludeMembers -IncludeLastMessagePreview
                        $chat = [pscustomobject]@{
                            Index = $null
                            ChatStatus = $directChat.ChatStatus
                            ChatType = $directChat.ChatType
                            Participants = $directChat.ParticipantDisplayNames
                            ParticipantDetails = $directChat.ParticipantSummary
                            Topic = $directChat.Topic
                            LastUpdatedDateTime = $directChat.LastUpdatedDateTime
                            LastMessagePreviewDateTime = $directChat.LastMessagePreviewDateTime
                            LastMessagePreviewFrom = $directChat.LastMessagePreviewFrom
                            LastMessagePreviewText = $directChat.LastMessagePreviewText
                            LastMessagePreviewSnippet = $directChat.LastMessagePreviewSnippet
                            ChatId = $directChat.ChatId
                        }
                    }
                }
                if ($chat) {
                    $detailsBox.Text = (@(
                        ('Index: {0}' -f $chat.Index),
                        ('Status: {0}' -f $chat.ChatStatus),
                        ('Chat type: {0}' -f $chat.ChatType),
                        ('Participants: {0}' -f $chat.ParticipantDetails),
                        ('Topic: {0}' -f $chat.Topic),
                        ('Last updated: {0}' -f $chat.LastUpdatedDateTime),
                        ('Preview time: {0}' -f $chat.LastMessagePreviewDateTime),
                        ('Preview from: {0}' -f $chat.LastMessagePreviewFrom),
                        ('Preview text: {0}' -f $chat.LastMessagePreviewText),
                        ('Chat ID: {0}' -f $chat.ChatId)
                    ) -join [Environment]::NewLine)
                    $guiState.SelectedChatId = $chat.ChatId
                }
                $detailsBox.AppendText(([Environment]::NewLine + [Environment]::NewLine + 'Inspection complete.'))
                $guiState.LastInspectionText = $detailsBox.Text
                [System.Windows.Forms.Application]::DoEvents()
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Inspection Failed', 'OK', 'Error') | Out-Null
                $detailsBox.Text = 'Inspection failed: {0}' -f $_.Exception.Message
                $guiState.LastInspectionText = $detailsBox.Text
                [System.Windows.Forms.Application]::DoEvents()
            }
        }.GetNewClosure())
    }

    $showBulkInspectPanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Inspect Multiple Chats'
        $split = [System.Windows.Forms.SplitContainer]::new()
        $split.Dock = 'Fill'
        $split.Orientation = 'Vertical'
        $split.SplitterDistance = 360
        $bodyPanel.Controls.Add($split)

        $leftLayout = [System.Windows.Forms.TableLayoutPanel]::new()
        $leftLayout.Dock = 'Fill'
        $leftLayout.RowCount = 3
        $leftLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 30)) | Out-Null
        $leftLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $leftLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 38)) | Out-Null
        $split.Panel1.Controls.Add($leftLayout)
        $leftLayout.Controls.Add([System.Windows.Forms.Label]@{ Text = 'Paste chat IDs, one per line:'; Dock = 'Fill' }, 0, 0)
        $idsTextBox = [System.Windows.Forms.TextBox]::new()
        $idsTextBox.Dock = 'Fill'
        $idsTextBox.Multiline = $true
        $idsTextBox.ScrollBars = 'Both'
        $idsTextBox.Font = [System.Drawing.Font]::new('Consolas', 9)
        $idsTextBox.Text = [string]$SessionState.LastBulkInput
        $leftLayout.Controls.Add($idsTextBox, 0, 1)
        $buttonPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $buttonPanel.Dock = 'Fill'
        $leftLayout.Controls.Add($buttonPanel, 0, 2)
        $useLastButton = [System.Windows.Forms.Button]::new()
        $useLastButton.Text = 'Use Last List'
        $useLastButton.AutoSize = $true
        $useLastButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $useLastButton.MinimumSize = [System.Drawing.Size]::new(125, 34)
        $useLastButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($useLastButton)
        $loadCsvButton = [System.Windows.Forms.Button]::new()
        $loadCsvButton.Text = 'Load CSV'
        $loadCsvButton.AutoSize = $true
        $loadCsvButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $loadCsvButton.MinimumSize = [System.Drawing.Size]::new(110, 34)
        $loadCsvButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($loadCsvButton)
        $inspectButton = [System.Windows.Forms.Button]::new()
        $inspectButton.Text = 'Inspect'
        $inspectButton.AutoSize = $true
        $inspectButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $inspectButton.MinimumSize = [System.Drawing.Size]::new(100, 34)
        $inspectButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($inspectButton)

        $detailsBox = [System.Windows.Forms.TextBox]::new()
        $detailsBox.Dock = 'Fill'
        $detailsBox.Multiline = $true
        $detailsBox.ReadOnly = $true
        $detailsBox.ScrollBars = 'Both'
        $detailsBox.Font = [System.Drawing.Font]::new('Consolas', 10)
        $detailsBox.Text = [string]$SessionState.LastBulkOutput
        $split.Panel2.Controls.Add($detailsBox)

        $useLastButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            if ($null -eq $guiState) {
                [System.Windows.Forms.MessageBox]::Show('The GUI session state is not available. Close and reopen the Teams Chat Admin window.', 'Teams Chat Admin', 'OK', 'Error') | Out-Null
                return
            }

            $idsTextBox.Text = (@($guiState.LastChatResults) | ForEach-Object { $_.ChatId }) -join [Environment]::NewLine
            $guiState.LastBulkInput = $idsTextBox.Text
        }.GetNewClosure())
        $loadCsvButton.Add_Click({
            param($sender, $eventArgs)

            $dialog = [System.Windows.Forms.OpenFileDialog]::new()
            $dialog.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
            if ($dialog.ShowDialog() -ne 'OK') { return }
            try {
                $idsTextBox.Text = (@(Import-Csv -Path $dialog.FileName) | Where-Object { $_.PSObject.Properties.Match('ChatId').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($_.ChatId) } | ForEach-Object { $_.ChatId.Trim() }) -join [Environment]::NewLine
                $guiState = $sender.FindForm().Tag
                if ($null -ne $guiState) { $guiState.LastBulkInput = $idsTextBox.Text }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'CSV Load Failed', 'OK', 'Error') | Out-Null
            }
        }.GetNewClosure())
        $inspectButton.Add_Click({
            param($sender, $eventArgs)

            $guiState = $sender.FindForm().Tag
            if ($null -eq $guiState) {
                [System.Windows.Forms.MessageBox]::Show('The GUI session state is not available. Close and reopen the Teams Chat Admin window.', 'Teams Chat Admin', 'OK', 'Error') | Out-Null
                return
            }

            $guiState.LastBulkInput = $idsTextBox.Text
            $ids = @($idsTextBox.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Select-Object -Unique)
            if ($ids.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Enter one or more chat IDs first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            $output = [System.Text.StringBuilder]::new()
            foreach ($chatId in $ids) {
                try {
                    $chat = $guiState.LastChatResults | Where-Object { $_.ChatId -eq $chatId } | Select-Object -First 1
                    if (-not $chat) {
                        $directChat = Get-TeamsChatThread -ChatId $chatId -IncludeMembers -IncludeLastMessagePreview
                        $chat = [pscustomobject]@{
                            Index = $null
                            ChatStatus = $directChat.ChatStatus
                            ChatType = $directChat.ChatType
                            Participants = $directChat.ParticipantDisplayNames
                            ParticipantDetails = $directChat.ParticipantSummary
                            Topic = $directChat.Topic
                            LastUpdatedDateTime = $directChat.LastUpdatedDateTime
                            LastMessagePreviewDateTime = $directChat.LastMessagePreviewDateTime
                            LastMessagePreviewFrom = $directChat.LastMessagePreviewFrom
                            LastMessagePreviewText = $directChat.LastMessagePreviewText
                            LastMessagePreviewSnippet = $directChat.LastMessagePreviewSnippet
                            ChatId = $directChat.ChatId
                        }
                    }
                    [void]$output.AppendLine('============================================================')
                    [void]$output.AppendLine((@(
                        ('Index: {0}' -f $chat.Index),
                        ('Status: {0}' -f $chat.ChatStatus),
                        ('Chat type: {0}' -f $chat.ChatType),
                        ('Participants: {0}' -f $chat.ParticipantDetails),
                        ('Topic: {0}' -f $chat.Topic),
                        ('Last updated: {0}' -f $chat.LastUpdatedDateTime),
                        ('Preview time: {0}' -f $chat.LastMessagePreviewDateTime),
                        ('Preview from: {0}' -f $chat.LastMessagePreviewFrom),
                        ('Preview text: {0}' -f $chat.LastMessagePreviewText),
                        ('Chat ID: {0}' -f $chat.ChatId)
                    ) -join [Environment]::NewLine))
                }
                catch {
                    [void]$output.AppendLine('============================================================')
                    [void]$output.AppendLine(('Unable to retrieve {0}: {1}' -f $chatId, $_.Exception.Message))
                }
            }
            $detailsBox.Text = $output.ToString()
            $detailsBox.AppendText(([Environment]::NewLine + ('Bulk inspection complete for {0} unique target(s).' -f $ids.Count)))
            $guiState.LastBulkOutput = $detailsBox.Text
            [System.Windows.Forms.Application]::DoEvents()
        }.GetNewClosure())
    }

    $showAuditPanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Audit Log'
        $grid = [System.Windows.Forms.DataGridView]::new()
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true
        $grid.AllowUserToAddRows = $false
        $grid.AllowUserToDeleteRows = $false
        $grid.AutoSizeColumnsMode = 'Fill'
        $bodyPanel.Controls.Add($grid)
        $rows = @(Get-TeamsChatAuditLog -AuditPath $SessionState.AuditPath -Last 100)
        $grid.DataSource = [System.Collections.ArrayList]::new($rows)
        & $setStatus ('Loaded {0} audit row(s). Audit path: {1}' -f $rows.Count, $SessionState.AuditPath)
    }

    $showDeletePanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Delete Chat'

        $layout = [System.Windows.Forms.TableLayoutPanel]::new()
        $layout.Dock = 'Fill'
        $layout.RowCount = 4
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $bodyPanel.Controls.Add($layout)

        $idPanel = [System.Windows.Forms.TableLayoutPanel]::new()
        $idPanel.Dock = 'Fill'
        $idPanel.ColumnCount = 3
        $idPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 140)) | Out-Null
        $idPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $idPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 120)) | Out-Null
        $layout.Controls.Add($idPanel, 0, 0)
        $idPanel.Controls.Add([System.Windows.Forms.Label]@{ Text = 'Chat ID:'; Dock = 'Fill'; TextAlign = 'MiddleLeft' }, 0, 0)
        $deleteChatTextBox = [System.Windows.Forms.TextBox]::new()
        $deleteChatTextBox.Dock = 'Fill'
        $deleteChatTextBox.Margin = [System.Windows.Forms.Padding]::new(4, 8, 8, 4)
        $deleteChatTextBox.Text = if (-not [string]::IsNullOrWhiteSpace([string]$SessionState.LastDeleteInput)) { [string]$SessionState.LastDeleteInput } else { [string]$SessionState.SelectedChatId }
        $idPanel.Controls.Add($deleteChatTextBox, 1, 0)
        $useCurrentButton = [System.Windows.Forms.Button]::new()
        $useCurrentButton.Text = 'Use current'
        $useCurrentButton.Dock = 'Fill'
        $useCurrentButton.Margin = [System.Windows.Forms.Padding]::new(4, 5, 4, 5)
        $idPanel.Controls.Add($useCurrentButton, 2, 0)

        $reasonPanel = [System.Windows.Forms.TableLayoutPanel]::new()
        $reasonPanel.Dock = 'Fill'
        $reasonPanel.ColumnCount = 3
        $reasonPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 140)) | Out-Null
        $reasonPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $reasonPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 120)) | Out-Null
        $layout.Controls.Add($reasonPanel, 0, 1)
        $reasonPanel.Controls.Add([System.Windows.Forms.Label]@{ Text = 'Reason:'; Dock = 'Fill'; TextAlign = 'MiddleLeft' }, 0, 0)
        $reasonTextBox = [System.Windows.Forms.TextBox]::new()
        $reasonTextBox.Dock = 'Fill'
        $reasonTextBox.Margin = [System.Windows.Forms.Padding]::new(4, 8, 8, 4)
        $reasonTextBox.Text = [string]$SessionState.LastDeleteReason
        $reasonPanel.Controls.Add($reasonTextBox, 1, 0)

        $buttonPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $buttonPanel.Dock = 'Fill'
        $layout.Controls.Add($buttonPanel, 0, 2)
        $previewButton = [System.Windows.Forms.Button]::new()
        $previewButton.Text = 'Preview Delete'
        $previewButton.AutoSize = $true
        $previewButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $previewButton.MinimumSize = [System.Drawing.Size]::new(155, 36)
        $previewButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($previewButton)
        $deleteButton = [System.Windows.Forms.Button]::new()
        $deleteButton.Text = 'Delete'
        $deleteButton.AutoSize = $true
        $deleteButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $deleteButton.MinimumSize = [System.Drawing.Size]::new(120, 36)
        $deleteButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($deleteButton)

        $outputBox = [System.Windows.Forms.TextBox]::new()
        $outputBox.Dock = 'Fill'
        $outputBox.Multiline = $true
        $outputBox.ReadOnly = $true
        $outputBox.ScrollBars = 'Both'
        $outputBox.Font = [System.Drawing.Font]::new('Consolas', 10)
        $outputBox.Text = [string]$SessionState.LastDeleteOutput
        $layout.Controls.Add($outputBox, 0, 3)

        $useCurrentButton.Add_Click({
            param($sender, $eventArgs)
            $guiState = $sender.FindForm().Tag
            if ([string]::IsNullOrWhiteSpace($guiState.SelectedChatId)) {
                [System.Windows.Forms.MessageBox]::Show('No chat is selected yet. Select a row in List Chats or inspect a chat first.', 'Teams Chat Admin', 'OK', 'Information') | Out-Null
                return
            }
            $deleteChatTextBox.Text = [string]$guiState.SelectedChatId
            $guiState.LastDeleteInput = $deleteChatTextBox.Text
        }.GetNewClosure())

        $previewButton.Add_Click({
            param($sender, $eventArgs)
            $guiState = $sender.FindForm().Tag
            $chatId = $deleteChatTextBox.Text.Trim()
            $reason = $reasonTextBox.Text
            $guiState.LastDeleteInput = $chatId
            $guiState.LastDeleteReason = $reason
            if ([string]::IsNullOrWhiteSpace($chatId)) {
                [System.Windows.Forms.MessageBox]::Show('Enter a chat ID first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            $plan = Get-TeamsChatDeletePlan -ChatId $chatId -Reason $reason
            $outputBox.Text = ($plan | Format-List | Out-String)
            $guiState.LastDeleteOutput = $outputBox.Text
        }.GetNewClosure())

        $deleteButton.Add_Click({
            param($sender, $eventArgs)
            $guiState = $sender.FindForm().Tag
            $guiState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$guiState.AllowDestructiveActions
            $chatId = $deleteChatTextBox.Text.Trim()
            $reason = $reasonTextBox.Text
            $guiState.LastDeleteInput = $chatId
            $guiState.LastDeleteReason = $reason
            if ([string]::IsNullOrWhiteSpace($chatId)) {
                [System.Windows.Forms.MessageBox]::Show('Enter a chat ID first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            if (-not $guiState.CapabilityState.SupportsSingleChatDeletion) {
                [System.Windows.Forms.MessageBox]::Show('Deletion requires deletion permission and deletion workflows enabled for this session.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            $confirmation = & (Get-Module -Name TeamsChatAdmin) {
                param($title, $instruction, $expectedValue)
                Read-TeamsChatWindowsConfirmation -Title $title -Instruction $instruction -ExpectedValue $expectedValue
            } 'Confirm Delete' 'Type the exact chat ID to confirm deletion:' $chatId
            if ($confirmation -ne $chatId) {
                $outputBox.Text = 'Deletion cancelled. Typed confirmation did not match the chat ID.'
                $guiState.LastDeleteOutput = $outputBox.Text
                return
            }
            try {
                $result = Remove-TeamsChatThread -ChatId $chatId -Reason $reason -TypedConfirmation $confirmation -AuditPath $guiState.AuditPath -Confirm:$false
                $outputBox.Text = ($result | Format-List | Out-String)
                $guiState.LastDeleteOutput = $outputBox.Text
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Delete Failed', 'OK', 'Error') | Out-Null
                $outputBox.Text = 'Delete failed: {0}' -f $_.Exception.Message
                $guiState.LastDeleteOutput = $outputBox.Text
            }
        }.GetNewClosure())
    }

    $showRestorePanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Restore Deleted Chat'

        $layout = [System.Windows.Forms.TableLayoutPanel]::new()
        $layout.Dock = 'Fill'
        $layout.RowCount = 5
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 45)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54)) | Out-Null
        $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 55)) | Out-Null
        $bodyPanel.Controls.Add($layout)

        $candidateGrid = [System.Windows.Forms.DataGridView]::new()
        $candidateGrid.Dock = 'Fill'
        $candidateGrid.ReadOnly = $true
        $candidateGrid.AllowUserToAddRows = $false
        $candidateGrid.AllowUserToDeleteRows = $false
        $candidateGrid.SelectionMode = 'FullRowSelect'
        $candidateGrid.MultiSelect = $false
        $candidateGrid.AutoSizeColumnsMode = 'Fill'
        $layout.Controls.Add($candidateGrid, 0, 0)

        $idPanel = [System.Windows.Forms.TableLayoutPanel]::new()
        $idPanel.Dock = 'Fill'
        $idPanel.ColumnCount = 3
        $idPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 140)) | Out-Null
        $idPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $idPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 240)) | Out-Null
        $layout.Controls.Add($idPanel, 0, 1)
        $idPanel.Controls.Add([System.Windows.Forms.Label]@{ Text = 'Deleted chat ID:'; Dock = 'Fill'; TextAlign = 'MiddleLeft' }, 0, 0)
        $deletedChatTextBox = [System.Windows.Forms.TextBox]::new()
        $deletedChatTextBox.Dock = 'Fill'
        $deletedChatTextBox.Margin = [System.Windows.Forms.Padding]::new(4, 8, 8, 4)
        $deletedChatTextBox.Text = [string]$SessionState.LastRestoreInput
        $idPanel.Controls.Add($deletedChatTextBox, 1, 0)
        $refreshButton = [System.Windows.Forms.Button]::new()
        $refreshButton.Text = 'Refresh Candidates'
        $refreshButton.Dock = 'Fill'
        $refreshButton.Margin = [System.Windows.Forms.Padding]::new(4, 5, 4, 5)
        $idPanel.Controls.Add($refreshButton, 2, 0)

        $reasonPanel = [System.Windows.Forms.TableLayoutPanel]::new()
        $reasonPanel.Dock = 'Fill'
        $reasonPanel.ColumnCount = 3
        $reasonPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 140)) | Out-Null
        $reasonPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $reasonPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 240)) | Out-Null
        $layout.Controls.Add($reasonPanel, 0, 2)
        $reasonPanel.Controls.Add([System.Windows.Forms.Label]@{ Text = 'Reason:'; Dock = 'Fill'; TextAlign = 'MiddleLeft' }, 0, 0)
        $reasonTextBox = [System.Windows.Forms.TextBox]::new()
        $reasonTextBox.Dock = 'Fill'
        $reasonTextBox.Margin = [System.Windows.Forms.Padding]::new(4, 8, 8, 4)
        $reasonTextBox.Text = [string]$SessionState.LastRestoreReason
        $reasonPanel.Controls.Add($reasonTextBox, 1, 0)

        $buttonPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $buttonPanel.Dock = 'Fill'
        $layout.Controls.Add($buttonPanel, 0, 3)
        $previewButton = [System.Windows.Forms.Button]::new()
        $previewButton.Text = 'Preview Restore'
        $previewButton.AutoSize = $true
        $previewButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $previewButton.MinimumSize = [System.Drawing.Size]::new(165, 36)
        $previewButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($previewButton)
        $restoreButton = [System.Windows.Forms.Button]::new()
        $restoreButton.Text = 'Restore'
        $restoreButton.AutoSize = $true
        $restoreButton.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $restoreButton.MinimumSize = [System.Drawing.Size]::new(120, 36)
        $restoreButton.Padding = [System.Windows.Forms.Padding]::new(8, 0, 8, 0)
        $buttonPanel.Controls.Add($restoreButton)

        $outputBox = [System.Windows.Forms.TextBox]::new()
        $outputBox.Dock = 'Fill'
        $outputBox.Multiline = $true
        $outputBox.ReadOnly = $true
        $outputBox.ScrollBars = 'Both'
        $outputBox.Font = [System.Drawing.Font]::new('Consolas', 10)
        $outputBox.Text = [string]$SessionState.LastRestoreOutput
        $layout.Controls.Add($outputBox, 0, 4)

        $loadCandidates = {
            param($state)
            $candidates = @(Get-TeamsChatRestoreCandidate -AuditPath @($state.AuditPath) -WorkingDirectory (Get-Location).Path)
            $candidateGrid.DataSource = $null
            $candidateGrid.DataSource = [System.Collections.ArrayList]::new($candidates)
            $outputBox.Text = 'Loaded {0} restore candidate(s) from audit logs. Select a row or paste a deleted chat ID.' -f $candidates.Count
            $state.LastRestoreOutput = $outputBox.Text
        }

        $candidateGrid.Add_CellClick({
            param($sender, $eventArgs)
            if ($eventArgs.RowIndex -lt 0) { return }
            $boundCandidate = $sender.Rows[$eventArgs.RowIndex].DataBoundItem
            if ($null -eq $boundCandidate) { return }
            $guiState = $sender.FindForm().Tag
            $deletedChatTextBox.Text = [string]$boundCandidate.ChatId
            $guiState.LastRestoreInput = $deletedChatTextBox.Text
            $outputBox.Text = (@(
                ('Selected restore candidate: {0}' -f $boundCandidate.ChatId),
                ('Deleted timestamp UTC: {0}' -f $boundCandidate.DeletedTimestampUtc),
                ('Deleted by: {0}' -f $boundCandidate.DeletedBy),
                ('Delete reason: {0}' -f $boundCandidate.DeleteReason),
                ('Audit path: {0}' -f $boundCandidate.AuditPath)
            ) -join [Environment]::NewLine)
            $guiState.LastRestoreOutput = $outputBox.Text
        }.GetNewClosure())

        $refreshButton.Add_Click({
            param($sender, $eventArgs)
            $guiState = $sender.FindForm().Tag
            try {
                $candidates = @(Get-TeamsChatRestoreCandidate -AuditPath @($guiState.AuditPath) -WorkingDirectory (Get-Location).Path)
                $candidateGrid.DataSource = $null
                $candidateGrid.DataSource = [System.Collections.ArrayList]::new($candidates)
                $outputBox.Text = 'Loaded {0} restore candidate(s) from audit logs. Select a row or paste a deleted chat ID.' -f $candidates.Count
                $guiState.LastRestoreOutput = $outputBox.Text
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Load Restore Candidates Failed', 'OK', 'Error') | Out-Null
            }
        }.GetNewClosure())

        $previewButton.Add_Click({
            param($sender, $eventArgs)
            $guiState = $sender.FindForm().Tag
            $deletedChatId = $deletedChatTextBox.Text.Trim()
            $guiState.LastRestoreInput = $deletedChatId
            $guiState.LastRestoreReason = $reasonTextBox.Text
            if ([string]::IsNullOrWhiteSpace($deletedChatId)) {
                [System.Windows.Forms.MessageBox]::Show('Enter or select a deleted chat ID first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            $outputBox.Text = (@(
                'Restore preview',
                ('Deleted chat ID: {0}' -f $deletedChatId),
                'Graph endpoint: /teamwork/deletedChats/{deletedChatId}/undoDelete',
                'Graph method: POST',
                ('Supports execution: {0}' -f $guiState.CapabilityState.SupportsDeletedChatRestore),
                ('Requires typed confirmation: {0}' -f $deletedChatId)
            ) -join [Environment]::NewLine)
            $guiState.LastRestoreOutput = $outputBox.Text
        }.GetNewClosure())

        $restoreButton.Add_Click({
            param($sender, $eventArgs)
            $guiState = $sender.FindForm().Tag
            $guiState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$guiState.AllowDestructiveActions
            $deletedChatId = $deletedChatTextBox.Text.Trim()
            $reason = $reasonTextBox.Text
            $guiState.LastRestoreInput = $deletedChatId
            $guiState.LastRestoreReason = $reason
            if ([string]::IsNullOrWhiteSpace($deletedChatId)) {
                [System.Windows.Forms.MessageBox]::Show('Enter or select a deleted chat ID first.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            if (-not $guiState.CapabilityState.SupportsDeletedChatRestore) {
                [System.Windows.Forms.MessageBox]::Show('Restore requires deletion permission and deletion/restore workflows enabled for this session.', 'Teams Chat Admin', 'OK', 'Warning') | Out-Null
                return
            }
            $confirmation = & (Get-Module -Name TeamsChatAdmin) {
                param($title, $instruction, $expectedValue)
                Read-TeamsChatWindowsConfirmation -Title $title -Instruction $instruction -ExpectedValue $expectedValue
            } 'Confirm Restore' 'Type the exact deleted chat ID to confirm restore:' $deletedChatId
            if ($confirmation -ne $deletedChatId) {
                $outputBox.Text = 'Restore cancelled. Typed confirmation did not match the deleted chat ID.'
                $guiState.LastRestoreOutput = $outputBox.Text
                return
            }
            try {
                $result = Restore-TeamsChatDeletedThread -DeletedChatId $deletedChatId -Reason $reason -TypedConfirmation $confirmation -AuditPath $guiState.AuditPath -Confirm:$false
                $outputBox.Text = ($result | Format-List | Out-String)
                $guiState.LastRestoreOutput = $outputBox.Text
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Restore Failed', 'OK', 'Error') | Out-Null
                $outputBox.Text = 'Restore failed: {0}' -f $_.Exception.Message
                $guiState.LastRestoreOutput = $outputBox.Text
            }
        }.GetNewClosure())

        $candidates = @(Get-TeamsChatRestoreCandidate -AuditPath @($SessionState.AuditPath) -WorkingDirectory (Get-Location).Path)
        $candidateGrid.DataSource = [System.Collections.ArrayList]::new($candidates)
        $outputBox.Text = if ([string]::IsNullOrWhiteSpace([string]$SessionState.LastRestoreOutput)) { 'Loaded {0} restore candidate(s) from audit logs. Select a row or paste a deleted chat ID.' -f $candidates.Count } else { [string]$SessionState.LastRestoreOutput }
    }

    $showHelpPanel = {
        & $refreshCapability
        $bodyPanel = & $setContent 'Help'
        $text = [System.Windows.Forms.TextBox]::new()
        $text.Dock = 'Fill'
        $text.Multiline = $true
        $text.ReadOnly = $true
        $text.ScrollBars = 'Vertical'
        $text.Font = [System.Drawing.Font]::new('Segoe UI', 10)
        $text.Text = (@(
            'This is the first full Windows GUI milestone. Normal prompts, selections, and inspection output stay in this window.',
            '',
            'Status: Graph connection, read capability, deletion permission, deletion session mode, and audit path.',
            'List Chats: enter a user ID or UPN and load chats into a grid. Select a row to inspect details.',
            'Inspect One Chat: enter a chat ID or a row number from the last list.',
            'Inspect Multiple Chats: paste IDs, use the last list, or load a CSV with a ChatId column.',
            'Audit Log: view recent audit entries.',
            'Delete Chat: use the selected chat or paste a chat ID, preview, then delete with exact typed confirmation.',
            'Restore: use the Restore Chat panel to select an audit-log candidate or paste a deleted chat ID, preview, and restore with typed confirmation.'
        ) -join [Environment]::NewLine)
        $bodyPanel.Controls.Add($text)
    }

    foreach ($buttonInfo in @(
        @{ Text = 'Status'; Action = $showStatusPanel },
        @{ Text = 'List Chats'; Action = $showListPanel },
        @{ Text = 'Inspect One Chat'; Action = $showInspectPanel },
        @{ Text = 'Inspect Multiple'; Action = $showBulkInspectPanel },
        @{ Text = 'Delete Chat'; Action = $showDeletePanel },
        @{ Text = 'Audit Log'; Action = $showAuditPanel },
        @{ Text = 'Restore Chat'; Action = $showRestorePanel },
        @{ Text = 'Help'; Action = $showHelpPanel }
    )) {
        $button = [System.Windows.Forms.Button]::new()
        $button.Text = $buttonInfo.Text
        $button.Width = 245
        $button.Height = 40
        $button.Margin = [System.Windows.Forms.Padding]::new(4, 4, 4, 4)
        $button.AutoEllipsis = $true
        $button.Font = [System.Drawing.Font]::new('Segoe UI', 10)
        $action = $buttonInfo.Action
        $button.Add_Click({ & $action }.GetNewClosure())
        $navigationPanel.Controls.Add($button)
    }

    $exitButton = [System.Windows.Forms.Button]::new()
    $exitButton.Text = 'Exit'
    $exitButton.Width = 245
    $exitButton.Height = 40
    $exitButton.Margin = [System.Windows.Forms.Padding]::new(4, 20, 4, 4)
    $exitButton.AutoEllipsis = $true
    $exitButton.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $exitButton.Add_Click({ $form.Close() }.GetNewClosure())
    $navigationPanel.Controls.Add($exitButton)

    & $showStatusPanel
    [void]$form.ShowDialog()
}