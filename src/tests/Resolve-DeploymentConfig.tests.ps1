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
                Quiet                       = $true
                Debug                       = $true
            }

            $script:res = ./src/Resolve-DeploymentConfig.ps1 @param
        }

        It "Should have a TemplateReference pointing to a local template" {
            $res.TemplateReference | Should -Be 'main.bicep'
        }

        It "Should have a DeploymentConfig.disabled property set to 'true'" {
            $res.DeploymentConfig.disabled | Should -BeTrue
        }
    }
}