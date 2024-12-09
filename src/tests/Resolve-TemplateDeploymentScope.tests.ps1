BeforeAll {
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    if ((Get-PSResource -Name Bicep -ErrorAction Ignore).Version -lt "2.5.0") {
        Install-PSResource -Name Bicep
    }
    Import-Module $PSScriptRoot/../support-functions.psm1 -Force
}

Describe "Resolve-TemplateDeploymentScope.ps1" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        $script:mockDirectory = Resolve-Path -Relative -Path "$scriptRoot/mock"
    }

    Context "When targetScope-keyword in template is not on line 1" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath = "$mockDirectory/deployments/deployment/comments/targetScopeLine2.bicepparam"
                DeploymentConfig  = @{}
            }
            $script:templateDeploymentScope = Resolve-TemplateDeploymentScope @param
        }

        It "Should resolve DeploymentScope to be [subscription]" {
            $templateDeploymentScope | Should -Be 'subscription'
        }
    }

    Context "When using-keyword in parameterfile is not on line 1" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath = "$mockDirectory/deployments/deployment/comments/usingLine2.bicepparam"
                DeploymentConfig  = @{ 'managementGroupId' = 'mockMgmtGroupId' }
            }
            $script:templateDeploymentScope = Resolve-TemplateDeploymentScope @param
        }

        It "Should resolve DeploymentScope to be [managementGroup]" {
            $templateDeploymentScope | Should -Be 'managementGroup'
        }
    }

    Context "When using-keyword is commented before the actual using-keyword" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath = "$mockDirectory/deployments/deployment/comments/usingCommented.bicepparam"
                DeploymentConfig  = @{
                    'managementGroupId' = 'mockMgmtGroupId'
                    'resourceGroupName' = 'mockResourceGroupName'
                }
            }
            $script:templateDeploymentScope = Resolve-TemplateDeploymentScope @param
        }

        It "Should resolve DeploymentScope to be [resourceGroup]" {
            $templateDeploymentScope | Should -Be 'resourceGroup'
        }
    }

    Context "When scope-keyword is commented before the actual scope-keyword" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath = "$mockDirectory/deployments/deployment/comments/targetScopeCommented.bicepparam"
                DeploymentConfig  = @{ 'managementGroupId' = 'mockMgmtGroupId' }
            }
            $script:templateDeploymentScope = Resolve-TemplateDeploymentScope @param
        }

        It "Should resolve DeploymentScope to be [subscription]" {
            $templateDeploymentScope | Should -Be 'subscription'
        }
    }
}
