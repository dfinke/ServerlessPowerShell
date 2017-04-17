Register-ArgumentCompleter -CommandName Invoke-DeployAzureFunction -ParameterName SiteName -ScriptBlock {
    
    Invoke-AzureLogin
    
    foreach ($Name in Get-SiteName) {
        $ToolTip = 'Resource Group: {0}' -f $Name.ResourceGroupName
        New-Object System.Management.Automation.CompletionResult $Name.SiteName, $Name.SiteName, 'ParameterValue', $ToolTip        
    }
}