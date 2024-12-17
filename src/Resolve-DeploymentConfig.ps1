[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ $_ | Test-Path -PathType Leaf })]
    [string]
    $DeploymentFilePath,
    
    [Parameter(Mandatory)]
    [ValidateScript({ $_ | Test-Path -PathType Leaf })]
    [string]
    $DefaultDeploymentConfigPath,
    
    [Parameter(Mandatory)]
    [string]
    $GitHubEventName, 
    
    [Parameter(Mandatory = $false)]
    [bool]
    $DeploymentWhatIf = $false, 

    [switch]
    $Quiet
)

Write-Debug "Resolve-DeploymentConfig.ps1: Started"
Write-Debug "Input parameters: $($PSBoundParameters | ConvertTo-Json -Depth 3)"

#* Establish defaults
$scriptRoot = $PSScriptRoot
Write-Debug "Working directory: $((Resolve-Path -Path .).Path)"
Write-Debug "Script root directory: $(Resolve-Path -Relative -Path $scriptRoot)"

#* Import Modules
Import-Module $scriptRoot/support-functions.psm1 -Force

#* Resolve files
$deploymentFile = Get-Item -Path $DeploymentFilePath
$deploymentFileRelativePath = Resolve-Path -Relative -Path $deploymentFile.FullName
$environmentName = ($deploymentFile.BaseName -split "\.")[0]
$deploymentDirectory = $deploymentFile.Directory
$deploymentRelativePath = Resolve-Path -Relative -Path $deploymentDirectory.FullName
$deploymentFileName = $deploymentFile.Name
Write-Debug "[$($deploymentDirectory.Name)] Deployment directory path: $deploymentRelativePath"
Write-Debug "[$($deploymentDirectory.Name)] Deployment file path: $deploymentFileRelativePath"

#* Resolve deployment name
$deploymentName = $deploymentDirectory.Name

#* Create deployment objects
Write-Debug "[$deploymentName][$environmentName] Processing deployment file: $deploymentFileRelativePath"

#* Get deploymentConfig
$param = @{
    DeploymentDirectoryPath     = $deploymentRelativePath
    DeploymentFileName          = $deploymentFileName
    DefaultDeploymentConfigPath = $DefaultDeploymentConfigPath
    Debug                       = ([bool]($PSBoundParameters.Debug))
}
$deploymentConfig = Get-DeploymentConfig @param

#* Determine deployment file type
if ($deploymentFile.Extension -eq ".bicepparam") {
    #* Is .bicepparam
    $templateReference = Resolve-ParameterFileTarget -Path $deploymentFileRelativePath
    $parameterFile = $deploymentFileRelativePath
}
elseif ($deploymentFile.Extension -eq ".bicep") {
    #* Is .bicep
    $templateReference = $deploymentFileRelativePath
    $parameterFile = $null
}
else {
    throw "Deployment file extension not supported. Only .bicep and .bicepparam is supported. Input deployment file extension: '$($deploymentFile.Extension)'"
}

#* Create deploymentObject
Write-Debug "[$deploymentName] Creating deploymentObject"

$deploymentObject = [pscustomobject]@{
    Deploy            = $true
    AzureCliVersion   = $deploymentConfig.azureCliVersion
    Environment       = $environmentName
    Type              = $deploymentConfig.type ?? "deployment"
    Scope             = Resolve-TemplateDeploymentScope -DeploymentFilePath $deploymentFileRelativePath -DeploymentConfig $deploymentConfig
    ParameterFile     = $parameterFile
    TemplateReference = $templateReference
    DeploymentConfig  = $deploymentConfig
    Name              = $deploymentConfig.name ?? "$deploymentName-$environmentName-$(git rev-parse --short HEAD)"
    Location          = $deploymentConfig.location
    ManagementGroupId = $deploymentConfig.managementGroupId
    ResourceGroupName = $deploymentConfig.resourceGroupName
}

$azCliCommand = @()
switch ($deploymentObject.Scope) {
    "resourceGroup" {
        $azCliCommand += "az $($deploymentObject.Type) group create"
        $azCliCommand += "--resource-group $($deploymentObject.ResourceGroupName)"
    }
    "subscription" { 
        $azCliCommand += "az $($deploymentObject.Type) sub create"
        $azCliCommand += "--location $($deploymentObject.Location)"
    }
    "managementGroup" {
        $azCliCommand += "az $($deploymentObject.Type) mg create"
        $azCliCommand += "--location $($deploymentObject.Location)"
        $azCliCommand += "--management-group-id $($deploymentObject.ManagementGroupId)"
    }
    "tenant" {
        $azCliCommand += "az $($deploymentObject.Type) tenant create"
        $azCliCommand += "--location $($deploymentObject.Location)" 
    }
    default {
        Write-Output "::error::Unknown deployment scope."
        throw "Unknown deployment scope."
    }
}

#* Add common parameters
$azCliCommand += "--name $($deploymentObject.Name)"

if ($deploymentObject.ParameterFile) {
    $azCliCommand += "--parameters $($deploymentObject.ParameterFile)"
}
else {
    $azCliCommand += "--template-file $($deploymentObject.TemplateReference)"
}

#* Add type specific parameters
if ($deploymentObject.Type -eq "deployment") {
    if ($DeploymentWhatIf) {
        $azCliCommand += "--what-if"
    }
}
elseif ($deploymentObject.Type -eq "stack") {
    $azCliCommand += "--yes"
    $azCliCommand += "--action-on-unmanage $($deploymentConfig.actionOnUnmanage)"
    $azCliCommand += "--deny-settings-mode $($deploymentConfig.denySettingsMode)"
    if ([string]::IsNullOrEmpty($deploymentObject.description)) {
        $azCliCommand += '--description ""'
    }
    else {
        $azCliCommand += "--description $($deploymentConfig.description)"
    }
    if ($deploymentObject.Scope -eq "subscription" -and $deploymentConfig.deploymentResourceGroup) {
        $azCliCommand += "--deployment-resource-group $($deploymentConfig.deploymentResourceGroup)"
    }
    if ($deploymentObject.Scope -eq "managementGroup" -and $deploymentConfig.deploymentSubscription) {
        $azCliCommand += "--deployment-subscription $($deploymentConfig.deploymentSubscription)"
    }
    if ($deploymentConfig.bypassStackOutOfSyncError -eq $true) {
        $azCliCommand += "--bypass-stack-out-of-sync-error"
    }
    if ($deploymentConfig.denySettingsApplyToChildScopes -eq $true) {
        $azCliCommand += "--deny-settings-apply-to-child-scopes"
    }
    if ($null -ne $deploymentConfig.denySettingsExcludedActions) {
        $azCliExcludedActions = ($deploymentConfig.denySettingsExcludedActions | ForEach-Object { "`"$_`"" }) -join " " ?? '""'
        if ($azCliExcludedActions.Length -eq 0) {
            $azCliCommand += '--deny-settings-excluded-actions ""'
        }
        else {
            $azCliCommand += "--deny-settings-excluded-actions $azCliExcludedActions"
        }
    }
    if ($null -ne $deploymentConfig.denySettingsExcludedPrincipals) {
        $azCliExcludedPrincipals = ($deploymentConfig.denySettingsExcludedPrincipals | ForEach-Object { "`"$_`"" }) -join " " ?? '""'
        if ($azCliExcludedPrincipals.Length -eq 0) {
            $azCliCommand += '--deny-settings-excluded-principals ""'
        }
        else {
            $azCliCommand += "--deny-settings-excluded-principals $azCliExcludedPrincipals"
        }
    }
    if ($null -ne $deploymentConfig.tags -and $deploymentConfig.tags.Count -ge 1) {
        $azCliTags = ($deploymentConfig.tags.Keys | ForEach-Object { "'$_=$($deploymentConfig.tags[$_])'" }) -join " "
        $azCliCommand += "--tags $azCliTags"
    }
    else {
        $azCliCommand += '--tags ""'
    }
}

#* Add Azure Cli command to deploymentObject
$deploymentObject | Add-Member -MemberType NoteProperty -Name "AzureCliCommand" -Value ($azCliCommand -join " ")

#* Exclude disabled deployments
Write-Debug "[$deploymentName] Checking if deployment is disabled in the deploymentconfig file."
if ($deploymentConfig.disabled) {
    $deploymentObject.Deploy = $false
    Write-Debug "[$deploymentName] Deployment is disabled for all triggers in the deploymentconfig file. Deployment is skipped."
}
if ($deploymentConfig.triggers -and $deploymentConfig.triggers.ContainsKey($GitHubEventName) -and $deploymentConfig.triggers[$GitHubEventName].disabled) {
    $deploymentObject.Deploy = $false
    Write-Debug "[$deploymentName] Deployment is disabled for the current trigger [$GitHubEventName] in the deploymentconfig file. Deployment is skipped."
}

Write-Debug "[$deploymentName] deploymentObject: $($deploymentObject | ConvertTo-Json -Depth 3)"

#* Print deploymentObject to console
if (!$Quiet.IsPresent) {
    $deploymentObject | Format-List * | Out-String | Write-Host
}

#* Return deploymentObject
$deploymentObject

Write-Debug "Resolve-DeploymentConfig.ps1: Completed"
