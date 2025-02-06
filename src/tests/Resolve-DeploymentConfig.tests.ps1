BeforeAll {
    if ((Get-PSResourceRepository -Name PSGallery).Trusted -eq $false) {
        Set-PSResourceRepository -Name PSGallery -Trusted -Confirm:$false
    }
    if ((Get-PSResource -Name Bicep -ErrorAction Ignore).Version -lt "2.7.0") {
        Install-PSResource -Name Bicep
    }
    Import-Module $PSScriptRoot/../support-functions.psm1 -Force
    $script:mockDirectory = Resolve-Path -Relative -Path "$PSScriptRoot/mock"
    $script:commonParam = @{
        Quiet                       = $true
        Debug                       = $false
        GitHubEventName             = "workflow_dispatch"
        DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
    }
    $script:shortHash = git rev-parse --short HEAD
}

Describe "Resolve-DeploymentConfig.ps1" {
    Context "When the deployment type is 'deployment'" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/default/dev.bicepparam"
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
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/local-template/dev.bicepparam"
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
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/remote-template/dev.bicepparam"
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
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/local-modules/dev.bicepparam"
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
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/remote-modules/dev.bicepparam"
        }

        It "Should not throw an error" {
            { ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/remote-modules/dev.bicepparam" } | `
                Should -Not -Throw
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name remote-modules-dev-$shortHash --parameters $mockDirectory/deployments/deployment/remote-modules/dev.bicepparam"
        }
    }

    Context "When a deployment does not have a .bicepparam file" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/no-param-default/dev.bicep"
        }

        It "Should not throw an error" {
            { ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/no-param-default/dev.bicep" } | `
                Should -Not -Throw
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name no-param-default-dev-$shortHash --template-file $mockDirectory/deployments/deployment/no-param-default/dev.bicep"
        }
    }

    Context "When a deployment does not have a .bicepparam file" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/no-param-default/dev.bicep"
        }

        It "Should not throw an error" {
            { ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/no-param-default/dev.bicep" } | `
                Should -Not -Throw
        }
        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name no-param-default-dev-$shortHash --template-file $mockDirectory/deployments/deployment/no-param-default/dev.bicep"
        }
    }

    Context "When a deployment uses the 'DeploymentWhatIf' parameter" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/deployment/default/dev.bicepparam" -DeploymentWhatIf $true
        }

        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az deployment sub create --location westeurope --name default-dev-$shortHash --parameters $mockDirectory/deployments/deployment/default/dev.bicepparam --what-if"
        }
    }

    Context "When the deployment type is 'deploymentStack'" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'Deploy' property should be 'true'" {
            $res.Deploy | Should -BeTrue
        }
        It "The 'AzureCliVersion' property should be '2.59.0'" {
            $res.AzureCliVersion | Should -Be "2.59.0"
        }
        It "The 'Type' property should be 'deploymentStack'" {
            $res.Type | Should -Be "deploymentStack"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                    description      = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                    description      = ""
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                    description      = "mock-description"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type                      = "deploymentStack"
                    name                      = "default-stack"
                    actionOnUnmanage          = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings              = @{
                        mode = "denyDelete"
                    }
                    bypassStackOutOfSyncError = $null
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type                      = "deploymentStack"
                    name                      = "default-stack"
                    actionOnUnmanage          = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings              = @{
                        mode = "denyDelete"
                    }
                    bypassStackOutOfSyncError = $false
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type                      = "deploymentStack"
                    name                      = "default-stack"
                    actionOnUnmanage          = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings              = @{
                        mode = "denyDelete"
                    }
                    bypassStackOutOfSyncError = $true
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --bypass-stack-out-of-sync-error --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.applyToChildScopes' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.applyToChildScopes' property set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        applyToChildScopes = $null
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.applyToChildScopes' property set to false" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        applyToChildScopes = $false
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.applyToChildScopes' property set to true" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        applyToChildScopes = $true
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--bypass-stack-out-of-sync-error `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-apply-to-child-scopes --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedActions' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-actions `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedActions' property is set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode            = "denyDelete"
                        excludedActions = $null
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-actions `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedActions' property is set to an empty array" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode            = "denyDelete"
                        excludedActions = @()
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-actions `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-excluded-actions `"`" --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedActions' property is set to an array with a single entry" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode            = "denyDelete"
                        excludedActions = @(
                            "mock-action"
                        )
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-actions `"mock-action`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-excluded-actions `"mock-action`" --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedActions' property is set to an array with a multiple entries" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode            = "denyDelete"
                        excludedActions = @(
                            "mock-action1"
                            "mock-action2"
                        )
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-actions `"mock-action1`" `"mock-action2`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-excluded-actions `"mock-action1`" `"mock-action2`" --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedPrincipals' property is unset" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-principals `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedPrincipals' property is set to null" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        excludedPrincipals = $null
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deny-settings-excluded-principals `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedPrincipals' property is set to an empty array" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        excludedPrincipals = @()
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-principals `"`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-excluded-principals `"`" --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedPrincipals' property is set to an array with a single entry" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        excludedPrincipals = @(
                            "mock-principal"
                        )
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-principals `"mock-principal`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-excluded-principals `"mock-principal`" --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a 'denySettings.excludedPrincipals' property is set to an array with a multiple entries" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode               = "denyDelete"
                        excludedPrincipals = @(
                            "mock-principal1"
                            "mock-principal2"
                        )
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deny-settings-excluded-principals `"mock-principal1`" `"mock-principal2`"' parameter" {
            $res.AzureCliCommand | Should -Be "az stack sub create --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --yes --action-on-unmanage deleteAll --deny-settings-mode denyDelete --deny-settings-excluded-principals `"mock-principal1`" `"mock-principal2`" --description `"`" --tags `"`""
        }
    }

    Context "When the stack does not have a tags property" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location         = "westeurope"
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                    tags             = @{}
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                    tags             = @{
                        "key" = "value"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                    tags             = [ordered]@{
                        "key1" = "value1"
                        "key2" = "value2"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type             = "deploymentStack"
                    name             = "default-stack"
                    actionOnUnmanage = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings     = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type                    = "deploymentStack"
                    name                    = "default-stack"
                    actionOnUnmanage        = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings            = @{
                        mode = "denyDelete"
                    }
                    deploymentResourceGroup = "mock-rg"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam"
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
                    type              = "deploymentStack"
                    name              = "default-stack"
                    actionOnUnmanage  = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings      = @{
                        mode = "denyDelete"
                    }
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/managementgroup/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should not include the '--deployment-resource-group' parameter" {
            $res.AzureCliCommand | Should -Be "az stack mg create --location westeurope --management-group-id mock-managementgroup-id --name default-stack --parameters $mockDirectory/deployments/stack/managementgroup/dev.bicepparam --yes --action-on-unmanage deleteResources --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }

    Context "When the stack has a management group scope and 'deploymentSubscription' is specified" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    location               = "westeurope"
                    managementGroupId      = "mock-managementgroup-id"
                    type                   = "deploymentStack"
                    name                   = "default-stack"
                    actionOnUnmanage       = @{
                        resources      = "delete"
                        resourceGroups = "delete"
                    }
                    denySettings           = @{
                        mode = "denyDelete"
                    }
                    deploymentSubscription = "mock-sub"
                }
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/managementgroup/dev.bicepparam"
        }

        It "The 'AzureCliCommand' property should include the '--deployment-subscription' parameter" {
            $res.AzureCliCommand | Should -Be "az stack mg create --location westeurope --management-group-id mock-managementgroup-id --name default-stack --parameters $mockDirectory/deployments/stack/managementgroup/dev.bicepparam --yes --action-on-unmanage deleteResources --deny-settings-mode denyDelete --description `"`" --deployment-subscription mock-sub --tags `"`""
        }
    }

    Context "When the stack uses the 'DeploymentWhatIf' parameter" {
        BeforeAll {
            $script:res = ./src/Resolve-DeploymentConfig.ps1 @commonParam -DeploymentFilePath "$mockDirectory/deployments/stack/default/dev.bicepparam" -DeploymentWhatIf $true
        }

        It "The 'AzureCliCommand' property should be correct" {
            $res.AzureCliCommand | Should -Be "az stack sub validate --location westeurope --name default-stack --parameters $mockDirectory/deployments/stack/default/dev.bicepparam --action-on-unmanage deleteAll --deny-settings-mode denyDelete --description `"`" --tags `"`""
        }
    }
}
