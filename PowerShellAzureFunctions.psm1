. $PSScriptRoot\SiteNameArgumentCompleter.ps1

function Invoke-AzureLogin {
    try {
        $null = Get-AzureRmContext
    } catch {
        $null = Login-AzureRmAccount
    }
}

function Get-FunctionApp {
    param($SiteName)

    Invoke-AzureLogin

    if ($SiteName) {
        Get-AzureRmResource | 
            Where-Object {
            $_.Name -eq $SiteName 
        } | ForEach-Object ResourceId   
    }
    else {
        Get-AzureRmResource | 
            Where-Object {
            $_.kind -eq 'functionapp' -and $_.ResourceType -eq 'Microsoft.Web/sites'
        } | ForEach-Object ResourceId
    }
}

function Get-Sitename {
    foreach ($name in Get-FunctionApp) {
 
        $null, $null, $subscriptionId, $null, $ResourceGroupName, $null, $null, $null, $SiteName = $name.split('/')
        [PSCustomObject][Ordered]@{
            SubscriptionId = $subscriptionId
            ResourceGroupName = $ResourceGroupName
            SiteName = $SiteName 
        }
    }
}

function Invoke-DeployAzureFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $SiteName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        $SourceFile
    )

    Begin {
        
        Invoke-AzureLogin

        Function GetResourceTypeAndName($SiteName, $Slot) {
            $ResourceType = "Microsoft.Web/sites"
            $ResourceName = $SiteName
            if ($Slot) {
                $ResourceType = "$($ResourceType)/slots"
                $ResourceName = "$($ResourceName)/$($Slot)"
            }

            $ResourceType, $ResourceName
        }

        Function GetFunctionInvokeUrl($ResourceGroupName, $SiteName, $FunctionName, $Slot) {
            $ResourceType, $ResourceName = GetResourceTypeAndName $SiteName $Slot

            Invoke-AzureRmResourceAction -ResourceGroupName $ResourceGroupName -ResourceType $ResourceType/Functions -ResourceName $SiteName/$FunctionName -Action listsecrets -ApiVersion "2015-08-01" -Force
        }
    }

    Process {
        
        $fileName = (Split-Path -Leaf $SourceFile)
        $extensionName = $fileName.Split('.')[-1]
        $FunctionName = $fileName.Split('.')[0]

        $SourceFileContent = Get-Content -Raw $SourceFile

        $props = @{
            config = @{"bindings" = @(
                    @{
                        "name" = "req"
                        "type" = "httpTrigger"
                        "direction" = "in"
                        "authLevel" = "function"
                    }
                    @{
                        "name" = "res"
                        "type" = "http"
                        "direction" = "out"
                    }
                )
                "disabled" = "false"
            }
        }

        switch ($extensionName) {
            "ps1" {
                $functionFileName = "run.ps1"
            }

            "js" {
                $functionFileName = "index.js"
            }

            "cs" {
                $functionFileName = "run.csx"
            }    

            "fs" {
                $functionFileName = "run.fsx"
            }    
        }    

        $props.files = @{$functionFileName = "$SourceFileContent"}        

        foreach ($targetSite in $SiteName) {
            $baseResourceID = Get-FunctionApp $targetSite
            $newResourceId = "{0}/functions/{1}" -f $baseResourceID, $FunctionName

            $ResourceGroupName = ($baseResourceID -split '/')[4]            
            Write-Verbose "Deploying $($fileName) to $($targetSite) in resource group $($ResourceGroupName)"            

            $r = New-AzureRmResource -ResourceId $newResourceId -ApiVersion 2015-08-01 -Properties $props -Force    
            GetFunctionInvokeUrl $ResourceGroupName $targetSite $FunctionName | ForEach-Object trigger_url
        }
    }
}