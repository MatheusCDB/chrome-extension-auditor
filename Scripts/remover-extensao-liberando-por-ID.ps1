# IDs das extensões permitidas (whitelist)
$whitelist = @(
    "cfnpidifppmenkapgihekkeednfoenal" #bitdefender
    
)

$usersPath = "C:\Users"
$chromeUserDataRelative = "AppData\Local\Google\Chrome\User Data"

# Fecha o Chrome para evitar conflitos
Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue

foreach ($user in Get-ChildItem $usersPath -Directory) {
    $chromeBasePath = Join-Path $user.FullName $chromeUserDataRelative

    if (Test-Path $chromeBasePath) {
        $profileDirs = Get-ChildItem -Path $chromeBasePath -Directory | Where-Object {
            Test-Path "$($_.FullName)\Extensions"
        }

        foreach ($profile in $profileDirs) {
            $extensionsPath = Join-Path $profile.FullName "Extensions"

            if (Test-Path $extensionsPath) {
                $installedExtensions = Get-ChildItem -Path $extensionsPath -Directory

                foreach ($ext in $installedExtensions) {
                    if ($whitelist -notcontains $ext.Name) {
                        try {
                            Remove-Item -Recurse -Force -Path $ext.FullName
                            Write-Output "❌ Extensão $($ext.Name) REMOVIDA do perfil $($profile.Name) do usuário $($user.Name)"
                        } catch {
                            Write-Warning "⚠ Falha ao remover $($ext.Name) em $($profile.FullName): $_"
                        }
                    } else {
                        Write-Output "✔ Extensão $($ext.Name) PERMITIDA no perfil $($profile.Name) do usuário $($user.Name)"
                    }
                }
            }
        }
    }
}
