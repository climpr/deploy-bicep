function Get-DeploymentConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ $_ | Test-Path -PathType Container })]
        [string]
        $DeploymentDirectoryPath,
        
        [Parameter(Mandatory)]
        [string]
        $ParameterFileName,
        
        [ValidateScript({ $_ | Test-Path -PathType Leaf })]
        [string]
        $DefaultDeploymentConfigPath
    )
    Write-Debug "[Get-DeploymentConfig()] Input parameters: $($PSBoundParameters | ConvertTo-Json -Depth 3)"

    #* Defaults
    $jsonDepth = 3

    #* Parse default deploymentconfig.json
    $defaultDeploymentConfig = @{}

    if ($DefaultDeploymentConfigPath) {
        if (Test-Path -Path $DefaultDeploymentConfigPath) {
            $defaultDeploymentConfig = Get-Content -Path $DefaultDeploymentConfigPath | ConvertFrom-Json -Depth $jsonDepth -AsHashtable -NoEnumerate
            Write-Debug "[Get-DeploymentConfig()] Found default deploymentconfig file: $DefaultDeploymentConfigPath"
            Write-Debug "[Get-DeploymentConfig()] Found default deploymentconfig: $($defaultDeploymentConfig | ConvertTo-Json -Depth $jsonDepth)"
        }
        else {
            Write-Debug "[Get-DeploymentConfig()] Did not find the specified default deploymentconfig file: $DefaultDeploymentConfigPath"
        }
    }
    else {
        Write-Debug "[Get-DeploymentConfig()] No default deploymentconfig file specified."
    }

    #* Parse most specific deploymentconfig.json file
    $fileNames = @(
        $ParameterFileName -replace "\.bicepparam$", ".deploymentconfig.json"
        "deploymentconfig.json"
    )

    $config = @{}
    $found = $false
    foreach ($fileName in $fileNames) {
        $filePath = Join-Path -Path $DeploymentDirectoryPath -ChildPath $fileName
        Write-Debug "[Get-DeploymentConfig()] Searching for deploymentconfig file: [$filePath]"
        if (Test-Path $filePath) {
            $found = $true
            $config = Get-Content -Path $filePath | ConvertFrom-Json -NoEnumerate -Depth $jsonDepth -AsHashtable
            Write-Debug "[Get-DeploymentConfig()] Found deploymentconfig file: $filePath"
            Write-Debug "[Get-DeploymentConfig()] Found deploymentconfig: $($config | ConvertTo-Json -Depth $jsonDepth)"
            break
        }
    }

    if (!$found) {
        if ($DefaultDeploymentConfigPath) {
            Write-Debug "[Get-DeploymentConfig()] Did not find deploymentconfig file. Using default deploymentconfig file."
        }
        else {
            Write-Debug "[Get-DeploymentConfig()] Did not find deploymentconfig file. No deploymentconfig applied."
        }
    }
    
    $deploymentConfig = Join-HashTable -Hashtable1 $defaultDeploymentConfig -Hashtable2 $config

    #* Return config object
    $deploymentConfig
}

function Resolve-ParameterFileTarget {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]
        $ParameterFilePath,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [string]
        $ParameterFileContent
    )

    #* Regex for finding 'using' statement in param file
    $regex = "^(?:\s)*?using(?:\s)*?(?:')(?:\s)*(.+?)(?:['\s])+?"

    if ($ParameterFileContent) {
        $content = $ParameterFileContent
    }
    else {
        $content = Get-Content -Path $ParameterFilePath -Raw
    }

    $usingReference = ""
    if ($content -match $regex) {
        $usingReference = $Matches[1]
        Write-Debug "[Resolve-ParameterFileTarget()] Valid 'using' statement found in parameter file content."
        Write-Debug "[Resolve-ParameterFileTarget()] Resolved: '$usingReference'"
    }
    else {
        throw "[Resolve-ParameterFileTarget()] Valid 'using' statement not found in parameter file content."
    }

    return $usingReference
}

function Resolve-TemplateDeploymentScope {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]
        $ParameterFilePath,

        [parameter(Mandatory)]
        [hashtable]
        $DeploymentConfig
    )

    $targetScope = ""

    $parameterFile = Get-Item -Path $ParameterFilePath
    $referenceString = Resolve-ParameterFileTarget -ParameterFilePath $ParameterFilePath

    if ($ReferenceString -match "^(br|ts)[\/:]") {
        #* Is remote template

        #* Resolve local cache path
        if ($ReferenceString -match "^(br|ts)\/(.+?):(.+?):(.+?)$") {
            #* Is alias

            #* Get active bicepconfig.json
            $bicepConfig = Get-BicepConfig -Path $ParameterFilePath | Select-Object -ExpandProperty Config | ConvertFrom-Json -AsHashtable -NoEnumerate
            
            $type = $Matches[1]
            $alias = $Matches[2]
            $registryFqdn = $bicepConfig.moduleAliases[$type][$alias].registry
            $modulePath = $bicepConfig.moduleAliases[$type][$alias].modulePath
            $templateName = $Matches[3]
            $version = $Matches[4]
            $modulePathElements = $($modulePath -split "/"; $templateName -split "/")
        }
        elseif ($ReferenceString -match "^(br|ts):(.+?)/(.+?):(.+?)$") {
            #* Is FQDN
            $type = $Matches[1]
            $registryFqdn = $Matches[2]
            $modulePath = $Matches[3]
            $version = $Matches[4]
            $modulePathElements = $modulePath -split "/"
        }

        #* Find cached template reference
        $cachePath = "~/.bicep/$type/$registryFqdn/$($modulePathElements -join "$")/$version`$/"

        if (!(Test-Path -Path $cachePath)) {
            #* Restore .bicep or .bicepparam file to ensure templates are located in the cache
            bicep restore $ParameterFilePath

            Write-Debug "[Resolve-TemplateDeploymentScope()] Target template is not cached locally. Running force restore operation on template."
            
            if (Test-Path -Path $cachePath) {
                Write-Debug "[Resolve-TemplateDeploymentScope()] Target template cached successfully."
            }
            else {
                Write-Debug "[Resolve-TemplateDeploymentScope()] Target template failed to restore. Target reference string: '$ReferenceString'. Local cache path: '$cachePath'"
                throw "Unable to restore target template '$ReferenceString'"
            }
        }

        #* Resolve deployment scope
        $armTemplate = Get-Content -Path "$cachePath/main.json" | ConvertFrom-Json -Depth 30 -AsHashtable -NoEnumerate
        
        switch -Regex ($armTemplate.'$schema') {
            "^.+?\/deploymentTemplate\.json#" {
                $targetScope = "resourceGroup"
            }
            "^.+?\/subscriptionDeploymentTemplate\.json#" {
                $targetScope = "subscription" 
            }
            "^.+?\/managementGroupDeploymentTemplate\.json#" {
                $targetScope = "managementGroup" 
            }
            "^.+?\/tenantDeploymentTemplate\.json#" {
                $targetScope = "tenant" 
            }
            default {
                throw "[Resolve-TemplateDeploymentScope()] Non-supported `$schema property in target template. Unable to ascertain the deployment scope." 
            }
        }
    }
    else {
        #* Is local template
        Push-Location -Path $parameterFile.Directory.FullName
        $templateFileContent = Get-Content -Path $ReferenceString
        Pop-Location
        
        #* Regex for finding 'targetScope' statement in template file
        $regex = "^(?:\s)*?targetScope(?:\s)*?=(?:\s)*?(?:['\s])+?(resourceGroup|subscription|managementGroup|tenant)(?:['\s])+?"

        if ($templateFileContent -match $regex) {
            Write-Debug "[Resolve-TemplateDeploymentScope()] Valid 'targetScope' statement found in template file content."
            Write-Debug "[Resolve-TemplateDeploymentScope()] Resolved: '$($Matches[1])'"
            $targetScope = $Matches[1]
        }
        else {
            Write-Debug "[Resolve-TemplateDeploymentScope()] Valid 'targetScope' statement not found in parameter file content. Defaulting to resourceGroup scope"
            $targetScope = "resourceGroup"
        }
    }

    Write-Debug "[Resolve-TemplateDeploymentScope()] TargetScope resolved as: $targetScope"

    #* Validate required deploymentconfig properties for scopes
    switch ($targetScope) {
        "resourceGroup" {
            if (!$DeploymentConfig.ContainsKey("resourceGroupName")) {
                throw "[Resolve-TemplateDeploymentScope()] Target scope is resourceGroup, but resourceGroupName property is not present in deploymentConfig.json file"
            }
        }
        "subscription" {}
        "managementGroup" {
            if (!$DeploymentConfig.ContainsKey("managementGroupId")) {
                throw "[Resolve-TemplateDeploymentScope()] Target scope is managementGroup, but managementGroupId property is not present in deploymentConfig.json file"
            }
        }
        "tenant" {}
    }

    #* Return target scope
    $targetScope
}

function Join-HashTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Hashtable1 = @{},
        
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Hashtable2 = @{}
    )

    #* Null handling
    $Hashtable1 = $Hashtable1.Keys.Count -eq 0 ? @{} : $Hashtable1
    $Hashtable2 = $Hashtable2.Keys.Count -eq 0 ? @{} : $Hashtable2

    #* Needed for nested enumeration
    $hashtable1Clone = $Hashtable1.Clone()
    
    foreach ($key in $hashtable1Clone.Keys) {
        if ($key -in $hashtable2.Keys) {
            if ($hashtable1Clone[$key] -is [hashtable] -and $hashtable2[$key] -is [hashtable]) {
                $Hashtable2[$key] = Join-HashTable -Hashtable1 $hashtable1Clone[$key] -Hashtable2 $Hashtable2[$key]
            }
            elseif ($hashtable1Clone[$key] -is [array] -and $hashtable2[$key] -is [array]) {
                foreach ($item in $hashtable1Clone[$key]) {
                    if ($hashtable2[$key] -notcontains $item) {
                        $hashtable2[$key] += $item
                    }
                }
            }
        }
        else {
            $Hashtable2[$key] = $hashtable1Clone[$key]
        }
    }
    
    return $Hashtable2
}
