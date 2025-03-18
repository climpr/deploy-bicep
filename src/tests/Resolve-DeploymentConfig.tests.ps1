BeforeAll {
    if ((Get-PSResourceRepository -Name PSGallery).Trusted -eq $false) {
        Set-PSResourceRepository -Name PSGallery -Trusted -Confirm:$false
    }
    if ((Get-PSResource -Name Bicep -ErrorAction Ignore).Version -lt "2.7.0") {
        Install-PSResource -Name Bicep
    }
    Import-Module $PSScriptRoot/../support-functions.psm1 -Force
}

Describe "Resolve-DeploymentConfig.ps1" {
    # MARK: Pester setup
    BeforeAll {
        $script:shortHash = git rev-parse --short HEAD

        $script:testRoot = Join-Path $TestDrive 'test'
        New-Item -Path $testRoot -ItemType Directory -Force | Out-Null
        
        $script:defaultDeploymentConfigPath = Join-Path $testRoot "default.deploymentconfig.jsonc"
        $script:defaultDeploymentConfig = [ordered]@{
            '$schema'         = "https://raw.githubusercontent.com/climpr/climpr-schemas/main/schemas/v1.0.0/bicep-deployment/deploymentconfig.json#"
            'location'        = "westeurope"
            'azureCliVersion' = "2.68.0"
        }
        $defaultDeploymentConfig | ConvertTo-Json | Out-File -FilePath $defaultDeploymentConfigPath
        $script:commonParam = @{
            Quiet                       = $true
            Debug                       = $false
            GitHubEventName             = "workflow_dispatch"
            DefaultDeploymentConfigPath = $defaultDeploymentConfigPath
        }
    }

    BeforeEach {
        $script:climprConfigFile = Join-Path $testRoot 'climprconfig.jsonc'
        $script:configFile = Join-Path $testRoot 'deploymentconfig.jsonc'
        $script:bicepFile = Join-Path $testRoot 'main.bicep'
        $script:paramFile = Join-Path $testRoot 'main.bicepparam'

        "targetScope = 'subscription'" | Out-File -Path $bicepFile
        "using 'main.bicep'" | Out-File -Path $paramFile

        $script:commonParams = @{
            DefaultDeploymentConfigPath = $defaultDeploymentConfigPath
            GitHubEventName             = "workflow_dispatch"
            DeploymentFilePath          = $paramFile
            Quiet                       = $true
        }
    }

    AfterEach {
        Remove-Item -Path $climprConfigFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $bicepFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $paramFile -Force -ErrorAction SilentlyContinue
    }

    # MARK: Input files
    Context "Handle input files correctly" {
        It "Should handle .bicep file correctly" {
            $bicepFileRelativePath = Resolve-Path -Relative -Path $bicepFile
            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams -DeploymentFilePath $bicepFile
            $res.TemplateReference | Should -Be $bicepFileRelativePath
            $res.ParameterFile | Should -BeNullOrEmpty
        }
        
        It "Should handle .bicepparam file correctly" {
            $paramFileRelativePath = Resolve-Path -Relative -Path $paramFile
            "using 'main.bicep'" | Set-Content -Path $paramFile
            
            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.TemplateReference | Should -Be "main.bicep"
            $res.ParameterFile | Should -Be $paramFileRelativePath
        }
    }

    # MARK: Scopes
    Context "Handle scopes correctly" {
        It "Should handle 'resourceGroup' scope correctly" {
            "targetScope = 'resourceGroup'" | Set-Content -Path $bicepFile
            @{ resourceGroupName = "mock-rg" } | ConvertTo-Json | Set-Content -Path $configFile

            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.Scope | Should -Be "resourceGroup"
        }

        It "Should handle 'subscription' scope correctly" {
            "targetScope = 'subscription'" | Set-Content -Path $bicepFile

            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.Scope | Should -Be "subscription"
        }

        It "Should handle 'managementGroup' scope correctly" {
            "targetScope = 'managementGroup'" | Set-Content -Path $bicepFile
            @{ managementGroupId = "mock-mg" } | ConvertTo-Json | Set-Content -Path $configFile

            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.Scope | Should -Be "managementGroup"
        }

        It "Should handle 'tenant' scope correctly" {
            "targetScope = 'tenant'" | Set-Content -Path $bicepFile

            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.Scope | Should -Be "tenant"
        }

        It "Should fail if target scope is 'tenant' and type is 'deploymentStack'" {
            "targetScope = 'tenant'" | Set-Content -Path $bicepFile
            @{ type = "deploymentStack" } | ConvertTo-Json | Set-Content -Path $configFile

            { ./src/Resolve-DeploymentConfig.ps1 @commonParams }
            | Should -Throw "Deployment stacks are not supported for tenant scoped deployments."
        }
    }

    # MARK: Remote templates
    Context "Handle direct .bicepparam remote template reference correctly" {
        It "Should handle remote Azure Container Registry (ACR) template correctly" {
            "using 'br/public:avm/res/resources/resource-group:0.4.1'" | Set-Content -Path $paramFile

            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.TemplateReference | Should -Be 'br/public:avm/res/resources/resource-group:0.4.1'
            $res.Scope | Should -Be 'subscription'
        }

        #? No authenticated pipeline to run test. Hence, template specs cannot be restored.
        # It "Should handle remote Template Specs correctly" {
        #     "using 'ts:resourceId:tag'" | Set-Content -Path $paramFile
        #     $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
        #     $res | ConvertTo-Json -Depth 10 | Write-Host
        #     $res.TemplateReference | Should -Be 'br/public:avm/res/resources/resource-group:0.4.1'
        #     $res.Scope | Should -Be 'subscription'
        # }
    }

    # MARK: Common parameters
    Context "Handle common parameters" {
        Context "'Deploy' parameter" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario         = "deploymentConfig.disabled not specified (default)"
                    deploymentConfig = @{}
                    expected         = $true
                }
                @{
                    scenario         = "deploymentConfig.disabled set to null"
                    deploymentConfig = @{ disabled = $null }
                    expected         = $true
                }
                @{
                    scenario         = "deploymentConfig.disabled set to false"
                    deploymentConfig = @{ disabled = $false }
                    expected         = $true
                }
                @{
                    scenario         = "deploymentConfig.disabled set to true"
                    deploymentConfig = @{ disabled = $true }
                    expected         = $false
                }
                @{
                    scenario         = "deploymentConfig.triggers.<eventName>.disabled set to true"
                    deploymentConfig = @{ disabled = $true; triggers = @{ workflow_dispatch = @{ disabled = $true } } }
                    expected         = $false
                }
                @{
                    scenario         = "deploymentConfig.triggers.<eventName>.disabled set to false but deploymentConfig.disabled set to true"
                    deploymentConfig = @{ disabled = $true; triggers = @{ workflow_dispatch = @{ disabled = $false } } }
                    expected         = $false
                }
            ) {
                param ($scenario, $deploymentConfig, $expected)

                $deploymentConfig | ConvertTo-Json | Set-Content -Path $configFile
                $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
                $res.Deploy | Should -Be $expected
            }
        }
    }

    # MARK: Deployment
    Context "When deployment is a normal deployment" {
        Context "When the deployment type is 'deployment'" {
            It "It should handle all properties correctly" {
                $paramFileRelative = Resolve-Path -Relative -Path $paramFile
                $deploymentName = "test-main-$shortHash" # Name of the temporary parent directory + 'main' from main.bicepparam + git short hash

                $properties = [ordered]@{
                    Deploy            = $true
                    AzureCliVersion   = $defaultDeploymentConfig.azureCliVersion
                    Type              = "deployment"
                    Scope             = "subscription"
                    ParameterFile     = $paramFileRelative
                    TemplateReference = 'main.bicep'
                    Name              = $deploymentName
                    Location          = "westeurope"
                    ManagementGroupId = $null
                    ResourceGroupName = $null
                    AzureCliCommand   = "az deployment sub create --location westeurope --name $deploymentName --parameters $paramFileRelative"
                }
                
                $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
                foreach ($key in $properties.Keys) {
                    $res.$key | Should -Be $properties[$key]
                }
            }
        }

        # MARK: Deployment 'DeploymentWhatIf'
        Context "Handle 'DeploymentWhatIf' parameter" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no 'DeploymentWhatIf' parameter"
                    expected = "^(?!.*--what-if).*$"
                }
                @{
                    scenario         = "false 'DeploymentWhatIf' parameter"
                    deploymentWhatIf = $false
                    expected         = "^(?!.*--what-if).*$"
                }
                @{
                    scenario         = "true 'DeploymentWhatIf' parameter"
                    deploymentWhatIf = $true
                    expected         = "--what-if"
                }
            ) {
                param ($scenario, $deploymentWhatIf, $expected)
            
                $deploymentWhatIfParam = @{}
                if ($deploymentWhatIf) {
                    $deploymentWhatIfParam = @{ DeploymentWhatIf = $deploymentWhatIf }
                }

                ./src/Resolve-DeploymentConfig.ps1 @commonParams @deploymentWhatIfParam
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }
    }

    # MARK: Stack
    Context "When deployment is a Deployment stack" {
        Context "When the deployment type is 'deploymentStack'" {
            It "It should handle all properties correctly" {
                $paramFileRelative = Resolve-Path -Relative -Path $paramFile
                $deploymentName = "test-main-$shortHash" # Name of the temporary parent directory + 'main' from main.bicepparam + git short hash

                $properties = [ordered]@{
                    Deploy            = $true
                    AzureCliVersion   = $defaultDeploymentConfig.azureCliVersion
                    Type              = "deploymentStack"
                    Scope             = "subscription"
                    ParameterFile     = $paramFileRelative
                    TemplateReference = 'main.bicep'
                    Name              = $deploymentName
                    Location          = "westeurope"
                    ManagementGroupId = $null
                    ResourceGroupName = $null
                    AzureCliCommand   = "az stack sub create --location westeurope --name $deploymentName --parameters $paramFileRelative --yes --action-on-unmanage detachAll --deny-settings-mode none --description `"`" --tags `"`""
                }
                
                @{ type = "deploymentStack" } | ConvertTo-Json | Set-Content -Path $configFile

                $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
                foreach ($key in $properties.Keys) {
                    $res.$key | Should -Be $properties[$key]
                }
            }
        }
        
        # MARK: Stack 'description'
        Context "When handling stack 'description' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no description property"
                    expected = '--description ""'
                }
                @{
                    scenario    = "null description property"
                    description = $null
                    expected    = '--description ""'
                }
                @{
                    scenario    = "empty description property"
                    description = ""
                    expected    = '--description ""'
                }
                @{
                    scenario    = "non-empty description property"
                    description = "mock-description"
                    expected    = '--description mock-description'
                }
            ) {
                param ($scenario, $description, $expected)
                
                @{
                    type        = "deploymentStack"
                    description = $description
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }

        # MARK: Stack 'bypassStackOutOfSyncError'
        Context "When handling stack 'bypassStackOutOfSyncError' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no bypassStackOutOfSyncError property"
                    expected = "^(?!.*--bypass-stack-out-of-sync-error).*$"
                }
                @{
                    scenario                  = "null bypassStackOutOfSyncError property"
                    bypassStackOutOfSyncError = $null
                    expected                  = "^(?!.*--bypass-stack-out-of-sync-error).*$"
                }
                @{
                    scenario                  = "false bypassStackOutOfSyncError"
                    bypassStackOutOfSyncError = $false
                    expected                  = "^(?!.*--bypass-stack-out-of-sync-error).*$"
                }
                @{
                    scenario                  = "true bypassStackOutOfSyncError"
                    bypassStackOutOfSyncError = $true
                    expected                  = '--bypass-stack-out-of-sync-error'
                }
            ) {
                param ($scenario, $bypassStackOutOfSyncError, $expected)
                
                $deploymentConfig + @{
                    type                      = "deploymentStack"
                    bypassStackOutOfSyncError = $bypassStackOutOfSyncError
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }

        # MARK: Stack 'denySettings.applyToChildScopes'
        Context "When handling stack 'denySettings.applyToChildScopes' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no applyToChildScopes property"
                    expected = "^(?!.*--deny-settings-apply-to-child-scopes).*$"
                }
                @{
                    scenario           = "null applyToChildScopes property"
                    applyToChildScopes = $null
                    expected           = "^(?!.*--deny-settings-apply-to-child-scopes).*$"
                }
                @{
                    scenario           = "false applyToChildScopes"
                    applyToChildScopes = $false
                    expected           = "^(?!.*--deny-settings-apply-to-child-scopes).*$"
                }
                @{
                    scenario           = "true applyToChildScopes"
                    applyToChildScopes = $true
                    expected           = '--deny-settings-apply-to-child-scopes'
                }
            ) {
                param ($scenario, $applyToChildScopes, $expected)
                
                $deploymentConfig + @{
                    type         = "deploymentStack"
                    denySettings = @{
                        mode               = "denyDelete"
                        applyToChildScopes = $applyToChildScopes
                    }
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }

        # MARK: Stack 'denySettings.excludedActions'
        Context "When handling stack 'denySettings.excludedActions' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no excludedActions property"
                    expected = "^(?!.*--deny-settings-excluded-actions).*$"
                }
                @{
                    scenario        = "null excludedActions property"
                    excludedActions = $null
                    expected        = "^(?!.*--deny-settings-excluded-actions).*$"
                }
                @{
                    scenario        = "empty array excludedActions"
                    excludedActions = @()
                    expected        = '--deny-settings-excluded-actions ""'
                }
                @{
                    scenario        = "single item excludedActions"
                    excludedActions = @("mock-action")
                    expected        = '--deny-settings-excluded-actions "mock-action"'
                }
                @{
                    scenario        = "multiple items excludedActions"
                    excludedActions = @("mock-action1", "mock-action2")
                    expected        = '--deny-settings-excluded-actions "mock-action1" "mock-action2"'
                }
            ) {
                param ($scenario, $excludedActions, $expected)
                
                $deploymentConfig + @{
                    type         = "deploymentStack"
                    denySettings = @{
                        mode            = "denyDelete"
                        excludedActions = $excludedActions
                    }
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }

        # MARK: Stack 'denySettings.excludedPrincipals'
        Context "When handling stack 'denySettings.excludedPrincipals' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no excludedPrincipals property"
                    expected = "^(?!.*--deny-settings-excluded-principals).*$"
                }
                @{
                    scenario           = "null excludedPrincipals property"
                    excludedPrincipals = $null
                    expected           = "^(?!.*--deny-settings-excluded-principals).*$"
                }
                @{
                    scenario           = "empty array excludedPrincipals"
                    excludedPrincipals = @()
                    expected           = '--deny-settings-excluded-principals ""'
                }
                @{
                    scenario           = "single item excludedPrincipals"
                    excludedPrincipals = @("mock-principal")
                    expected           = '--deny-settings-excluded-principals "mock-principal"'
                }
                @{
                    scenario           = "multiple items excludedPrincipals"
                    excludedPrincipals = @("mock-principal1", "mock-principal2")
                    expected           = '--deny-settings-excluded-principals "mock-principal1" "mock-principal2"'
                }
            ) {
                param ($scenario, $excludedPrincipals, $expected)
                
                $deploymentConfig + @{
                    type         = "deploymentStack"
                    denySettings = @{
                        mode               = "denyDelete"
                        excludedPrincipals = $excludedPrincipals
                    }
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }

        # MARK: Stack 'actionOnUnmanage'
        Context "When handling stack 'actionOnUnmanage' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no actionOnUnmanage property"
                    expected = "--action-on-unmanage detachAll"
                }
                @{
                    scenario         = "null actionOnUnmanage property"
                    actionOnUnmanage = $null
                    expected         = "--action-on-unmanage detachAll"
                }
                @{
                    scenario         = "resources and resourceGroups is 'delete'"
                    actionOnUnmanage = @{ resources = "delete"; resourceGroups = "delete" }
                    expected         = "--action-on-unmanage deleteAll"
                }
                @{
                    scenario         = "resources is 'delete' but resourceGroups is not 'delete'"
                    actionOnUnmanage = @{ resources = "delete" }
                    expected         = "--action-on-unmanage deleteResources"
                }
            ) {
                param ($scenario, $actionOnUnmanage, $expected)
            
                $deploymentConfig + @{
                    type             = "deploymentStack"
                    actionOnUnmanage = $actionOnUnmanage
                } | ConvertTo-Json | Set-Content -Path $configFile
            
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }

            Context "When scope is 'managementGroup'" {
                It "Should handle <scenario> correctly" -TestCases @(
                    @{
                        scenario         = "resources, resourceGroups and managementGroups is 'delete'"
                        actionOnUnmanage = @{ resources = "delete"; resourceGroups = "delete"; managementGroups = "delete" }
                        expected         = "--action-on-unmanage deleteAll"
                    }
                    @{
                        scenario         = "resources and resourceGroups is 'delete' but managementGroups is not 'delete'"
                        actionOnUnmanage = @{ resources = "delete"; resourceGroups = "delete" }
                        expected         = "--action-on-unmanage deleteResources"
                    }
                    @{
                        scenario         = "resources is 'delete' but resourceGroups is not 'delete'"
                        actionOnUnmanage = @{ resources = "delete" }
                        expected         = "--action-on-unmanage deleteResources"
                    }
                ) {
                    param ($scenario, $actionOnUnmanage, $expected)
                
                    $deploymentConfig + @{
                        type              = "deploymentStack"
                        managementGroupId = "mock-mg"
                        actionOnUnmanage  = $actionOnUnmanage
                    } | ConvertTo-Json | Set-Content -Path $configFile

                    # Set target scope to managementGroup
                    "targetScope = 'managementGroup'" | Set-Content -Path $bicepFile
                
                    ./src/Resolve-DeploymentConfig.ps1 @commonParams
                    | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
                }
            }
        }

        # MARK: Stack 'tags'
        Context "When handling stack 'tags' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no tags property"
                    tags     = $null
                    expected = '--tags ""'
                }
                @{
                    scenario = "empty tags"
                    tags     = @{}
                    expected = '--tags ""'
                }
                @{
                    scenario = "single tag"
                    tags     = @{ "key" = "value" }
                    expected = "--tags 'key=value'"
                }
                @{
                    scenario = "multiple tags"
                    tags     = [ordered]@{ "key1" = "value1"; "key2" = "value2" }
                    expected = "--tags 'key1=value1' 'key2=value2'"
                }
            ) {
                param ($scenario, $tags, $expected)
                
                @{
                    type = "deploymentStack"
                    tags = $tags
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }

        # MARK: Stack 'deploymentResourceGroup'
        Context "When handling stack 'deploymentResourceGroup' property" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario         = "no deploymentResourceGroup property"
                    deploymentConfig = @{}
                    expected         = "^(?!.*--deployment-resource-group).*$"
                }
                @{
                    scenario         = "null deploymentResourceGroup"
                    deploymentConfig = @{ deploymentResourceGroup = $null }
                    expected         = "^(?!.*--deployment-resource-group).*$"
                }
                @{
                    scenario         = "empty deploymentResourceGroup"
                    deploymentConfig = @{ deploymentResourceGroup = "" }
                    expected         = "^(?!.*--deployment-resource-group).*$"
                }
                @{
                    scenario         = "non-empty deploymentResourceGroup"
                    deploymentConfig = @{ deploymentResourceGroup = "mock-rg" }
                    expected         = "--deployment-resource-group mock-rg"
                }
            ) {
                param ($scenario, $deploymentConfig, $expected)
                
                $deploymentConfig + @{
                    type = "deploymentStack"
                } | ConvertTo-Json | Set-Content -Path $configFile
                
                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }

            # TODO: Not supported yet
            # It "Should fail if 'deploymentResourceGroup' is specified and the scope is 'resourceGroup'" {
            #     @{ type = "deploymentStack"; deploymentResourceGroup = "mock-rg"; resourceGroupName = "mock-rg" } | ConvertTo-Json | Set-Content -Path $configFile
            #     "targetScope = 'resourceGroup'" | Set-Content -Path $bicepFile

            #     $errorActionPreference = 'Stop'
            #     { ./src/Resolve-DeploymentConfig.ps1 @commonParams } | Should -Throw "The 'deploymentResourceGroup' property is only supported when the target scope is 'resourceGroup'."
            # }

            # It "Should fail if 'deploymentResourceGroup' is specified and the scope is 'managementGroup'" {
            #     @{ type = "deploymentStack"; deploymentResourceGroup = "mock-rg"; managementGroupId = "mock-mg" } | ConvertTo-Json | Set-Content -Path $configFile
            #     "targetScope = 'managementGroup'" | Set-Content -Path $bicepFile

            #     $errorActionPreference = 'Stop'
            #     { ./src/Resolve-DeploymentConfig.ps1 @commonParams } | Should -Throw "The 'deploymentResourceGroup' property is only supported when the target scope is 'resourceGroup'."
            # }
        }

        # MARK: Stack 'deploymentSubscription'
        Context "Handle 'deploymentSubscription' property" {
            It "Should handle <scenario> deploymentSubscription correctly" -TestCases @(
                @{
                    scenario         = "no deploymentSubscription property"
                    deploymentConfig = @{}
                    expected         = "^(?!.*--deployment-resource-group).*$"
                }
                @{
                    scenario         = "null deploymentSubscription"
                    deploymentConfig = @{ deploymentSubscription = $null }
                    expected         = "^(?!.*--deployment-subscription).*$"
                }
                @{
                    scenario         = "empty deploymentSubscription"
                    deploymentConfig = @{ deploymentSubscription = "" }
                    expected         = "^(?!.*--deployment-subscription).*$"
                }
                @{
                    scenario         = "non-empty deploymentSubscription"
                    deploymentConfig = @{ deploymentSubscription = "mock-sub" }
                    expected         = "--deployment-subscription mock-sub"
                }
            ) {
                param ($scenario, $deploymentConfig, $expected)
                
                $deploymentConfig + @{
                    type              = "deploymentStack"
                    managementGroupId = 'mock-mg'
                } | ConvertTo-Json | Set-Content -Path $configFile
                "targetScope = 'managementGroup'" | Set-Content -Path $bicepFile

                ./src/Resolve-DeploymentConfig.ps1 @commonParams
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }

            # TODO: Not supported yet
            # It "Should fail if 'deploymentSubscription' is specified and the scope is 'resourceGroup'" {
            #     @{ type = "deploymentStack"; deploymentSubscription = "mock-sub"; resourceGroupName = "mock-rg" } | ConvertTo-Json | Set-Content -Path $configFile
            #     "targetScope = 'resourceGroup'" | Set-Content -Path $bicepFile

            #     $errorActionPreference = 'Stop'
            #     { ./src/Resolve-DeploymentConfig.ps1 @commonParams } | Should -Throw "The 'deploymentSubscription' property is only supported when the target scope is 'managementGroup'."
            # }

            # It "Should fail if 'deploymentResourceGroup' is specified and the scope is 'subscription'" {
            #     @{ type = "deploymentStack"; deploymentSubscription = "mock-sub" } | ConvertTo-Json | Set-Content -Path $configFile
            #     "targetScope = 'subscription'" | Set-Content -Path $bicepFile

            #     $errorActionPreference = 'Stop'
            #     { ./src/Resolve-DeploymentConfig.ps1 @commonParams } | Should -Throw "The 'deploymentSubscription' property is only supported when the target scope is 'managementGroup'."
            # }
        }

        # MARK: Stack 'DeploymentWhatIf'
        Context "Handle 'DeploymentWhatIf' parameter" {
            It "Should handle <scenario> correctly" -TestCases @(
                @{
                    scenario = "no 'DeploymentWhatIf' parameter"
                    expected = "^az stack sub create"
                }
                @{
                    scenario         = "false 'DeploymentWhatIf' parameter"
                    deploymentWhatIf = $false
                    expected         = "^az stack sub create"
                }
                @{
                    scenario         = "true 'DeploymentWhatIf' parameter"
                    deploymentWhatIf = $true
                    expected         = "^az stack sub validate"
                }
            ) {
                param ($scenario, $deploymentWhatIf, $expected)
            
                $deploymentConfig + @{ type = "deploymentStack" } | ConvertTo-Json | Set-Content -Path $configFile

                # Create deployment parameter object
                $deploymentWhatIfParam = @{}
                if ($deploymentWhatIf) {
                    $deploymentWhatIfParam = @{ DeploymentWhatIf = $deploymentWhatIf }
                }

                ./src/Resolve-DeploymentConfig.ps1 @commonParams @deploymentWhatIfParam
                | Select-Object -ExpandProperty "AzureCliCommand" | Should -Match $expected
            }
        }
    }

    # MARK: climprconfig.jsonc behavior
    Context "Handle climprconfig.jsonc behavior correctly" {
        It "Should handle <scenario> correctly" -TestCases @(
            @{
                scenario         = "no climprconfig and no deploymentconfig file"
                climprConfig     = @{}
                deploymentConfig = @{}
                expected         = "westeurope" # Action default
            }
            @{
                scenario         = "climprconfig action default override"
                climprConfig     = @{ bicepDeployment = @{ location = 'swedencentral' } }
                deploymentConfig = @{}
                expected         = "swedencentral"
            }
            @{
                scenario         = "deploymentconfig override action default"
                climprConfig     = @{}
                deploymentConfig = @{ location = 'swedencentral' }
                expected         = "swedencentral"
            }
            @{
                scenario         = "deploymentconfig override climprconfig"
                climprConfig     = @{ bicepDeployment = @{ location = 'eastus' } }
                deploymentConfig = @{ location = 'swedencentral' }
                expected         = "swedencentral"
            }
        ) {
            param ($scenario, $climprConfig, $deploymentConfig, $expected)
            
            $climprConfig | ConvertTo-Json | Set-Content -Path $climprConfigFile
            $deploymentConfig | ConvertTo-Json | Set-Content -Path $configFile

            $res = ./src/Resolve-DeploymentConfig.ps1 @commonParams
            $res.Location | Should -Be $expected
        }
    }
}
