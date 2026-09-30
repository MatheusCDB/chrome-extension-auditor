<#
.SYNOPSIS
    Auditoria completa de extensões do Chrome
.DESCRIPTION
    Consolida os JSONs das estações, gera relatório CSV, log,
    dashboard HTML e abre no navegador. Tudo em um único script.
.EXAMPLE
    .\Auditoria-Extensoes.ps1
    .\Auditoria-Extensoes.ps1 -PastaExtensoes "D:\Teste"
#>
param(
    [string]$PastaExtensoes = "\\fileserver.dominio.local\Extensoes",
    [switch]$NaoAbrirNavegador
)

# ===== CONFIGURAÇÕES =====
$arquivoConsolidado = Join-Path $PastaExtensoes "dados_consolidados.json"
$arquivoCSV         = Join-Path $PastaExtensoes "relatorio_completo.csv"
$arquivoLog         = Join-Path $PastaExtensoes "consolidacao_log.txt"
$arquivoHtmlSaida   = Join-Path $PastaExtensoes "Relatorio_Extensoes.html"
$templateHtml       = Join-Path $PastaExtensoes "template_dashboard.html"
$dataAtual          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ===== HELPERS DE LOG =====
function Write-Log {
    param([string]$Mensagem, [string]$Cor = "White", [switch]$SomenteLog)
    if (-not $SomenteLog) { Write-Host $Mensagem -ForegroundColor $Cor }
    $Mensagem | Out-File -FilePath $arquivoLog -Append -Encoding UTF8
}

# ===== CABEÇALHO =====
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AUDITORIA DE EXTENSÕES DO CHROME" -ForegroundColor Cyan
Write-Host "Data: $dataAtual" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

"=== AUDITORIA INICIADA EM $dataAtual ===" | Out-File -FilePath $arquivoLog -Encoding UTF8

# ===== FASE 1: CONSOLIDAÇÃO =====
Write-Host "[FASE 1/2] Consolidando arquivos JSON..." -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path $PastaExtensoes)) {
    Write-Log "ERRO: Pasta não encontrada: $PastaExtensoes" "Red"
    exit 1
}

$arquivos = Get-ChildItem -Path $PastaExtensoes -Filter "*.json" | Where-Object {
    $_.Name -notin @("dados_consolidados.json")
}

Write-Host "Encontrados $($arquivos.Count) arquivos JSON..." -ForegroundColor Yellow
Write-Log "Encontrados $($arquivos.Count) arquivos JSON" "White" -SomenteLog

if ($arquivos.Count -eq 0) {
    Write-Log "Nenhum arquivo JSON encontrado para consolidar!" "Red"
    exit 1
}

$dadosConsolidados    = [System.Collections.Generic.List[object]]::new()
$arquivosProcessados  = 0
$arquivosComErro      = 0
$totalRegistros       = 0

foreach ($arquivo in $arquivos) {
    Write-Host "  → $($arquivo.Name)..." -NoNewline

    try {
        $conteudo = Get-Content $arquivo.FullName -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($conteudo)) {
            Write-Host " ⚠️  VAZIO" -ForegroundColor Yellow
            Write-Log "ARQUIVO VAZIO: $($arquivo.Name)" "Yellow" -SomenteLog
            $arquivosComErro++
            continue
        }

        $jsonData = $conteudo | ConvertFrom-Json
        if ($jsonData -isnot [array]) { $jsonData = @($jsonData) }

        if ($jsonData.Count -eq 0) {
            Write-Host " ⚠️  SEM DADOS" -ForegroundColor Yellow
            Write-Log "SEM DADOS: $($arquivo.Name)" "Yellow" -SomenteLog
            $arquivosComErro++
            continue
        }

        $dadosConsolidados.AddRange($jsonData)
        $arquivosProcessados++
        $totalRegistros += $jsonData.Count

        Write-Host " ✅ $($jsonData.Count) registros" -ForegroundColor Green
        Write-Log "$($arquivo.Name) - $($jsonData.Count) registros" "White" -SomenteLog

    } catch {
        Write-Host " ❌ ERRO: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO em $($arquivo.Name): $($_.Exception.Message)" "Red" -SomenteLog
        $arquivosComErro++
    }
}

# ===== ESTATÍSTICAS =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RESULTADO DA CONSOLIDAÇÃO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Arquivos processados: $arquivosProcessados" -ForegroundColor Green
Write-Host "Arquivos com erro:    $arquivosComErro" -ForegroundColor Yellow
Write-Host "Total de registros:   $totalRegistros" -ForegroundColor Cyan

if ($totalRegistros -eq 0) {
    Write-Log "NENHUM DADO PARA CONSOLIDAR" "Red"
    exit 1
}

$maquinasUnicas   = ($dadosConsolidados | Group-Object Computer).Count
$usuariosUnicos   = ($dadosConsolidados | Group-Object User).Count
$extensoesUnicas  = ($dadosConsolidados | Group-Object ID).Count

Write-Host ""
Write-Host "Máquinas únicas:  $maquinasUnicas" -ForegroundColor Green
Write-Host "Usuários únicos:  $usuariosUnicos" -ForegroundColor Green
Write-Host "Extensões únicas: $extensoesUnicas" -ForegroundColor Green
Write-Host ""

# ===== SALVA ARQUIVOS =====
Write-Host "Salvando arquivos..." -ForegroundColor Yellow

$dadosConsolidados | ConvertTo-Json -Depth 3 | Out-File -FilePath $arquivoConsolidado -Encoding UTF8
Write-Host "  ✅ JSON: $arquivoConsolidado" -ForegroundColor Green

$dadosConsolidados | Export-Csv -Path $arquivoCSV -NoTypeInformation -Encoding UTF8
Write-Host "  ✅ CSV:  $arquivoCSV" -ForegroundColor Green

Write-Log "Total de registros: $totalRegistros"  "White" -SomenteLog
Write-Log "Máquinas únicas: $maquinasUnicas"     "White" -SomenteLog
Write-Log "Usuários únicos: $usuariosUnicos"    "White" -SomenteLog
Write-Log "Extensões únicas: $extensoesUnicas"  "White" -SomenteLog

# ===== TOP 10 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TOP 10 EXTENSÕES MAIS INSTALADAS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$topExtensoes = $dadosConsolidados | Group-Object Extension |
                Sort-Object Count -Descending | Select-Object -First 10

$i = 1
foreach ($ext in $topExtensoes) {
    $porcentagem = [math]::Round(($ext.Count / $totalRegistros) * 100, 1)
    Write-Host "$i. $($ext.Name) - $($ext.Count) máquinas ($porcentagem%)" -ForegroundColor White
    $i++
}

# ===== EXTENSÕES ÚNICAS =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "EXTENSÕES ÚNICAS (Apenas 1 máquina)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$extensoesUnicasLista = $dadosConsolidados | Group-Object Extension | Where-Object { $_.Count -eq 1 }

if ($extensoesUnicasLista.Count -gt 0) {
    foreach ($ext in $extensoesUnicasLista) {
        $computador = ($dadosConsolidados | Where-Object { $_.Extension -eq $ext.Name } |
                      Select-Object -First 1).Computer
        Write-Host "⚠️  $($ext.Name) - $computador" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Nenhuma extensão única encontrada" -ForegroundColor Green
}

# ===== FASE 2: GERAR DASHBOARD HTML =====
Write-Host ""
Write-Host "[FASE 2/2] Gerando dashboard HTML..." -ForegroundColor Magenta
Write-Host ""

# Carrega template (arquivo externo ou fallback embutido)
$htmlTemplate = $null
if (Test-Path $templateHtml) {
    Write-Host "  ✅ Template encontrado: $templateHtml" -ForegroundColor Green
    $htmlTemplate = Get-Content $templateHtml -Raw -Encoding UTF8
} else {
    Write-Host "  ⚠️  Template não encontrado. Usando HTML embutido..." -ForegroundColor Yellow
    # ⬇️ COLE AQUI O CONTEÚDO DO TEMPLATE (o grande bloco HTML)
    # Deixe o placeholder: var dadosExtensoes = DADOS_AQUI;
    $htmlTemplate = @'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Chrome Extension Inventory</title>
    <link href="https://cdn.datatables.net/1.11.5/css/jquery.dataTables.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdn.datatables.net/1.11.5/js/jquery.dataTables.min.js"></script>
    <style>
        :root { --primary:#2563eb; --warning:#f59e0b; --bg:#f1f5f9; }
        body { font-family: -apple-system, 'Segoe UI', Roboto, sans-serif; background:var(--bg); padding:20px; }
        .container { max-width:1400px; margin:0 auto; }
        .header { background:linear-gradient(135deg,var(--primary),#1d4ed8); color:#fff; padding:30px; border-radius:16px; margin-bottom:30px; }
        .stat-card { background:#fff; padding:20px; border-radius:12px; display:inline-block; margin:5px; min-width:200px; }
        .stat-number { font-size:28px; font-weight:700; color:var(--primary); }
        table { width:100%; background:#fff; border-collapse:collapse; }
        th,td { padding:10px; text-align:left; border-bottom:1px solid #eee; }
        .ranking-item { padding:6px 0; border-bottom:1px solid #f1f5f9; }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>Chrome Extension Inventory</h1>
        <div>Atualizado em: <span id="dataAtualizacao"></span></div>
    </div>
    <div>
        <div class="stat-card"><div class="stat-number" id="statComputadores">0</div>Máquinas</div>
        <div class="stat-card"><div class="stat-number" id="statUsuarios">0</div>Usuários</div>
        <div class="stat-card"><div class="stat-number" id="statExtensoes">0</div>Extensões</div>
        <div class="stat-card"><div class="stat-number" id="statInstalacoes">0</div>Instalações</div>
    </div>
    <br>
    <input type="text" id="searchInput" placeholder="Pesquisar..." onkeyup="renderizarTabela()" style="padding:10px;width:300px;">
    <br><br>
    <table id="tabela">
        <thead><tr><th>Computador</th><th>Usuário</th><th>Perfil</th><th>Extensão</th><th>ID</th><th>Versão</th></tr></thead>
        <tbody id="tableBody"></tbody>
    </table>
    <h3>Top Extensões</h3>
    <div id="rankingMaisInstaladas"></div>
</div>
<script>
    var dadosExtensoes = DADOS_AQUI;

    function renderizarTabela() {
        const search = document.getElementById('searchInput').value.toLowerCase();
        const tbody = document.getElementById('tableBody');
        tbody.innerHTML = '';
        dadosExtensoes
            .filter(d => !search ||
                d.Computer.toLowerCase().includes(search) ||
                d.User.toLowerCase().includes(search) ||
                d.Extension.toLowerCase().includes(search))
            .forEach(d => {
                tbody.innerHTML += `<tr>
                    <td>${d.Computer}</td><td>${d.User}</td><td>${d.Profile}</td>
                    <td>${d.Extension}</td><td>${d.ID}</td><td>${d.Version || 'N/A'}</td>
                </tr>`;
            });
    }

    function renderizarRanking() {
        const contagem = {};
        dadosExtensoes.forEach(d => contagem[d.Extension] = (contagem[d.Extension]||0)+1);
        const sorted = Object.entries(contagem).sort((a,b)=>b[1]-a[1]).slice(0,15);
        document.getElementById('rankingMaisInstaladas').innerHTML =
            sorted.map(([n,c],i)=>`<div class="ranking-item">#${i+1} ${n} — ${c} máquinas</div>`).join('');
    }

    document.getElementById('statComputadores').textContent = new Set(dadosExtensoes.map(d=>d.Computer)).size;
    document.getElementById('statUsuarios').textContent    = new Set(dadosExtensoes.map(d=>d.User)).size;
    document.getElementById('statExtensoes').textContent   = new Set(dadosExtensoes.map(d=>d.ID)).size;
    document.getElementById('statInstalacoes').textContent = dadosExtensoes.length;
    document.getElementById('dataAtualizacao').textContent = new Date().toLocaleString('pt-BR');

    renderizarTabela();
    renderizarRanking();
</script>
</body>
</html>
'@
}

# Injeta os dados usando .Replace (seguro contra regex e $)
$jsonData  = $dadosConsolidados | ConvertTo-Json -Depth 3 -Compress
$htmlFinal = $htmlTemplate.Replace('DADOS_AQUI;', "$jsonData;")

try {
    $htmlFinal | Out-File -FilePath $arquivoHtmlSaida -Encoding UTF8
    Write-Host "  ✅ Dashboard: $arquivoHtmlSaida" -ForegroundColor Green
    Write-Host "  📊 Registros: $($dadosConsolidados.Count)" -ForegroundColor Cyan
} catch {
    Write-Log "ERRO ao salvar HTML: $($_.Exception.Message)" "Red"
    exit 1
}

# ===== FINALIZAÇÃO =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AUDITORIA CONCLUÍDA!" -ForegroundColor Green
Write-Host "Log: $arquivoLog" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

Write-Log "=== AUDITORIA CONCLUÍDA EM $dataAtual ===" "White" -SomenteLog
Write-Log "Arquivos processados: $arquivosProcessados" "White" -SomenteLog
Write-Log "Total de registros: $totalRegistros" "White" -SomenteLog

# Abre o navegador
if (-not $NaoAbrirNavegador) {
    Start-Process $arquivoHtmlSaida
}
