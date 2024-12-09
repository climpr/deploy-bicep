BeforeAll {
    if ((Get-PSResourceRepository -Name PSGallery).Trusted -eq $false) {
        Set-PSResourceRepository -Name PSGallery -Trusted -Confirm:$false
    }
    if ((Get-PSResource -Name Bicep -ErrorAction Ignore).Version -lt "2.5.0") {
        Install-PSResource -Name Bicep
    }
    Import-Module $PSScriptRoot/../support-functions.psm1
    $script:commonParam = @{
        Quiet                       = $true
        Debug                       = $false
        GitHubEventName             = "workflow_dispatch"
        DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
    }
    $script:shortHash = git rev-parse --short HEAD
}

Describe "Resolve-DeploymentConfig.ps1" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        $script:mockDirectory = Resolve-Path -Relative -Path "$scriptRoot/mock"
    }

    Context "When the deployment type is 'deployment'" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/deployment/default/dev.bicepparam"
        }

        It "The 'Deploy' property should be 'true'" {
            $res.Deploy | Should -BeTrue
        }
        It "The 'AzureCliVersion' property should be '2.59.0'" {
            $res.AzureCliVersion | Should -Be "2.59.0"
        }
        It "The 'Type' property should be 'deployment'" {
            $res.Type | Should -Be "deployment"
        }
        It "The 'Scope' property should be 'subscription'" {
            $res.Scope | Should -Be "subscription"
        }
        It "The 'ParameterFile' property should be './src/tests/mock/deployments/deployment/default/dev.bicepparam'" {
            $res.ParameterFile | Should -Be "./src/tests/mock/deployments/deployment/default/dev.bicepparam"
        }
        It "The 'TemplateReference' property should be 'main.bicep'" {
            $res.TemplateReference | Should -Be 'main.bicep'
        }
        It "The 'Name' property should be 'default-dev-$shortHash'" {
            $res.Name | Should -Be "default-dev-$shortHash"
        }
        It "The 'Location' property should be 'westeurope'" {
            $res.Location | Should -Be "westeurope"
        }
        It "The 'ManagementGroupId' property should be empty" {
            $res.ManagementGroupId | Should -BeNullOrEmpty
        }
        It "The 'ResourceGroupName' property should be empty" {
            $res.ResourceGroupName | Should -BeNullOrEmpty
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name default-dev-$shortHash --parameters $mockDirectory/deployments/deployment/default/dev.bicepparam"
        }
    }

    Context "When a deployment uses a local template" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/deployment/local-template/dev.bicepparam"
        }

        It "The 'TemplateReference' property should be 'main.bicep'" {
            $res.TemplateReference | Should -Be 'main.bicep'
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name local-template-dev-$shortHash --parameters $mockDirectory/deployments/deployment/local-template/dev.bicepparam"
        }
    }

    Context "When a deployment uses a remote template" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/deployment/remote-template/dev.bicepparam"
        }

        It "The 'TemplateReference' property should be 'br/public:avm/res/resources/resource-group:0.2.3'" {
            $res.TemplateReference | Should -Be 'br/public:avm/res/resources/resource-group:0.2.3'
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name remote-template-dev-$shortHash --parameters $mockDirectory/deployments/deployment/remote-template/dev.bicepparam"
        }
    }

    Context "When a deployment uses a template with local modules" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/deployment/local-modules/dev.bicepparam"
        }

        It "The 'TemplateReference' property should be 'main.bicep'" {
            $res.TemplateReference | Should -Be 'main.bicep'
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name local-modules-dev-$shortHash --parameters $mockDirectory/deployments/deployment/local-modules/dev.bicepparam"
        }
    }

    Context "When a deployment uses a template with remote modules" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/deployment/remote-modules/dev.bicepparam"
        }

        It "Should not throw an error" {
            { ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/deployment/remote-modules/dev.bicepparam" } | `
                Should -Not -Throw
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name remote-modules-dev-$shortHash --parameters $mockDirectory/deployments/deployment/remote-modules/dev.bicepparam"
        }
    }

    Context "When the deployment type is 'stack'" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'Deploy' property should be 'true'" {
            $res.Deploy | Should -BeTrue
        }
        It "The 'AzureCliVersion' property should be '2.59.0'" {
            $res.AzureCliVersion | Should -Be "2.59.0"
        }
        It "The 'Type' property should be 'stack'" {
            $res.Type | Should -Be "stack"
        }
        It "The 'Scope' property should be 'subscription'" {
            $res.Scope | Should -Be "subscription"
        }
        It "The 'ParameterFile' property should be './src/tests/mock/deployments/stack/default/dev.bicepparam'" {
            $res.ParameterFile | Should -Be "./src/tests/mock/deployments/stack/default/dev.bicepparam"
        }
        It "The 'TemplateReference' property should be 'main.bicep'" {
            $res.TemplateReference | Should -Be 'main.bicep'
        }
        It "The 'Name' property should be 'default-stack'" {
            $res.Name | Should -Be "default-stack"
        }
        It "The 'Location' property should be 'westeurope'" {
            $res.Location | Should -Be "westeurope"
        }
        It "The 'ManagementGroupId' property should be empty" {
            $res.ManagementGroupId | Should -BeNullOrEmpty
        }
        It "The 'ResourceGroupName' property should be empty" {
            $res.ResourceGroupName | Should -BeNullOrEmpty
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack does not have a 'description' property" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--description `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'description' property with a null value" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                    description      = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--description `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'description' property with an empty string" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                    description      = ""
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--description `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'description' property with an actual string" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                    description      = "mock-description"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--description `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'bypassStackOutOfSyncError' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'bypassStackOutOfSyncError' property set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                  = "westeurope"
                    type                      = "stack"
                    name                      = "default-stack"
                    actionOnUnmanage          = "deleteAll"
                    denySettingsMode          = "denyDelete"
                    bypassStackOutOfSyncError = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'bypassStackOutOfSyncError' property set to false" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                  = "westeurope"
                    type                      = "stack"
                    name                      = "default-stack"
                    actionOnUnmanage          = "deleteAll"
                    denySettingsMode          = "denyDelete"
                    bypassStackOutOfSyncError = $false
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'bypassStackOutOfSyncError' property set to true" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                  = "westeurope"
                    type                      = "stack"
                    name                      = "default-stack"
                    actionOnUnmanage          = "deleteAll"
                    denySettingsMode          = "denyDelete"
                    bypassStackOutOfSyncError = $true
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --bypass-stack-out-of-sync-error --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsApplyToChildScopes' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsApplyToChildScopes' property set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsApplyToChildScopes = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsApplyToChildScopes' property set to false" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsApplyToChildScopes = $false
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsApplyToChildScopes' property set to true" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsApplyToChildScopes = $true
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-apply-to-child-scopes --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedActions' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-actions `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedActions' property is set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                    = "westeurope"
                    type                        = "stack"
                    name                        = "default-stack"
                    actionOnUnmanage            = "deleteAll"
                    denySettingsMode            = "denyDelete"
                    denySettingsExcludedActions = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-actions `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedActions' property is set to an empty array" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                    = "westeurope"
                    type                        = "stack"
                    name                        = "default-stack"
                    actionOnUnmanage            = "deleteAll"
                    denySettingsMode            = "denyDelete"
                    denySettingsExcludedActions = @()
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-actions `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-excluded-actions `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedActions' property is set to an array with a single entry" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                    = "westeurope"
                    type                        = "stack"
                    name                        = "default-stack"
                    actionOnUnmanage            = "deleteAll"
                    denySettingsMode            = "denyDelete"
                    denySettingsExcludedActions = @( "mock-action" )
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-actions `"mock-action`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-excluded-actions `"mock-action`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedActions' property is set to an array with a multiple entries" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                    = "westeurope"
                    type                        = "stack"
                    name                        = "default-stack"
                    actionOnUnmanage            = "deleteAll"
                    denySettingsMode            = "denyDelete"
                    denySettingsExcludedActions = @(
                        "mock-action1"
                        "mock-action2"
                    )
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-actions `"mock-action1`" `"mock-action2`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-excluded-actions `"mock-action1`" `"mock-action2`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedPrincipals' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-principals `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedPrincipals' property is set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsExcludedPrincipals = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-principals `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedPrincipals' property is set to an empty array" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsExcludedPrincipals = @()
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-principals `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-excluded-principals `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedPrincipals' property is set to an array with a single entry" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsExcludedPrincipals = @( "mock-action" )
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-principals `"mock-action`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-excluded-principals `"mock-action`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettingsExcludedPrincipals' property is set to an array with a multiple entries" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                       = "westeurope"
                    type                           = "stack"
                    name                           = "default-stack"
                    actionOnUnmanage               = "deleteAll"
                    denySettingsMode               = "denyDelete"
                    denySettingsExcludedPrincipals = @(
                        "mock-principal1"
                        "mock-principal2"
                    )
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-principals `"mock-principal1`" `"mock-principal2`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deny-settings-excluded-principals `"mock-principal1`" `"mock-principal2`" --tags `"`""
        }
    }

    Context "When the stack does not have a tags property" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the correct tags syntax" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has an empty tags property" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                    tags             = @{}
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the correct tags syntax" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a tags property containing a single entry" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                    tags             = @{
                        "key" = "value"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the correct tags syntax" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags 'key=value'"
        }
    }

    Context "When the stack has a tags property containing multiple entries" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                    tags             = [ordered]@{
                        "key1" = "value1"
                        "key2" = "value2"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the correct tags syntax" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags 'key1=value1' 'key2=value2'"
        }
    }

    Context "When the stack has a subscription scope and 'deploymentResourceGroup' is not specified" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "stack"
                    name             = "default-stack"
                    actionOnUnmanage = "deleteAll"
                    denySettingsMode = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deployment-resource-group' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a subscription scope and 'deploymentResourceGroup' is specified" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location                = "westeurope"
                    type                    = "stack"
                    name                    = "default-stack"
                    actionOnUnmanage        = "deleteAll"
                    denySettingsMode        = "denyDelete"
                    deploymentResourceGroup = "mock-rg"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deployment-resource-group' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deployment-resource-group mock-rg --tags `"`""
        }
    }

    Context "When the stack has a management group scope and 'deploymentSubscription' is not specified" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location          = "westeurope"
                    managementGroupId = "mock-managementgroup-id"
                    type              = "stack"
                    name              = "default-stack"
                    actionOnUnmanage  = "deleteAll"
                    denySettingsMode  = "denyDelete"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/managementgroup/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deployment-resource-group' parameter" {
            $res.AzureCliCommand | Should -Be "az stack mg create --location westeurope --management-group-id mock-managementgroup-id --name default-stack --parameters $mockDirectory/deployments/stack/managementgroup/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a management group scope and 'deploymentSubscription' is specified" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location               = "westeurope"
                    managementGroupId      = "mock-managementgroup-id"
                    type                   = "stack"
                    name                   = "default-stack"
                    actionOnUnmanage       = "deleteAll"
                    denySettingsMode       = "denyDelete"
                    deploymentSubscription = "mock-sub"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -ParameterFilePath "$mockDirectory/deployments/stack/managementgroup/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deployment-subscription' parameter" {
            $res.AzureCliCommand | Should -Be "az stack mg create --location westeurope --management-group-id mock-managementgroup-id --name default-stack --parameters $mockDirectory/deployments/stack/managementgroup/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --deployment-subscription mock-sub --tags `"`""
        }
    }
}
