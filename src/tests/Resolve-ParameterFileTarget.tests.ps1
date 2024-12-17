BeforeAll {
    if ((Get-PSResourceRepository -Name PSGallery).Trusted -eq $false) {
        Set-PSResourceRepository -Name PSGallery -Trusted -Confirm:$false
    }
    if ((Get-PSResource -Name Bicep -ErrorAction Ignore).Version -lt "2.7.0") {
        Install-PSResource -Name Bicep
    }
    Import-Module $PSScriptRoot/../support-functions.psm1 -Force
    $script:mockDirectory = Resolve-Path -Relative -Path "$PSScriptRoot/mock"
}

Describe "Resolve-ParameterFileTarget" {
    Context "When the input is a file (Path)" {
        BeforeAll {
            $script:tempFile = New-TemporaryFile
            "using 'main.bicep'" | Out-File -Path $tempFile
        }

        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Path $tempFile
        }

        AfterAll {
            $script:tempFile | Remove-Item -Force -Confirm:$false
        }
    }

    Context "When the input is a string (Content)" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Content "using 'main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file contains a properly formatted: `"using 'main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Content "using 'main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file contains leading spaces: `"  using   '   main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Content "using   '   main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file does not contain spaces: `"using'main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Content "using'main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file contains relative paths with '.': `"using './main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Content "using './main.bicep'" | Should -Be "./main.bicep"
        }
    }

    Context "When the parameter file contains relative paths with '/': `"using '/main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -Content "using '/main.bicep'" | Should -Be "/main.bicep"
        }
    }

    Context "When the parameter file contains ACR or TS paths" {
        It "It should return 'br/public:filepath:tag'" {
            Resolve-ParameterFileTarget -Content "using 'br/public:filepath:tag''" | Should -Be "br/public:filepath:tag"
        }

        It "It should return 'br:mcr.microsoft.com/bicep/filepath:tag'" {
            Resolve-ParameterFileTarget -Content "using 'br:mcr.microsoft.com/bicep/filepath:tag''" | Should -Be "br:mcr.microsoft.com/bicep/filepath:tag"
        }
    }

    Context "When targetScope-keyword in template is not on line 1" {
        It "Should have a TemplateReference pointing to a targetScopeLine2" {
            Resolve-ParameterFileTarget -Path "$mockDirectory/deployments/deployment/comments/targetScopeLine2.bicepparam" | Should -Be 'targetScopeLine2.bicep'
        }
    }
    
    Context "When using-keyword in parameterfile is not on line 1" {
        It "Should have a TemplateReference pointing to a usingLine2" {
            Resolve-ParameterFileTarget -Path "$mockDirectory/deployments/deployment/comments/usingLine2.bicepparam" | Should -Be 'usingLine2.bicep'
        }
    }

    Context "When using-keyword is commented before the actual using-keyword" {
        It "Should have a TemplateReference pointing to a usingCommented" {
            Resolve-ParameterFileTarget -Path "$mockDirectory/deployments/deployment/comments/usingCommented.bicepparam" | Should -Be 'usingCommented.bicep'
        }
    }

    Context "When scope-keyword is commented before the actual scope-keyword" {
        It "Should have a TemplateReference pointing to a usingCommented" {
            Resolve-ParameterFileTarget -Path "$mockDirectory/deployments/deployment/comments/targetScopeCommented.bicepparam" | Should -Be 'targetScopeCommented.bicep'
        }
    }
}