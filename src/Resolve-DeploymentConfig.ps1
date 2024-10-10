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
    DeploymentName    = $deploymentConfig.name ?? "$deploymentName-$([Datetime]::Now.ToString("yyyyMMdd-HHmmss"))"
    ParameterFile     = $parameterFileRelativePath
    TemplateReference = Resolve-ParameterFileTarget -ParameterFilePath $parameterFileRelativePath
    DeploymentScope   = Resolve-TemplateDeploymentScope -ParameterFilePath $parameterFileRelativePath -DeploymentConfig $deploymentConfig
    Location          = $deploymentConfig.location
    ResourceGroupName = $deploymentConfig.resourceGroupName
    ManagementGroupId = $deploymentConfig.managementGroupId
    AzureCliVersion   = $deploymentConfig.azureCliVersion
    DeploymentConfig  = $deploymentConfig
}
Write-Debug "[$deploymentName] deploymentObject: $($deploymentObject | ConvertTo-Json -Depth 1)"

#* Exclude disabled deployments
Write-Debug "[$deploymentName] Checking if deployment is disabled in deploymentconfig.json"
if ($deploymentConfig.disabled) {
    $deploymentObject.Deploy = $false
    Write-Debug "[$deploymentName] Deployment is disabled for all triggers in deploymentconfig.json. Deployment is skipped."
}
if ($deploymentConfig.triggers -and $deploymentConfig.triggers.ContainsKey($GitHubEventName) -and $deploymentConfig.triggers[$GitHubEventName].disabled) {
    $deploymentObject.Deploy = $false
    Write-Debug "[$deploymentName] Deployment is disabled for the current trigger [$GitHubEventName] in deploymentconfig.json. Deployment is skipped."
}

#* Print deploymentObject to console
if (!$Quiet.IsPresent) {
    $deploymentObject | Format-List * | Out-String | Write-Host
}

#* Return deploymentObject
$deploymentObject

Write-Debug "Resolve-DeploymentConfig.ps1: Completed"
