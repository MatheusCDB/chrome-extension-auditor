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
$arquivoJson = "\\pasta-compartilhada\Extensoes\$($env:COMPUTERNAME).json"
$jsonOutput | Out-File -FilePath $arquivoJson -Encoding UTF8

Write-Output "Inventário concluído. Arquivo salvo em: $arquivoJson"
Write-Output "Total de extensões encontradas: $($extensoesColetadas.Count)"
