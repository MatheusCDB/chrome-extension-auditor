# Inventario-Chrome.ps1
# Coleta extensões do Chrome e gera JSON no compartilhamento

$usersPath = "C:\Users"
$chromeUserDataRelative = "AppData\Local\Google\Chrome\User Data"
$extensoesColetadas = @()

foreach ($user in Get-ChildItem $usersPath -Directory) {
    $chromeBasePath = Join-Path $user.FullName $chromeUserDataRelative
    
    if (Test-Path $chromeBasePath) {
        $profileDirs = Get-ChildItem -Path $chromeBasePath -Directory | Where-Object {
            Test-Path "$($_.FullName)\Extensions"
        }
        
        foreach ($profile in $profileDirs) {
            $extensionsPath = Join-Path $profile.FullName "Extensions"
            $extDirs = Get-ChildItem -Path $extensionsPath -Directory -ErrorAction SilentlyContinue
            
            foreach ($ext in $extDirs) {
                $extId = $ext.Name
                $versionFolder = Get-ChildItem -Path $ext.FullName -Directory | Sort-Object Name -Descending | Select-Object -First 1
                
                if ($versionFolder) {
                    $manifestPath = Join-Path $versionFolder.FullName "manifest.json"
                    
                    if (Test-Path $manifestPath) {
                        try {
                            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                            $extName = $manifest.name
                            
                            # Traduz nomes com __MSG_*__
                            if ($extName -like "__MSG_*__") {
                                $msgId = $extName -replace "__MSG_(.*)__", '$1'
                                $localePath = Join-Path $versionFolder.FullName "_locales\pt_BR\messages.json"
                                
                                if (-not (Test-Path $localePath)) {
                                    $localePath = Join-Path $versionFolder.FullName "_locales\en\messages.json"
                                }
                                
                                if (Test-Path $localePath) {
                                    $messages = Get-Content $localePath -Raw | ConvertFrom-Json
                                    if ($messages.$msgId.message) {
                                        $extName = $messages.$msgId.message
                                    }
                                }
                            }
                            
                            # Adiciona ao array com estrutura JSON
                            $extensoesColetadas += [PSCustomObject]@{
                                Computer    = $env:COMPUTERNAME
                                User        = $user.Name
                                Profile     = $profile.Name
                                Extension   = $extName
                                ID          = $extId
                                Version     = $versionFolder.Name
                                ScanDate    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                            }
                            
                        } catch {
                            # Registra erro mas continua
                            $extensoesColetadas += [PSCustomObject]@{
                                Computer    = $env:COMPUTERNAME
                                User        = $user.Name
                                Profile     = $profile.Name
                                Extension   = "ERRO: $($_.Exception.Message)"
                                ID          = $extId
                                Version     = "N/A"
                                ScanDate    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                            }
                        }
                    }
                }
            }
        }
    }
}

# Gera JSON e salva
$jsonOutput = $extensoesColetadas | ConvertTo-Json -Depth 3
$arquivoJson = "\\fileserver02.copobras.local\ArquivosCopobras\Extensoes\$($env:COMPUTERNAME).json"
$jsonOutput | Out-File -FilePath $arquivoJson -Encoding UTF8

Write-Output "Inventário concluído. Arquivo salvo em: $arquivoJson"
Write-Output "Total de extensões encontradas: $($extensoesColetadas.Count)"
# SIG # Begin signature block
# MIIb5QYJKoZIhvcNAQcCoIIb1jCCG9ICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmgTpwUneu5YVDPnZDWBjKDD/
# sMqgghZVMIIDFzCCAf+gAwIBAgIQHgwdIvC8oJpPOeJsLsPzUTANBgkqhkiG9w0B
# AQsFADAbMRkwFwYDVQQDDBBBVEEgQXV0aGVudGljb2RlMB4XDTI1MDkxNzEyNDk0
# MVoXDTI4MDkxNzEyNTk0MVowGzEZMBcGA1UEAwwQQVRBIEF1dGhlbnRpY29kZTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALScHLdRygtN+iX2cSBBwAZs
# j4pyQXGLCmCz60f7fjNuZ5OYhnqYDhE1LppzWpO18a5ox1SxKIp/YSlYh/+Wfbj1
# B8CS4UiXlSR2/3pxQEXA8tg+U4JU846AsXlxaE5FMFWlGBdvz4PABXP+LaemYWEv
# RQB7S+i4iVEKyiYPuBl6ZzyF6yo4WtmWgnKZS95/KavRChqMJqLkzCIKGEN07BO4
# Ylx83+K1WaoMBBP+cB9b6Q7kF2l0lneBIPFwZt9yU2GflAXDabXy109uqsO6Reo3
# FCxHfaCDhlVKd43EqlS7tCKfmcLAW9i+yxcLWYoes0Jgq1gxzvDw3jfaM5SMX00C
# AwEAAaNXMFUwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA8G
# A1UdEQQIMAaCBEFEMDEwHQYDVR0OBBYEFDMAh3y6mfj46g366eCG8q+gFNzQMA0G
# CSqGSIb3DQEBCwUAA4IBAQAXPxuD71w/Q51D/7jMR5GtZhbGUx+iZjJnvzeXww8u
# 25LuFms/yXVtdK9F+rrOHQ1630Cd9YZf8UU3KJXhBUaNhClITWoIgPnTHys94l2s
# 2Lcv2icujduXmoO+HgaUEaxlzw3HXaPbFj1946xSXpy+v8jOg9/S5jBx9WXF8lpC
# dH+Hxw/9SztvsFc0Jl70MKpsQrRdm6TmelvFoXvM3+WH3RUo8sBLlYWAloMOtZpM
# M0s//CNOg2nTP0875K+LfBUDk23kFUTdoxsbdo1ozPE7N/kUMX8KxxO90o6gtYUO
# JcHa1CXXx2kUO/vodOTN9lqTVvPmdxyvm9ddyYOO/ZkLMIIFjTCCBHWgAwIBAgIQ
# DpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAx
# MDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQD
# ExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aa
# za57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllV
# cq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT
# +CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd
# 463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+
# EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92k
# J7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5j
# rubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7
# f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJU
# KSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+wh
# X8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQAB
# o4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0P
# AQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDww
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IB
# AQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229
# GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FD
# RJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVG
# amlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCw
# rFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvR
# XKwYw02fc7cBqZ9Xql4o4rmUMIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJ
# hjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdp
# Q2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1
# OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# tHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkb
# sDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+
# AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAkt
# VJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3
# Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv8
# 2wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638Z
# xqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7V
# vwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2N
# L+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTK
# IsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUoz
# ZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIG
# A1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtO
# MB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIB
# hjATBgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQw
# QwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZI
# AYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N
# 0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7J
# d2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1j
# EMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdog
# P8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMv
# NYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBld
# NE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjT
# Y6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/B
# dHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyI
# PbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8
# dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2j
# NrbM1pD2T7m3XDCCBu0wggTVoAMCAQICEAqA7xhLjfEFgtHEdqeVdGgwDQYJKoZI
# hvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0
# MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5
# NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkG
# A1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRl
# ciAyMDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDQRqwtEsae
# 0OquYFazK1e6b1H/hnAKAd/KN8wZQjBjMqiZ3xTWcfsLwOvRxUwXcGx8AUjni6bz
# 52fGTfr6PHRNv6T7zsf1Y/E3IU8kgNkeECqVQ+3bzWYesFtkepErvUSbf+EIYLkr
# LKd6qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4vEjoT1FpS54dNApZfKY61HAldytxNM89
# PZXUP/5wWWURK+IfxiOg8W9lKMqzdIo7VA1R0V3Zp3DjjANwqAf4lEkTlCDQ0/fK
# JLKLkzGBTpx6EYevvOi7XOc4zyh1uSqgr6UnbksIcFJqLbkIXIPbcNmA98Oskkkr
# vt6lPAw/p4oDSRZreiwB7x9ykrjS6GS3NR39iTTFS+ENTqW8m6THuOmHHjQNC3zb
# J6nJ6SXiLSvw4Smz8U07hqF+8CTXaETkVWz0dVVZw7knh1WZXOLHgDvundrAtuvz
# 0D3T+dYaNcwafsVCGZKUhQPL1naFKBy1p6llN3QgshRta6Eq4B40h5avMcpi54wm
# 0i2ePZD5pPIssoszQyF4//3DoK2O65Uck5Wggn8O2klETsJ7u8xEehGifgJYi+6I
# 03UuT1j7FnrqVrOzaQoVJOeeStPeldYRNMmSF3voIgMFtNGh86w3ISHNm0IaadCK
# CkUe2LnwJKa8TIlwCUNVwppwn4D3/Pt5pwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/
# BAIwADAdBgNVHQ4EFgQU5Dv88jHt/f3X85FxYxlQQ89hjOgwHwYDVR0jBBgwFoAU
# 729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0
# cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0
# MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNB
# NDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCG
# SAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAZSqt8RwnBLmuYEHs0QhEnmNAciH4
# 5PYiT9s1i6UKtW+FERp8FgXRGQ/YAavXzWjZhY+hIfP2JkQ38U+wtJPBVBajYfrb
# IYG+Dui4I4PCvHpQuPqFgqp1PzC/ZRX4pvP/ciZmUnthfAEP1HShTrY+2DE5qjzv
# Zs7JIIgt0GCFD9ktx0LxxtRQ7vllKluHWiKk6FxRPyUPxAAYH2Vy1lNM4kzekd8o
# EARzFAWgeW3az2xejEWLNN4eKGxDJ8WDl/FQUSntbjZ80FU3i54tpx5F/0Kr15zW
# /mJAxZMVBrTE2oi0fcI8VMbtoRAmaaslNXdCG1+lqvP4FbrQ6IwSBXkZagHLhFU9
# HCrG/syTRLLhAezu/3Lr00GrJzPQFnCEH1Y58678IgmfORBPC1JKkYaEt2OdDh4G
# mO0/5cHelAK2/gTlQJINqDr6JfwyYHXSd+V08X1JUPvB4ILfJdmL+66Gp3CSBXG6
# IwXMZUXBhtCyIaehr0XkBoDIGMUG1dUtwq1qmcwbdUfcSYCn+OwncVUXf53VJUNO
# aMWMts0VlRYxe5nK+At+DI96HAlXHAL5SlfYxJ7La54i71McVWRP66bW+yERNpbJ
# CjyCYG2j+bdpxo/1Cy4uPcU3AWVPGrbn5PhDBf3Froguzzhk++ami+r3Qrx5bIbY
# 3TVzgiFI7Gq3zWcxggT6MIIE9gIBATAvMBsxGTAXBgNVBAMMEEFUQSBBdXRoZW50
# aWNvZGUCEB4MHSLwvKCaTznibC7D81EwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFE/UXWo43t3
# fhS/ZXuVPwF6C27JMA0GCSqGSIb3DQEBAQUABIIBAKTVHeMC+dAokB3aob5unji/
# HMC4Z5teWT51lf0oYBYMmaCqT8iT3RsW5JoPqavWTD5PMv4p0ptARieqdC6C7P0h
# Tmawyv1BH2Acl15FgXYpQ6oxVk7/yfkLNMHYCora+v/fhNqe0VLah4h32oHbfJZ8
# OZhwwW99hOtPi52btCnHpYt+Eh5sq/KXqNsf/cHKzOpGheQjAPHKFkndLANQdbNd
# Tkr9DoJpmDefMHoJcScs60sk9pS24SI0D1dqRS7cdKrhBIWdD2YPrpU39JkFLCdw
# JDGiK+NGN2AH25U1re8hQNfThUkar3wJ/R9X8XYkEl3LyEYykbmh903kYYDic6Kh
# ggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEwfTBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExAhAKgO8Y
# S43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYwNjMwMTQxMjExWjAvBgkqhkiG9w0B
# CQQxIgQgBpN4+z9ucftMPeh+DUU4zG4//BILw3JSW0AiX/4xeZowDQYJKoZIhvcN
# AQEBBQAEggIAs15hl/p1eU5nOaBonB05FORnZKFvDsaoEF6vrrRwABfsr0O4DLgU
# lzj6s/Est4G1W3X24Ab9dITHQ7bd3MiENFQbAhtJ0dET8V47VWpoXIAnOWlUN0N8
# GoIpSQ9wx5YbgIfbQZimzCMxTayslUvl5hZAloQmRiUUksj/l5LR4lejw+bvkP5i
# O2TRdTFAAtSo/F8D6qebujNPj58C6Id6Vm0FnILQ8MSsyudlnCkie5kFGbFLMHGF
# 8Ibw9ZmQSKyCuiONmWTpWdY1wrhWF7GlzFBnmSMqLibsBq7qKnN4bhwQ++yTSzV/
# EoiIbrZbrWH4kZwBQqN+WPNvDNJWy2QMKF8lqC+BldwzmGIiDzqjTjs8mLWfE5D3
# 7qv5aK7H1KtW06C/paO9Kk3x6GE7fHTj6FrS9lYHLbvuCRXO7Z/ZlcnDtFRXSSh2
# jn+vE6BfQDeJ1XOKcZ1YJDBYejL2QApCsXZ7dxx07n3b8hom2raL05ZOshaEANcl
# egHoo5UqtzFrZEAuANUatueo4LMbi2sLLo5eVJxhxzd0scH3L0WbZxkRxJT++c13
# hnl8IQo/0U0u+u5Jrsvsa/g1fpiUAzVHNI5mw/mRRSIAY1r32wJCyY9H/F7Nd5mB
# SXhU4B0w61xnvE7Sivm9Oh/tyZWBVjACmmLpC8+SehbITfk4rLo11Ew=
# SIG # End signature block
