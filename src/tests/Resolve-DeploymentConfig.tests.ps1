BeforeAll {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module Bicep -MinimumVersion "2.5.0"
    Import-Module $PSScriptRoot/../support-functions.psm1
}

Describe "Resolve-DeploymentConfig.ps1" {
    BeforeAll {
        $script:mockDirectory = "$PSScriptRoot/mock"
    }

    Context "When a deployment uses a local template" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-local/dev.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "workflow_dispatch"
                Quiet                       = $false
                Debug                       = $true
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have a TemplateReference pointing to a local template" {
            $res.TemplateReference | Should -Be 'main.bicep'
        }

        It "Should have Deploy property calculated to 'false'" {
            $res.Deploy | Should -BeFalse
        }
    }

    Context "When targetScope-keyword in template is not on line 1" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-local-comments/targetScopeLine2.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "workflow_dispatch"
                Quiet                       = $true
                Debug                       = $true
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have a TemplateReference pointing to a targetScopeLine2" {
            $res.TemplateReference | Should -Be 'targetScopeLine2.bicep'
        }

        It "Should have Scope like [subscription]" {
            $res.Scope | Should -Be 'subscription'
        }
    }

    Context "When using-keyword in parameterfile is not on line 1" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{ 'managementGroupId' = 'mockMgmtGroupId' }
            }

            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-local-comments/usingLine2.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "workflow_dispatch"
                Quiet                       = $true
                Debug                       = $true
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have a TemplateReference pointing to a usingLine2" {
            $res.TemplateReference | Should -Be 'usingLine2.bicep'
        }

        It "Should have Scope like [managementGroup]" {
            $res.Scope | Should -Be 'managementGroup'
        }

        It "Should have same ManagementGroupId as mock [mockMgmtGroupId]" {
            $res.ManagementGroupId | Should -Be 'mockMgmtGroupId'
        }
    }

    Context "When using-keyword is commented before the actual using-keyword" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{
                    'managementGroupId' = 'mockMgmtGroupId'
                    'resourceGroupName' = 'mockResourceGroupName'
                }
            }

            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-local-comments/usingCommented.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "workflow_dispatch"
                Quiet                       = $true
                Debug                       = $true
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have a TemplateReference pointing to a usingCommented" {
            $res.TemplateReference | Should -Be 'usingCommented.bicep'
        }

        It "Should have Scope like [resourceGroup]" {
            $res.Scope | Should -Be 'resourceGroup'
        }
    }

    Context "When scope-keyword is commented before the actual scope-keyword" {
        BeforeAll {
            Mock Get-DeploymentConfig {
                return @{ 'managementGroupId' = 'mockMgmtGroupId' }
            }

            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-local-comments/targetScopeCommented.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "workflow_dispatch"
                Quiet                       = $true
                Debug                       = $true
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have a TemplateReference pointing to a usingCommented" {
            $res.TemplateReference | Should -Be 'targetScopeCommented.bicep'
        }

        It "Should have Scope like [subscription]" {
            $res.Scope | Should -Be 'subscription'
        }
    }

    Context "With conflicting deploymentconfig files" {
        BeforeAll {
            $script:deploymentPath = "$mockDirectory/deployments/workload-multi-deploymentconfig"
            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-multi-deploymentconfig/dev.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "workflow_dispatch"
                Quiet                       = $true
                Debug                       = $false
            }
            Copy-Item -Path "$deploymentPath/deploymentconfig.json" -Destination "$deploymentPath/deploymentconfig.jsonc"
        }

        It "Should throw 'Found multiple deploymentconfig files.'" {
            { ./src/Resolve-DeploymentConfig.ps1 @param } | Should -Throw "*Found multiple deploymentconfig files.*"
        }

        AfterAll {
            Remove-Item -Path "$script:deploymentPath/deploymentconfig.jsonc" -Confirm:$false
        }
    }

    Context "With jsonc deploymentconfig file" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath           = "$mockDirectory/deployments/workload-jsonc-deploymentconfig/dev.bicepparam"
                DefaultDeploymentConfigPath = "$mockDirectory/default.deploymentconfig.json"
                GitHubEventName             = "schedule"
                Quiet                       = $true
                Debug                       = $false
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have Deploy property calculated to 'false'" {
            $res.Deploy | Should -BeFalse
        }
    }
}
