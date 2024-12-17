function Get-DeploymentConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ $_ | Test-Path -PathType Container })]
        [string]
        $DeploymentDirectoryPath,
        
        [Parameter(Mandatory)]
        [string]
        $DeploymentFileName,
        
        [ValidateScript({ $_ | Test-Path -PathType Leaf })]
        [string]
        $DefaultDeploymentConfigPath
    )

    #* Defaults
    $jsonDepth = 3

    #* Parse default deploymentconfig file
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

    #* Parse most specific deploymentconfig file
    $fileNames = @(
        $DeploymentFileName -replace "\.(bicep|bicepparam)$", ".deploymentconfig.json"
        $DeploymentFileName -replace "\.(bicep|bicepparam)$", ".deploymentconfig.jsonc"
        "deploymentconfig.json"
        "deploymentconfig.jsonc"
    )

    $config = @{}
    $foundFiles = @()
    foreach ($fileName in $fileNames) {
        $filePath = Join-Path -Path $DeploymentDirectoryPath -ChildPath $fileName
        if (Test-Path $filePath) {
            $foundFiles += $filePath
        }
    }

    if ($foundFiles.Count -eq 1) {
        $config = Get-Content -Path $foundFiles[0] | ConvertFrom-Json -NoEnumerate -Depth $jsonDepth -AsHashtable
        Write-Debug "[Get-DeploymentConfig()] Found deploymentconfig file: $($foundFiles[0])"
        Write-Debug "[Get-DeploymentConfig()] Found deploymentconfig: $($config | ConvertTo-Json -Depth $jsonDepth)"
    }
    elseif ($foundFiles.Count -gt 1) {
        throw "[Get-DeploymentConfig()] Found multiple deploymentconfig files. Only one deploymentconfig file is supported. Found files: [$foundFiles]"
    }
    else {
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
        $Path,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        $Content
    )

    if ($Path) {
        $Content = Get-Content -Path $Path
    }
    $cleanContent = ConvertTo-UncommentedBicep -Content $Content

    #* Regex for finding 'using' statement in param file
    $regex = "^(?:\s)*?using(?:\s)*?(?:')(?:\s)*(.+?)(?:['\s])+?"

    $contentMatchesRegex = $null
    $contentMatchesRegex = $cleanContent | Select-String -AllMatches -Pattern $regex

    if (!$contentMatchesRegex) {
        throw "[Resolve-ParameterFileTarget()] Valid 'using' statement not found in parameter file content."
    }
    
    $usingReference = $contentMatchesRegex.Matches.Groups[1].Value
    Write-Debug "[Resolve-ParameterFileTarget()] Valid 'using' statement found in parameter file content."
    Write-Debug "[Resolve-ParameterFileTarget()] Resolved: '$usingReference'"

    return $usingReference
}

function Resolve-TemplateDeploymentScope {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [ValidateScript({ $_ | Test-Path -PathType Leaf })]
        [string]
        $DeploymentFilePath,

        [parameter(Mandatory)]
        [hashtable]
        $DeploymentConfig
    )

    $targetScope = ""
    $deploymentFile = Get-Item -Path $DeploymentFilePath
    
    if ($DeploymentConfig.scope) {
        Write-Debug "[Resolve-TemplateDeploymentScope()] TargetScope determined by scope property in deploymentconfig.json file"
        $targetScope = $DeploymentConfig.scope
    }
    elseif ($deploymentFile.Extension -eq ".bicep") {
        $referenceString = $deploymentFile.Name
    }
    elseif ($deploymentFile.Extension -eq ".bicepparam") {
        $referenceString = Resolve-ParameterFileTarget -Path $DeploymentFilePath
    }
    else {
        throw "Deployment file extension not supported. Only .bicep and .bicepparam is supported. Input deployment file extension: '$($deploymentFile.Extension)'"
    }

    if ($referenceString -match "^(br|ts)[\/:]") {
        #* Is remote template

        #* Resolve local cache path
        if ($referenceString -match "^(br|ts)\/(.+?):(.+?):(.+?)$") {
            #* Is alias

            #* Get active bicepconfig.json
            $bicepConfig = Get-BicepConfig -Path $DeploymentFilePath | Select-Object -ExpandProperty Config | ConvertFrom-Json -AsHashtable -NoEnumerate
            
            $type = $Matches[1]
            $alias = $Matches[2]
            $registryFqdn = $bicepConfig.moduleAliases[$type][$alias].registry
            $modulePath = $bicepConfig.moduleAliases[$type][$alias].modulePath
            $templateName = $Matches[3]
            $version = $Matches[4]
            $modulePathElements = $($modulePath -split "/"; $templateName -split "/")
        }
        elseif ($referenceString -match "^(br|ts):(.+?)/(.+?):(.+?)$") {
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
            bicep restore $DeploymentFilePath

            Write-Debug "[Resolve-TemplateDeploymentScope()] Target template is not cached locally. Running force restore operation on template."
            
            if (Test-Path -Path $cachePath) {
                Write-Debug "[Resolve-TemplateDeploymentScope()] Target template cached successfully."
            }
            else {
                Write-Debug "[Resolve-TemplateDeploymentScope()] Target template failed to restore. Target reference string: '$referenceString'. Local cache path: '$cachePath'"
                throw "Unable to restore target template '$referenceString'"
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
        Push-Location -Path $deploymentFile.Directory.FullName
        
        #* Regex for finding 'targetScope' statement in template file
        $content = Get-Content -Path $referenceString
        $cleanContent = ConvertTo-UncommentedBicep -Content $content
        $regex = "^(?:\s)*?targetScope(?:\s)*?=(?:\s)*?(?:['\s])+?(resourceGroup|subscription|managementGroup|tenant)(?:['\s])+?"
        $templateMatchesRegex = $cleanContent | Select-String -AllMatches -Pattern $regex

        Pop-Location

        if ($templateMatchesRegex) {
            $targetScope = $templateMatchesRegex.Matches.Groups[1].Value
            Write-Debug "[Resolve-TemplateDeploymentScope()] Valid 'targetScope' statement found in template file content."
            Write-Debug "[Resolve-TemplateDeploymentScope()] Resolved: '$($targetScope)'"
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
                throw "[Resolve-TemplateDeploymentScope()] Target scope is resourceGroup, but resourceGroupName property is not present in the deploymentConfig file"
            }
        }
        "subscription" {}
        "managementGroup" {
            if (!$DeploymentConfig.ContainsKey("managementGroupId")) {
                throw "[Resolve-TemplateDeploymentScope()] Target scope is managementGroup, but managementGroupId property is not present in the deploymentConfig file"
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


function ConvertTo-UncommentedBicep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Content
    )
    
    #* Convert to single string
    $rawContent = $Content -join [System.Environment]::NewLine

    #* Remove block comments
    $rawContent = $rawContent -replace '/\*[\s\S]*?\*/', ''

    #* Remove single-line comments
    $rawContent = $rawContent -replace '//.*', ''

    #* Convert to array of strings
    $contentArray = $rawContent -split [System.Environment]::NewLine

    #* Return
    $contentArray
}
