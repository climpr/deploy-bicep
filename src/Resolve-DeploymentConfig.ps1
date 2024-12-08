[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ $_ | Test-Path -PathType Leaf })]
    [string]
    $ParameterFilePath,
    
    [Parameter(Mandatory)]
    [ValidateScript({ $_ | Test-Path -PathType Leaf })]
    [string]
    $DefaultDeploymentConfigPath,
    
    [Parameter(Mandatory)]
    [string]
    $GitHubEventName, 
    
    [Parameter(Mandatory)]
    [bool]
    $DeploymentWhatIf, 

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
$parameterFile = Get-Item -Path $ParameterFilePath
$parameterFileRelativePath = Resolve-Path -Relative -Path $parameterFile.FullName
$environmentName = ($parameterFile.BaseName -split "\.")[0]
$deploymentDirectory = $parameterFile.Directory
$deploymentRelativePath = Resolve-Path -Relative -Path $deploymentDirectory.FullName
$parameterFileName = $parameterFile.Name
Write-Debug "[$($deploymentDirectory.Name)] Deployment directory path: $deploymentRelativePath"
Write-Debug "[$($deploymentDirectory.Name)] Parameter file path: $parameterFileRelativePath"

#* Resolve deployment name
$deploymentName = $deploymentDirectory.Name

#* Create deployment objects
Write-Debug "[$deploymentName][$environmentName] Processing parameter file: $parameterFileRelativePath"

#* Get deploymentConfig
$param = @{
    DeploymentDirectoryPath     = $deploymentRelativePath
    ParameterFileName           = $parameterFileName
    DefaultDeploymentConfigPath = $DefaultDeploymentConfigPath
    Debug                       = ([bool]($PSBoundParameters.Debug))
}
$deploymentConfig = Get-DeploymentConfig @param

#* Create deploymentObject
Write-Debug "[$deploymentName] Creating deploymentObject"

$deploymentObject = [pscustomobject]@{
    Deploy            = $true
    AzureCliVersion   = $deploymentConfig.azureCliVersion
    Type              = $deploymentConfig.type ?? "deployment"
    Scope             = Resolve-TemplateDeploymentScope -ParameterFilePath $parameterFileRelativePath -DeploymentConfig $deploymentConfig
    ParameterFile     = $parameterFileRelativePath
    TemplateReference = Resolve-ParameterFileTarget -Path $parameterFileRelativePath
    DeploymentConfig  = $deploymentConfig
    Name              = $deploymentConfig.name ?? "$deploymentName-$([Datetime]::Now.ToString("yyyyMMdd-HHmmss"))"
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
$azCliCommand += "--parameters $($deploymentObject.ParameterFile)"

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
    $azCliCommand += "--description $($deploymentConfig.description ?? '""')"
    if ($deploymentObject.Scope -eq "subscription" -and $deploymentConfig.deploymentResourceGroup) {
        $azCliCommand += "--deployment-resource-group $($deploymentConfig.deploymentResourceGroup)"
    }
    if ($deploymentObject.Scope -eq "managementGroup" -and $deploymentConfig.deploymentResourceGroup) {
        $azCliCommand += "--deployment-subscription $($deploymentConfig.subscription)"
    }
    if ($deploymentConfig.bypassStackOutOfSyncError -eq $true) {
        $azCliCommand += "--bypass-stack-out-of-sync-error"
    }
    if ($deploymentConfig.denySettingsApplyToChildScopes -eq $true) {
        $azCliCommand += "--deny-settings-apply-to-child-scopes"
    }
    if ($null -ne $deploymentConfig.denySettingsExcludedActions) {
        $azCliExcludedActions = ($deploymentConfig.denySettingsExcludedActions | ForEach-Object { "`"$_`"" }) -join " " ?? '""'
        $azCliCommand += "--deny-settings-excluded-actions $azCliExcludedActions"
    }
    if ($null -ne $deploymentConfig.denySettingsExcludedPrincipals) {
        $azCliExcludedPrincipals = ($deploymentConfig.denySettingsExcludedPrincipals | ForEach-Object { "`"$_`"" }) -join " " ?? '""'
        $azCliCommand += "--deny-settings-excluded-principals $azCliExcludedPrincipals"
    }
    if ($null -ne $deploymentConfig.tags) {
        $azCliTags = ($deploymentConfig.tags.Keys | ForEach-Object { "'$_=$($deploymentConfig.tags[$_])'" }) -join " "
        $azCliCommand += "--tags $($azCliTags ?? '""')"
    }
    else {
        $azCliCommand += '--tags ""'
    }
}

#* Add Azure Cli command to deploymentObject
$deploymentObject.Add("AzureCliCommand", ($azCliCommand -join " "))

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
