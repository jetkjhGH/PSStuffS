function Show-TeamsChatUserSearchDialog {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.IWin32Window]$Owner
    )

    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = 'Find User'
    $dialog.StartPosition = 'CenterParent'
    $dialog.ClientSize = [System.Drawing.Size]::new(900, 520)
    $dialog.MinimumSize = [System.Drawing.Size]::new(720, 420)
    $dialog.Padding = [System.Windows.Forms.Padding]::new(12)

    $layout = [System.Windows.Forms.TableLayoutPanel]::new()
    $layout.Dock = 'Fill'
    $layout.RowCount = 3
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 44)) | Out-Null
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 28)) | Out-Null
    $dialog.Controls.Add($layout)

    $searchPanel = [System.Windows.Forms.TableLayoutPanel]::new()
    $searchPanel.Dock = 'Fill'
    $searchPanel.ColumnCount = 2
    $searchPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $searchPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 130)) | Out-Null
    $layout.Controls.Add($searchPanel, 0, 0)

    $searchTextBox = [System.Windows.Forms.TextBox]::new()
    $searchTextBox.Dock = 'Fill'
    $searchTextBox.Margin = [System.Windows.Forms.Padding]::new(0, 7, 8, 7)
    $searchPanel.Controls.Add($searchTextBox, 0, 0)

    $searchButton = [System.Windows.Forms.Button]::new()
    $searchButton.Text = 'Search'
    $searchButton.Dock = 'Fill'
    $searchPanel.Controls.Add($searchButton, 1, 0)

    $resultsGrid = [System.Windows.Forms.DataGridView]::new()
    $resultsGrid.Dock = 'Fill'
    $resultsGrid.ReadOnly = $true
    $resultsGrid.AllowUserToAddRows = $false
    $resultsGrid.AllowUserToDeleteRows = $false
    $resultsGrid.SelectionMode = 'FullRowSelect'
    $resultsGrid.MultiSelect = $false
    $resultsGrid.AutoSizeColumnsMode = 'Fill'
    $layout.Controls.Add($resultsGrid, 0, 1)

    $statusLabel = [System.Windows.Forms.Label]::new()
    $statusLabel.Dock = 'Fill'
    $statusLabel.Text = 'Enter at least three characters, then double-click a matching user.'
    $statusLabel.TextAlign = 'MiddleLeft'
    $layout.Controls.Add($statusLabel, 0, 2)

    $selectedUser = $null
    $searchButton.Add_Click({
        param($sender, $eventArgs)

        $searchText = $searchTextBox.Text.Trim()
        if ($searchText.Length -lt 3) {
            [System.Windows.Forms.MessageBox]::Show('Enter at least three characters to search users.', 'Find User', 'OK', 'Warning') | Out-Null
            return
        }

        try {
            $statusLabel.Text = 'Searching Microsoft Graph...'
            [System.Windows.Forms.Application]::DoEvents()
            $results = @(Find-TeamsChatUser -SearchText $searchText)
            $resultsGrid.DataSource = $null
            $resultsGrid.DataSource = [System.Collections.ArrayList]@($results)
            $statusLabel.Text = 'Found {0} matching user(s). Double-click a row to select it.' -f $results.Count
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'User Search Failed', 'OK', 'Error') | Out-Null
            $statusLabel.Text = 'Search failed.'
        }
    }.GetNewClosure())

    $resultsGrid.Add_CellDoubleClick({
        param($sender, $eventArgs)

        if ($eventArgs.RowIndex -lt 0) {
            return
        }

        $selectedUser = $sender.Rows[$eventArgs.RowIndex].DataBoundItem
        if ($null -ne $selectedUser) {
            $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dialog.Close()
        }
    }.GetNewClosure())

    $dialog.AcceptButton = $searchButton
    [void]$searchTextBox.Focus()
    if ($dialog.ShowDialog($Owner) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $selectedUser
    }
}