BeforeAll {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module Bicep -MinimumVersion "2.5.0"
    Import-Module $PSScriptRoot/../support-functions.psm1
}

Describe "Resolve-ParameterFileTarget" {
    Context "When the input is a file (ParameterFilePath)" {
        BeforeAll {
            $script:tempFile = New-TemporaryFile
            "using 'main.bicep'" | Out-File -Path $tempFile
        }

        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFilePath $tempFile
        }

        AfterAll {
            $script:tempFile | Remove-Item -Force -Confirm:$false
        }
    }

    Context "When the input is a string (ParameterFileContent)" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using 'main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file contains a properly formatted: `"using 'main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using 'main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file contains leading spaces: `"  using   '   main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using   '   main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file does not contain spaces: `"using'main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using'main.bicep'" | Should -Be "main.bicep"
        }
    }

    Context "When the parameter file contains relative paths with '.': `"using './main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using './main.bicep'" | Should -Be "./main.bicep"
        }
    }

    Context "When the parameter file contains relative paths with '/': `"using '/main.bicep'`"" {
        It "It should return 'main.bicep'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using '/main.bicep'" | Should -Be "/main.bicep"
        }
    }

    Context "When the parameter file contains ACR or TS paths" {
        It "It should return 'br/public:filepath:tag'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using 'br/public:filepath:tag''" | Should -Be "br/public:filepath:tag"
        }

        It "It should return 'br:mcr.microsoft.com/bicep/filepath:tag'" {
            Resolve-ParameterFileTarget -ParameterFileContent "using 'br:mcr.microsoft.com/bicep/filepath:tag''" | Should -Be "br:mcr.microsoft.com/bicep/filepath:tag"
        }
    }
}