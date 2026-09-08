function Invoke-TeamsChatAdminInteractive {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Terminal', 'Windows', 'Auto')]
        [string]$UiMode = 'Terminal',

        [Parameter()]
        [pscustomobject]$SessionState
    )

    if (-not $SessionState) {
        $SessionState = [pscustomobject]@{
            UiMode = $UiMode
            AllowDestructiveActions = $false
            AuditPath = (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv')
            CapabilityState = Get-TeamsChatCapabilityProfile
            LastChatResults = @()
            LastListUserId = ''
        }
    }

    $selectionMode = if ($SessionState.UiMode -eq 'Auto' -and $IsWindows) { 'Windows' } elseif ($SessionState.UiMode -eq 'Auto') { 'Terminal' } else { $SessionState.UiMode }

    do {
        $SessionState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$SessionState.AllowDestructiveActions
        $selection = if ($selectionMode -eq 'Windows') { Show-TeamsChatAdminWindowsMenu -SessionState $SessionState } else { Show-TeamsChatAdminMenu -SessionState $SessionState }
        $requestedSelection = $selection.ToUpperInvariant()
        $inspectionOnly = $requestedSelection -in @('3', '4')

        switch ($requestedSelection) {
            '5' { $selection = '3' }
            '6' { $selection = '4' }
            '7' { $selection = '6' }
            '8' { $selection = '5' }
            '9' { $selection = '7' }
            '10' { $selection = '10' }
            'G' { $selection = 'G' }
            default { $selection = $requestedSelection }
        }

        switch ($selection.ToUpperInvariant()) {
            'U' {
                $searchText = Read-Host 'Search UPN, display name, first name, or last name (minimum 3 characters)'
                if ([string]::IsNullOrWhiteSpace($searchText)) {
                    continue
                }

                try {
                    $users = @(Find-TeamsChatUser -SearchText $searchText)
                }
                catch {
                    Write-Warning $_.Exception.Message
                    continue
                }

                if ($users.Count -eq 0) {
                    Write-Warning 'No matching users were found.'
                    continue
                }

                $indexedUsers = for ($index = 0; $index -lt $users.Count; $index++) {
                    [pscustomobject]@{
                        Index = $index + 1
                        DisplayName = $users[$index].DisplayName
                        UserPrincipalName = $users[$index].UserPrincipalName
                        GivenName = $users[$index].GivenName
                        Surname = $users[$index].Surname
                        Id = $users[$index].Id
                    }
                }
                $indexedUsers | Format-Table Index, DisplayName, UserPrincipalName, GivenName, Surname, Id -AutoSize
                $selectedIndex = Read-Host 'Select a user number to use for List Chats, or press Enter to return'
                if ($selectedIndex -notmatch '^\d+$' -or [int]$selectedIndex -lt 1 -or [int]$selectedIndex -gt $indexedUsers.Count) {
                    continue
                }

                $selectedUser = $indexedUsers[[int]$selectedIndex - 1]
                $SessionState.LastListUserId = if (-not [string]::IsNullOrWhiteSpace([string]$selectedUser.UserPrincipalName)) { $selectedUser.UserPrincipalName } else { $selectedUser.Id }
                Write-Host ('Selected {0} ({1}). Choose option 2 to load chats.' -f $selectedUser.DisplayName, $SessionState.LastListUserId) -ForegroundColor Cyan
            }
            '1' {
                $SessionState.CapabilityState | Select-Object AuthType, Connected, Account, TenantId, ClientId, GraphSdkAvailable, GraphRequestAvailable, SupportsReadReports, SupportsMessageRead, HasDeletionPermission, DeletionSessionEnabled, SupportsSingleChatDeletion, SupportsBulkChatDeletion, SupportsDeletedChatRestore, Warning | Format-List
                Write-Host 'Capability matrix:' -ForegroundColor Cyan
                Get-TeamsChatCapabilityMatrix | Select-Object Feature, Method, DestructiveOperation, ConfirmationRequirement | Format-Table -AutoSize
            }
            '2' {
                $prompt = if ([string]::IsNullOrWhiteSpace([string]$SessionState.LastListUserId)) { 'User ID or UPN' } else { 'User ID or UPN (press Enter to use {0})' -f $SessionState.LastListUserId }
                $userId = Read-Host $prompt
                if ([string]::IsNullOrWhiteSpace($userId)) {
                    $userId = [string]$SessionState.LastListUserId
                }
                $SessionState.LastListUserId = $userId
                if (-not [string]::IsNullOrWhiteSpace($userId)) {
                    $allRows = Read-Host 'Load all pages? Type Y for all pages, or press Enter for the first page'
                    try {
                        $chats = @(Get-TeamsChatByUser -UserId $userId -IncludeMembers -IncludeLastMessagePreview -All:($allRows.Trim().ToUpperInvariant() -eq 'Y'))
                    }
                    catch {
                        if ((Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) -or $_.Exception.Message -match 'token is expired|expired or invalid|InvalidAuthenticationToken') {
                            Write-Warning $_.Exception.Message
                            Write-Host 'Reconnect example for read inspection:' -ForegroundColor Yellow
                            Write-Host 'Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All' -ForegroundColor Yellow
                            Write-Host 'If you need deletion workflows, reconnect with Chat.ManageDeletion.All after admin consent is available.' -ForegroundColor Yellow
                            $SessionState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$SessionState.AllowDestructiveActions
                            continue
                        }

                        throw
                    }

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

                    $SessionState.LastChatResults = @($indexedChats)
                    if ($indexedChats.Count -eq 0) {
                        Write-Warning 'No chats were returned for that user.'
                    }
                    else {
                        foreach ($chatRow in $indexedChats) {
                            $topic = if ([string]::IsNullOrWhiteSpace($chatRow.Topic)) { '[no topic]' } else { $chatRow.Topic }
                            $participants = if ([string]::IsNullOrWhiteSpace($chatRow.Participants)) { '[participants not returned]' } else { Format-TeamsChatTextSnippet -Text $chatRow.Participants -MaximumLength 140 }
                            $previewFrom = if ([string]::IsNullOrWhiteSpace($chatRow.LastMessagePreviewFrom)) { '[unknown sender]' } else { $chatRow.LastMessagePreviewFrom }
                            $previewText = if ([string]::IsNullOrWhiteSpace($chatRow.LastMessagePreviewSnippet)) { '[no preview text returned]' } else { $chatRow.LastMessagePreviewSnippet }
                            $previewDate = if ($null -eq $chatRow.LastMessagePreviewDateTime) { '[no preview timestamp]' } else { $chatRow.LastMessagePreviewDateTime }

                            Write-Host ('{0,3}. [{1}/{2}] {3}' -f $chatRow.Index, $chatRow.ChatType, $chatRow.ChatStatus, $topic) -ForegroundColor Cyan
                            Write-Host ('     People : {0}' -f $participants)
                            Write-Host ('     Preview: {0} | {1} | {2}' -f $previewFrom, $previewDate, $previewText)
                        }
                        Write-Host ''
                        Write-Host 'The list is shortened for readability. Use option 3 and enter a row number to inspect full participant details, preview text, and chat ID.' -ForegroundColor Cyan
                    }
                }
            }
            '3' {
                $chatId = Read-Host 'Chat ID or row number from the last chat list. Type F to show full stored details'
                $selectedChat = $null
                if ($chatId.Trim().ToUpperInvariant() -eq 'F') {
                    if ($SessionState.LastChatResults.Count -eq 0) {
                        Write-Warning 'No chat list is stored yet. Run option 2 first or paste a full chat ID.'
                    }
                    else {
                        $SessionState.LastChatResults | Format-List Index, ChatStatus, ChatType, ParticipantDetails, Topic, LastMessagePreviewFrom, LastMessagePreviewText, ChatId
                    }
                    $chatId = Read-Host 'Chat ID or row number'
                }

                if ($chatId -match '^\d+$' -and $SessionState.LastChatResults.Count -gt 0) {
                    $selectedChat = $SessionState.LastChatResults | Where-Object { $_.Index -eq [int]$chatId } | Select-Object -First 1
                    if ($selectedChat) {
                        $chatId = $selectedChat.ChatId
                    }
                }
                elseif ($SessionState.LastChatResults.Count -gt 0) {
                    $selectedChat = $SessionState.LastChatResults | Where-Object { $_.ChatId -eq $chatId } | Select-Object -First 1
                }

                if (-not [string]::IsNullOrWhiteSpace($chatId)) {
                    try {
                        $directChat = Get-TeamsChatThread -ChatId $chatId -IncludeMembers -IncludeLastMessagePreview -IncludeMessageCount
                        $selectedChat = [pscustomobject]@{
                            Index = if ($selectedChat) { $selectedChat.Index } else { $null }
                            ChatStatus = $directChat.ChatStatus
                            ChatType = $directChat.ChatType
                            Participants = $directChat.ParticipantDisplayNames
                            ParticipantDetails = $directChat.ParticipantSummary
                            MemberCount = $directChat.MemberCount
                            Topic = $directChat.Topic
                            CreatedDateTime = $directChat.CreatedDateTime
                            LastUpdatedDateTime = $directChat.LastUpdatedDateTime
                            MessageCount = $directChat.MessageCount
                            LastMessagePreviewDateTime = $directChat.LastMessagePreviewDateTime
                            LastMessagePreviewFrom = $directChat.LastMessagePreviewFrom
                            LastMessagePreviewText = $directChat.LastMessagePreviewText
                            LastMessagePreviewSnippet = $directChat.LastMessagePreviewSnippet
                            ChatId = $directChat.ChatId
                        }
                    }
                    catch {
                        if ((Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) -or $_.Exception.Message -match 'token is expired|expired or invalid|InvalidAuthenticationToken') {
                            Write-Warning $_.Exception.Message
                            Write-Host 'Reconnect example for read inspection:' -ForegroundColor Yellow
                            Write-Host 'Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All' -ForegroundColor Yellow
                            continue
                        }

                        Write-Warning ('Unable to retrieve chat details for {0}: {1}' -f $chatId, $_.Exception.Message)
                    }
                }

                if ($selectedChat) {
                    Write-Host ''
                    Write-Host 'Selected chat inspection' -ForegroundColor Cyan
                    $selectedChat | Show-TeamsChatInspectionRecord
                }
                else {
                    Write-Host 'No cached participant or preview details are available for that chat ID. Run option 2 first and select a row for full inspection context.' -ForegroundColor Yellow
                }

                if ($inspectionOnly) {
                    continue
                }

                if (-not $SessionState.CapabilityState.HasDeletionPermission) {
                    Write-Warning 'Deletion is not available in the current Graph context. Reconnect with Chat.ManageDeletion.All or Chat.ManageDeletion.Chat if deletion is required.'
                    continue
                }

                $reason = Read-Host 'Reason'
                if (-not [string]::IsNullOrWhiteSpace($chatId)) {
                    $plan = Get-TeamsChatDeletePlan -ChatId $chatId -Reason $reason
                    Write-Host ''
                    Write-Host 'Deletion preview' -ForegroundColor Cyan
                    $plan | Select-Object ChatId, PlannedAction, Reason, SupportsExecution, RequiresTypedConfirmation, TenantThrottle, RestoreWindow | Format-List

                    if (-not $SessionState.CapabilityState.HasDeletionPermission) {
                        Write-Warning 'Deletion cannot run because the current Graph context lacks Chat.ManageDeletion.All or Chat.ManageDeletion.Chat.'
                        continue
                    }
                    if (-not $SessionState.AllowDestructiveActions) {
                        Write-Warning 'Deletion permission exists, but deletion workflows are disabled for this session. Choose option 9 to enable them.'
                        continue
                    }

                    $execute = Read-Host 'Execute the deletion now? Type Y to continue, or press Enter to cancel'
                    if ($execute.Trim().ToUpperInvariant() -ne 'Y') {
                        Write-Host 'Deletion cancelled. No delete request was sent.' -ForegroundColor Yellow
                        continue
                    }

                    $typedConfirmation = Read-Host ('Type the exact chat ID to confirm deletion: {0}' -f $chatId)
                    $result = Remove-TeamsChatThread -ChatId $chatId -Reason $reason -TypedConfirmation $typedConfirmation -AuditPath $SessionState.AuditPath -Confirm:$false
                    $result | Format-List
                }
            }
            '4' {
                $chatIds = [System.Collections.Generic.List[string]]::new()

                Write-Host 'Bulk source options:' -ForegroundColor Cyan
                Write-Host 'P. Paste chat IDs one per line'
                Write-Host 'L. Use all rows from the last chat list'
                Write-Host 'C. Load from CSV with a ChatId column'
                $source = Read-Host 'Select source'

                switch ($source.Trim().ToUpperInvariant()) {
                    'L' {
                        foreach ($chat in @($SessionState.LastChatResults)) {
                            if (-not [string]::IsNullOrWhiteSpace($chat.ChatId)) {
                                $chatIds.Add($chat.ChatId)
                            }
                        }
                    }
                    'C' {
                        $csvPath = Read-Host 'CSV path'
                        if (-not (Test-Path -LiteralPath $csvPath)) {
                            Write-Warning 'CSV path was not found.'
                            continue
                        }
                        foreach ($row in @(Import-Csv -Path $csvPath)) {
                            if ($row.PSObject.Properties['ChatId'] -and -not [string]::IsNullOrWhiteSpace($row.ChatId)) {
                                $chatIds.Add($row.ChatId.Trim())
                            }
                        }
                    }
                    default {
                        Write-Host 'Enter chat IDs one per line. Enter a blank line when finished.' -ForegroundColor Cyan
                        do {
                            $line = Read-Host 'Chat ID'
                            if (-not [string]::IsNullOrWhiteSpace($line)) {
                                $chatIds.Add($line.Trim())
                            }
                        } while (-not [string]::IsNullOrWhiteSpace($line))
                    }
                }

                $uniqueChatIds = [System.Collections.Generic.List[string]]::new()
                $seenChatIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($currentChatId in $chatIds) {
                    if ($seenChatIds.Add($currentChatId)) {
                        $uniqueChatIds.Add($currentChatId)
                    }
                }

                if ($uniqueChatIds.Count -ne $chatIds.Count) {
                    Write-Host ('Removed {0} duplicate target(s).' -f ($chatIds.Count - $uniqueChatIds.Count)) -ForegroundColor Yellow
                }

                if ($uniqueChatIds.Count -eq 0) {
                    Write-Warning 'No chat IDs were entered.'
                    continue
                }

                Write-Host ''
                Write-Host ('Bulk inspection targets: {0}' -f $uniqueChatIds.Count) -ForegroundColor Cyan

                $matchedChats = [System.Collections.Generic.List[object]]::new()
                $unmatchedChatIds = [System.Collections.Generic.List[string]]::new()
                foreach ($currentChatId in $uniqueChatIds) {
                    $cachedChat = $SessionState.LastChatResults | Where-Object { $_.ChatId -eq $currentChatId } | Select-Object -First 1
                    if ($cachedChat) {
                        $matchedChats.Add($cachedChat)
                        continue
                    }

                    try {
                        $directChat = Get-TeamsChatThread -ChatId $currentChatId -IncludeMembers -IncludeLastMessagePreview
                        $matchedChats.Add([pscustomobject]@{
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
                        })
                    }
                    catch {
                        if ((Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) -or $_.Exception.Message -match 'token is expired|expired or invalid|InvalidAuthenticationToken') {
                            Write-Warning $_.Exception.Message
                            Write-Host 'Reconnect example for read inspection:' -ForegroundColor Yellow
                            Write-Host 'Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All' -ForegroundColor Yellow
                            continue
                        }

                        Write-Warning ('Unable to retrieve chat details for {0}: {1}' -f $currentChatId, $_.Exception.Message)
                        $unmatchedChatIds.Add($currentChatId)
                    }
                }

                if ($matchedChats.Count -gt 0) {
                    foreach ($matchedChat in $matchedChats) {
                        Write-Host ''
                        Write-Host ('Target {0}' -f $matchedChat.ChatId) -ForegroundColor Cyan
                        $matchedChat | Show-TeamsChatInspectionRecord
                    }
                }

                if ($unmatchedChatIds.Count -gt 0) {
                    Write-Host ''
                    Write-Warning 'Some targets could not be matched from cache or retrieved directly from Graph.'
                    $unmatchedChatIds | ForEach-Object { Write-Host (' - {0}' -f $_) }
                    Write-Host 'Confirm the chat ID and current Graph permissions, then retry.' -ForegroundColor Yellow
                }

                if ($inspectionOnly) {
                    continue
                }

                if (-not $SessionState.CapabilityState.HasDeletionPermission) {
                    Write-Warning 'Deletion is not available in the current Graph context. Reconnect with Chat.ManageDeletion.All or Chat.ManageDeletion.Chat if deletion is required.'
                    continue
                }

                $reason = Read-Host 'Reason for bulk deletion'
                Write-Host ''
                Write-Host 'Bulk deletion preview' -ForegroundColor Cyan
                Get-TeamsChatDeletePlan -ChatId $uniqueChatIds.ToArray() -Mode Bulk -Reason $reason | Format-Table ChatId, SupportsExecution, RequiresTypedConfirmation -AutoSize

                if (-not $SessionState.AllowDestructiveActions) {
                    Write-Warning 'Deletion permission exists, but deletion workflows are disabled for this session. Choose option 9 to enable them.'
                    continue
                }

                $execute = Read-Host 'Execute bulk deletion now? Type Y to continue, or press Enter to cancel'
                if ($execute.Trim().ToUpperInvariant() -ne 'Y') {
                    Write-Host 'Bulk deletion cancelled. No delete requests were sent.' -ForegroundColor Yellow
                    continue
                }

                $typedConfirmation = Read-Host 'Type DELETE to confirm bulk deletion'
                $results = @(Remove-TeamsChatThreadsBulk -ChatId $uniqueChatIds.ToArray() -Reason $reason -TypedConfirmation $typedConfirmation -AuditPath $SessionState.AuditPath -Confirm:$false)
                $results | Group-Object Status | Select-Object Name, Count | Format-Table -AutoSize
                Write-Host ('Audit log: {0}' -f $SessionState.AuditPath) -ForegroundColor Cyan
            }
            '5' {
                Write-Host ('Audit log: {0}' -f $SessionState.AuditPath) -ForegroundColor Cyan
                $auditRows = @(Get-TeamsChatAuditLog -AuditPath $SessionState.AuditPath -Last 10)
                if ($auditRows.Count -eq 0) {
                    Write-Warning 'No audit rows exist yet.'
                }
                else {
                    $auditRows | Format-Table TimestampUtc, Action, Status, ChatId, Reason -AutoSize
                }
            }
            '6' {
                if (-not $SessionState.CapabilityState.HasDeletionPermission) {
                    Write-Host 'Deleted-chat restore requires Chat.ManageDeletion.All delegated permission or Chat.ManageDeletion.Chat / Chat.ManageDeletion.All application permission. The documented endpoint is POST /teamwork/deletedChats/{deletedChatId}/undoDelete.' -ForegroundColor Yellow
                    continue
                }
                if (-not $SessionState.AllowDestructiveActions) {
                    Write-Warning 'Restore permission exists, but deletion/restore workflows are disabled for this session. Choose option 9 to enable them.'
                    continue
                }

                $restoreCandidates = @(Get-TeamsChatRestoreCandidate -AuditPath @($SessionState.AuditPath) -WorkingDirectory (Get-Location).Path)
                if ($restoreCandidates.Count -gt 0) {
                    Write-Host ''
                    Write-Host 'Deleted chat restore candidates from audit logs' -ForegroundColor Cyan
                    $restoreCandidates | Format-Table Index, DeletedTimestampUtc, ChatId, DeleteReason -AutoSize -Wrap
                }
                else {
                    Write-Warning 'No deleted chat candidates were found in the current audit log or working-folder TeamsChatAdmin audit logs.'
                }

                $restoreInput = Read-Host 'Enter candidate index or deleted chat ID to restore'
                if ([string]::IsNullOrWhiteSpace($restoreInput)) {
                    Write-Host 'Restore cancelled. No restore request was sent.' -ForegroundColor Yellow
                    continue
                }

                $deletedChatId = $restoreInput.Trim()
                if ($deletedChatId -match '^\d+$' -and $restoreCandidates.Count -gt 0) {
                    $candidate = $restoreCandidates | Where-Object { $_.Index -eq [int]$deletedChatId } | Select-Object -First 1
                    if ($candidate) {
                        $deletedChatId = $candidate.ChatId
                    }
                }

                Write-Host ''
                Write-Host 'Restore preview' -ForegroundColor Cyan
                [pscustomobject]@{
                    DeletedChatId = $deletedChatId
                    GraphEndpoint = '/teamwork/deletedChats/{deletedChatId}/undoDelete'
                    GraphMethod = 'POST'
                    SupportsExecution = $SessionState.CapabilityState.SupportsDeletedChatRestore
                    RequiresTypedConfirmation = $deletedChatId
                } | Format-List

                $reason = Read-Host 'Reason for restore'
                $execute = Read-Host 'Execute the restore now? Type Y to continue, or press Enter to cancel'
                if ($execute.Trim().ToUpperInvariant() -ne 'Y') {
                    Write-Host 'Restore cancelled. No restore request was sent.' -ForegroundColor Yellow
                    continue
                }

                $typedConfirmation = Read-Host ('Type the exact deleted chat ID to confirm restore: {0}' -f $deletedChatId)
                $result = Restore-TeamsChatDeletedThread -DeletedChatId $deletedChatId -Reason $reason -TypedConfirmation $typedConfirmation -AuditPath $SessionState.AuditPath -Confirm:$false
                $result | Format-List
            }
            '7' {
                if ($SessionState.CapabilityState.HasDeletionPermission) {
                    $SessionState.AllowDestructiveActions = -not $SessionState.AllowDestructiveActions
                    $SessionState.CapabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$SessionState.AllowDestructiveActions
                    Write-Host ('Deletion and restore workflows enabled for this session: {0}' -f $SessionState.AllowDestructiveActions) -ForegroundColor Yellow
                }
                else {
                    Write-Host 'Deletion and restore require Chat.ManageDeletion.All delegated permission or Chat.ManageDeletion.Chat / Chat.ManageDeletion.All application permission, plus tenant/admin constraints for the API.' -ForegroundColor Yellow
                }
            }
            '10' {
                $userId = Read-Host 'First user ID or UPN'
                $otherUser = Read-Host 'Second user ID, UPN, email, or display name'
                if ([string]::IsNullOrWhiteSpace($userId) -or [string]::IsNullOrWhiteSpace($otherUser)) {
                    Write-Warning 'Both users are required.'
                    continue
                }

                $allRows = Read-Host 'Load all pages for the first user? Type Y for all pages, or press Enter for the first page'
                try {
                    $chats = @(Get-TeamsChatBetweenUsers -UserId $userId -OtherUser $otherUser -All:($allRows.Trim().ToUpperInvariant() -eq 'Y'))
                }
                catch {
                    if ((Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) -or $_.Exception.Message -match 'token is expired|expired or invalid|InvalidAuthenticationToken') {
                        Write-Warning $_.Exception.Message
                        Write-Host 'Reconnect example for read inspection:' -ForegroundColor Yellow
                        Write-Host 'Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All' -ForegroundColor Yellow
                        continue
                    }

                    throw
                }

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

                $SessionState.LastChatResults = @($indexedChats)
                if ($indexedChats.Count -eq 0) {
                    Write-Warning 'No shared chat threads were found for those users in the selected page scope.'
                    continue
                }

                Write-Host ''
                Write-Host ('Found {0} shared thread(s). Results are stored for row-number inspection/deletion.' -f $indexedChats.Count) -ForegroundColor Cyan
                foreach ($chatRow in $indexedChats) {
                    $topic = if ([string]::IsNullOrWhiteSpace($chatRow.Topic)) { '[no topic]' } else { $chatRow.Topic }
                    $participants = if ([string]::IsNullOrWhiteSpace($chatRow.Participants)) { '[participants not returned]' } else { Format-TeamsChatTextSnippet -Text $chatRow.Participants -MaximumLength 140 }
                    $previewFrom = if ([string]::IsNullOrWhiteSpace($chatRow.LastMessagePreviewFrom)) { '[unknown sender]' } else { $chatRow.LastMessagePreviewFrom }
                    $previewText = if ([string]::IsNullOrWhiteSpace($chatRow.LastMessagePreviewSnippet)) { '[no preview text returned]' } else { $chatRow.LastMessagePreviewSnippet }
                    $previewDate = if ($null -eq $chatRow.LastMessagePreviewDateTime) { '[no preview timestamp]' } else { $chatRow.LastMessagePreviewDateTime }

                    Write-Host ('{0,3}. [{1}/{2}] {3}' -f $chatRow.Index, $chatRow.ChatType, $chatRow.ChatStatus, $topic) -ForegroundColor Cyan
                    Write-Host ('     People : {0}' -f $participants)
                    Write-Host ('     Preview: {0} | {1} | {2}' -f $previewFrom, $previewDate, $previewText)
                }
            }
            'G' {
                $guiAvailability = Test-TeamsChatWindowsGuiAvailable
                if (-not $guiAvailability.IsAvailable) {
                    Write-Warning $guiAvailability.Reason
                    continue
                }

                Start-TeamsChatWindowsGui -SessionState $SessionState
                $selectionMode = 'Terminal'
            }
            'H' {
                Write-Host ''
                Write-Host 'Help' -ForegroundColor Cyan
                Write-Host 'List chats first when possible. The interface keeps the last chat list and lets you choose a row number for inspection or deletion.'
                Write-Host 'Use option 10 to search for shared chat threads between two users; results become the current row-number list.'
                Write-Host 'Use G to launch the Windows GUI from terminal mode.'
                Write-Host 'Inspection options never ask deletion questions. Use options 5 and 6 when you intend to delete.'
                Write-Host 'Deletion and restore are session workflows. They require Graph deletion permission and must be enabled from option 9.'
                Write-Host 'Restore uses the documented deletedChat undoDelete endpoint and can use deleted chat IDs from audit logs or pasted input.'
                Write-Host 'Every interactive deletion flow shows a preview, requires typed confirmation, and writes to the audit log only when an action is attempted.'
                Write-Host ('Audit log: {0}' -f $SessionState.AuditPath)
            }
            'Q' {
                Write-Host ('Session closed. Audit log: {0}' -f $SessionState.AuditPath) -ForegroundColor Cyan
                return
            }
            default {
                Write-Warning 'Unknown selection.'
            }
        }
    } while ($true)
}