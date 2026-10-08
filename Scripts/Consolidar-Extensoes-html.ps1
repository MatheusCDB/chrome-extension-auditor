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
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chrome Extension Inventory</title>
    <link href="https://cdn.datatables.net/1.11.5/css/jquery.dataTables.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdn.datatables.net/1.11.5/js/jquery.dataTables.min.js"></script>
    <style>
        :root {
            --primary: #0f172a;
            --primary-light: #1e293b;
            --primary-lighter: #334155;
            --accent: #3b82f6;
            --accent-hover: #2563eb;
            --gray-50: #f8fafc;
            --gray-100: #f1f5f9;
            --gray-200: #e2e8f0;
            --gray-300: #cbd5e1;
            --gray-400: #94a3b8;
            --gray-500: #64748b;
            --gray-600: #475569;
            --gray-700: #334155;
            --gray-800: #1e293b;
            --gray-900: #0f172a;
            --warning: #f59e0b;
            --success: #10b981;
            --danger: #ef4444;
        }

        * { box-sizing: border-box; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--gray-100);
            padding: 0;
            margin: 0;
            color: var(--gray-800);
            line-height: 1.5;
        }

        .container {
            max-width: 1500px;
            margin: 0 auto;
            padding: 24px;
        }

        /* ===== HEADER ===== */
        .header {
            background: linear-gradient(135deg, var(--primary) 0%, var(--primary-light) 50%, var(--primary-lighter) 100%);
            color: #fff;
            padding: 40px 32px;
            border-radius: 16px;
            margin-bottom: 28px;
            box-shadow: 0 10px 25px -5px rgba(15, 23, 42, 0.3), 0 8px 10px -6px rgba(15, 23, 42, 0.2);
            position: relative;
            overflow: hidden;
        }

        .header::before {
            content: '';
            position: absolute;
            top: -50%;
            right: -10%;
            width: 400px;
            height: 400px;
            background: radial-gradient(circle, rgba(59, 130, 246, 0.15) 0%, transparent 70%);
            border-radius: 50%;
        }

        .header h1 {
            margin: 0 0 8px 0;
            font-size: 28px;
            font-weight: 700;
            letter-spacing: -0.5px;
            position: relative;
        }

        .header h1 i {
            margin-right: 12px;
            color: var(--accent);
        }

        .header .subtitle {
            font-size: 14px;
            color: var(--gray-300);
            position: relative;
        }

        .header .subtitle i {
            margin-right: 6px;
        }

        /* ===== STATS CARDS ===== */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 28px;
        }

        .stat-card {
            background: #fff;
            padding: 24px;
            border-radius: 14px;
            border: 1px solid var(--gray-200);
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.06);
            transition: all 0.2s ease;
            position: relative;
            overflow: hidden;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: var(--accent);
        }

        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(15, 23, 42, 0.1);
            border-color: var(--gray-300);
        }

        .stat-card .stat-icon {
            font-size: 20px;
            color: var(--accent);
            margin-bottom: 12px;
        }

        .stat-number {
            font-size: 32px;
            font-weight: 700;
            color: var(--primary);
            letter-spacing: -1px;
            line-height: 1;
            margin-bottom: 6px;
        }

        .stat-label {
            font-size: 13px;
            color: var(--gray-500);
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        /* ===== SEARCH ===== */
        .search-box {
            position: relative;
            margin-bottom: 20px;
        }

        .search-box i {
            position: absolute;
            left: 16px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--gray-400);
        }

        #searchInput {
            width: 100%;
            max-width: 420px;
            padding: 12px 16px 12px 44px;
            border: 1px solid var(--gray-300);
            border-radius: 10px;
            font-size: 14px;
            background: #fff;
            color: var(--gray-800);
            transition: all 0.2s ease;
            outline: none;
        }

        #searchInput:focus {
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
        }

        #searchInput::placeholder {
            color: var(--gray-400);
        }

        /* ===== TABLE ===== */
        .table-wrapper {
            background: #fff;
            border-radius: 14px;
            border: 1px solid var(--gray-200);
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.06);
            overflow: hidden;
            margin-bottom: 28px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        thead {
            background: var(--primary);
            color: #fff;
        }

        thead th {
            padding: 14px 16px;
            text-align: left;
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--gray-200);
            border-bottom: 2px solid var(--accent);
            white-space: nowrap;
        }

        tbody tr {
            border-bottom: 1px solid var(--gray-100);
            transition: background 0.15s ease;
        }

        tbody tr:hover {
            background: var(--gray-50);
        }

        tbody tr:last-child {
            border-bottom: none;
        }

        tbody td {
            padding: 12px 16px;
            color: var(--gray-700);
            vertical-align: middle;
        }

        tbody td:first-child {
            font-weight: 600;
            color: var(--primary);
        }

        .ext-name {
            font-weight: 500;
            color: var(--gray-800);
        }

        .ext-id {
            font-family: 'Courier New', monospace;
            font-size: 11px;
            color: var(--gray-500);
            background: var(--gray-100);
            padding: 2px 6px;
            border-radius: 4px;
        }

        .version-badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            background: var(--gray-100);
            color: var(--gray-600);
        }

        /* ===== BOTÃO ANÁLISE ===== */
        .btn-analise {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            background: var(--accent);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.2s ease;
            white-space: nowrap;
        }

        .btn-analise:hover {
            background: var(--accent-hover);
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.35);
            color: #fff;
            text-decoration: none;
        }

        .btn-analise:active {
            transform: translateY(0);
        }

        .btn-analise i {
            font-size: 11px;
        }

        /* ===== RANKING ===== */
        .ranking-section {
            background: #fff;
            border-radius: 14px;
            border: 1px solid var(--gray-200);
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.06);
            padding: 24px;
        }

        .ranking-section h3 {
            margin: 0 0 20px 0;
            font-size: 18px;
            font-weight: 700;
            color: var(--primary);
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .ranking-section h3 i {
            color: var(--accent);
        }

        .ranking-item {
            display: flex;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid var(--gray-100);
            gap: 14px;
        }

        .ranking-item:last-child {
            border-bottom: none;
        }

        .ranking-position {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: var(--gray-100);
            color: var(--gray-600);
            font-weight: 700;
            font-size: 13px;
            flex-shrink: 0;
        }

        .ranking-item:nth-child(1) .ranking-position {
            background: linear-gradient(135deg, #fbbf24, #f59e0b);
            color: #fff;
        }

        .ranking-item:nth-child(2) .ranking-position {
            background: linear-gradient(135deg, #cbd5e1, #94a3b8);
            color: #fff;
        }

        .ranking-item:nth-child(3) .ranking-position {
            background: linear-gradient(135deg, #d97706, #b45309);
            color: #fff;
        }

        .ranking-name {
            flex: 1;
            font-weight: 500;
            color: var(--gray-700);
            font-size: 13px;
        }

        .ranking-count {
            font-size: 12px;
            color: var(--gray-500);
            background: var(--gray-100);
            padding: 4px 10px;
            border-radius: 12px;
            font-weight: 600;
            white-space: nowrap;
        }

        /* ===== DATATABLES OVERRIDES ===== */
        .dataTables_wrapper .dataTables_filter input {
            border: 1px solid var(--gray-300);
            border-radius: 8px;
            padding: 6px 10px;
        }

        .dataTables_wrapper .dataTables_length select {
            border: 1px solid var(--gray-300);
            border-radius: 8px;
            padding: 4px 8px;
        }

        /* ===== RESPONSIVE ===== */
        @media (max-width: 768px) {
            .container { padding: 12px; }
            .header { padding: 24px 20px; }
            .header h1 { font-size: 20px; }
            .stat-number { font-size: 24px; }
            #searchInput { max-width: 100%; }
            .table-wrapper { overflow-x: auto; }
        }
    </style>
</head>
<body>
<div class="container">
    <!-- HEADER -->
    <div class="header">
        <h1><i class="fas fa-puzzle-piece"></i>Chrome Extension Inventory</h1>
        <div class="subtitle">
            <i class="fas fa-clock"></i>Atualizado em: <span id="dataAtualizacao"></span>
        </div>
    </div>

    <!-- STATS -->
    <div class="stats-grid">
        <div class="stat-card">
            <div class="stat-icon"><i class="fas fa-desktop"></i></div>
            <div class="stat-number" id="statComputadores">0</div>
            <div class="stat-label">Máquinas</div>
        </div>
        <div class="stat-card">
            <div class="stat-icon"><i class="fas fa-users"></i></div>
            <div class="stat-number" id="statUsuarios">0</div>
            <div class="stat-label">Usuários</div>
        </div>
        <div class="stat-card">
            <div class="stat-icon"><i class="fas fa-puzzle-piece"></i></div>
            <div class="stat-number" id="statExtensoes">0</div>
            <div class="stat-label">Extensões</div>
        </div>
        <div class="stat-card">
            <div class="stat-icon"><i class="fas fa-download"></i></div>
            <div class="stat-number" id="statInstalacoes">0</div>
            <div class="stat-label">Instalações</div>
        </div>
    </div>

    <!-- SEARCH -->
    <div class="search-box">
        <i class="fas fa-search"></i>
        <input type="text" id="searchInput" placeholder="Pesquisar por computador, usuário ou extensão..." onkeyup="renderizarTabela()">
    </div>

    <!-- TABLE -->
    <div class="table-wrapper">
        <table id="tabela">
            <thead>
                <tr>
                    <th>Computador</th>
                    <th>Usuário</th>
                    <th>Perfil</th>
                    <th>Extensão</th>
                    <th>ID</th>
                    <th>Versão</th>
                    <th>Análise</th>
                </tr>
            </thead>
            <tbody id="tableBody"></tbody>
        </table>
    </div>

    <!-- RANKING -->
    <div class="ranking-section">
        <h3><i class="fas fa-trophy"></i>Top 15 Extensões Mais Instaladas</h3>
        <div id="rankingMaisInstaladas"></div>
    </div>
</div>

<script>
    var dadosExtensoes = DADOS_AQUI;

    // ===== FUNÇÃO AUXILIAR: ESCAPE HTML =====
    function escapeHtml(text) {
        if (text === null || text === undefined) return '';
        const div = document.createElement('div');
        div.textContent = String(text);
        return div.innerHTML;
    }

    // ===== RENDERIZAR TABELA =====
    function renderizarTabela() {
        const search = document.getElementById('searchInput').value.toLowerCase().trim();
        const tbody = document.getElementById('tableBody');
        tbody.innerHTML = '';

        const filtrados = dadosExtensoes.filter(d => {
            if (!search) return true;
            return (d.Computer && d.Computer.toLowerCase().includes(search)) ||
                   (d.User && d.User.toLowerCase().includes(search)) ||
                   (d.Extension && d.Extension.toLowerCase().includes(search)) ||
                   (d.ID && d.ID.toLowerCase().includes(search));
        });

        if (filtrados.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:40px;color:#94a3b8;">Nenhum resultado encontrado</td></tr>';
            return;
        }

        // Limita a 500 linhas para performance
        const limite = filtrados.slice(0, 500);
        let html = '';

        limite.forEach(d => {
            const id = escapeHtml(d.ID || '');
            const linkAnalise = id ? `https://extensionshield.com/scan/results/${encodeURIComponent(id)}` : '#';

            html += `<tr>
                <td>${escapeHtml(d.Computer)}</td>
                <td>${escapeHtml(d.User)}</td>
                <td>${escapeHtml(d.Profile)}</td>
                <td><span class="ext-name">${escapeHtml(d.Extension)}</span></td>
                <td><span class="ext-id">${id || 'N/A'}</span></td>
                <td>${d.Version ? `<span class="version-badge">${escapeHtml(d.Version)}</span>` : '<span style="color:#94a3b8;">N/A</span>'}</td>
                <td>
                    ${id
                        ? `<a href="${linkAnalise}" target="_blank" rel="noopener noreferrer" class="btn-analise" title="Analisar no ExtensionShield">
                             <i class="fas fa-shield-alt"></i>Analisar
                           </a>`
                        : '<span style="color:#94a3b8;font-size:11px;">—</span>'}
                </td>
            </tr>`;
        });

        tbody.innerHTML = html;

        if (filtrados.length > 500) {
            tbody.innerHTML += `<tr><td colspan="7" style="text-align:center;padding:16px;color:#f59e0b;font-size:12px;font-weight:600;">
                ⚠️ Mostrando 500 de ${filtrados.length} resultados. Refine sua pesquisa para ver mais.
            </td></tr>`;
        }
    }

    // ===== RENDERIZAR RANKING =====
    function renderizarRanking() {
        const contagem = {};
        dadosExtensoes.forEach(d => {
            const nome = d.Extension || 'Desconhecida';
            contagem[nome] = (contagem[nome] || 0) + 1;
        });

        const sorted = Object.entries(contagem)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 15);

        const container = document.getElementById('rankingMaisInstaladas');

        if (sorted.length === 0) {
            container.innerHTML = '<div style="text-align:center;padding:20px;color:#94a3b8;">Sem dados</div>';
            return;
        }

        container.innerHTML = sorted.map(([nome, count], i) =>
            `<div class="ranking-item">
                <div class="ranking-position">${i + 1}</div>
                <div class="ranking-name">${escapeHtml(nome)}</div>
                <div class="ranking-count">${count} ${count === 1 ? 'máquina' : 'máquinas'}</div>
            </div>`
        ).join('');
    }

    // ===== ESTATÍSTICAS =====
    document.getElementById('statComputadores').textContent = new Set(dadosExtensoes.map(d => d.Computer).filter(Boolean)).size;
    document.getElementById('statUsuarios').textContent    = new Set(dadosExtensoes.map(d => d.User).filter(Boolean)).size;
    document.getElementById('statExtensoes').textContent   = new Set(dadosExtensoes.map(d => d.ID).filter(Boolean)).size;
    document.getElementById('statInstalacoes').textContent = dadosExtensoes.length;
    document.getElementById('dataAtualizacao').textContent = new Date().toLocaleString('pt-BR');

    // ===== INICIALIZAÇÃO =====
    renderizarTabela();
    renderizarRanking();
</script>
</body>
</html>
'@
