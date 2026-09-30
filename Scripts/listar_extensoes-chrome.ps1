$usersPath = "C:\Users"
$chromeUserDataRelative = "AppData\Local\Google\Chrome\User Data"
$saida = @()

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

                            # Se o nome for "__MSG_...__", tenta traduzir via messages.json
                            if ($extName -like "__MSG_*__") {
                                $msgId = $extName -replace "__MSG_(.*)__", '$1'
                                $localePath = Join-Path $versionFolder.FullName "_locales\en\messages.json" # tenta inglês
                                if (Test-Path $localePath) {
                                    $messages = Get-Content $localePath -Raw | ConvertFrom-Json
                                    if ($messages.$msgId.message) {
                                        $extName = $messages.$msgId.message
                                    }
                                }
                            }

                            $linha = "Usuário: $($user.Name) | Perfil: $($profile.Name) | Nome: $extName | ID: $extId"
                            $saida += $linha
                        } catch {
                            $saida += "Erro ao ler extensão $extId no perfil $($profile.Name) do usuário $($user.Name)"
                        }
                    }
                }
            }
        }
    }
}

# Exportar para arquivo no caminho de rede
$arquivo = "\\pasta-compartilha\Extensoes\$($env:COMPUTERNAME).txt"
$saida | Out-File -FilePath $arquivo -Encoding UTF8

Write-Output "Relatório salvo em: $arquivo"
