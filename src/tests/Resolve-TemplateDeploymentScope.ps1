BeforeAll {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module Bicep -MinimumVersion "2.5.0"
    Import-Module $PSScriptRoot/../support-functions.psm1
}

Describe "Resolve-TemplateDeploymentScope.ps1" {
    BeforeAll {
        $script:mockDirectory = "$PSScriptRoot/mock"
    }

    Context "When targetScope-keyword in template is not on line 1" {
        BeforeAll {
            $script:param = @{
                ParameterFilePath = "$mockDirectory/deployments/workload-local-comments/targetScopeLine2.bicepparam"
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
                ParameterFilePath = "$mockDirectory/deployments/workload-local-comments/usingLine2.bicepparam"
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
                ParameterFilePath = "$mockDirectory/deployments/workload-local-comments/usingCommented.bicepparam"
                DeploymentConfig  = @{ 'managementGroupId' = 'mockMgmtGroupId' }
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
                ParameterFilePath = "$mockDirectory/deployments/workload-local-comments/targetScopeCommented.bicepparam"
                DeploymentConfig  = @{ 'managementGroupId' = 'mockMgmtGroupId' }
            }
            $script:templateDeploymentScope = Resolve-TemplateDeploymentScope @param
        }

        It "Should resolve DeploymentScope to be [subscription]" {
            $templateDeploymentScope | Should -Be 'subscription'
        }
    }
}
