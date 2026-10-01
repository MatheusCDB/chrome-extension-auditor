# chrome-extension-auditor

> Solução em PowerShell para inventário centralizado das extensões instaladas
> no Google Chrome em estações Windows de um domínio Active Directory.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![AD](https://img.shields.io/badge/Active%20Directory-GPO-success)
![License](https://img.shields.io/badge/License-MIT-green)

**Stack:** PowerShell · Active Directory · GPO · JSON · HTML/CSS/JS

---

## O problema

Auditar extensões instaladas manualmente em centenas de máquinas é inviável.
Extensões não autorizadas representam risco real de segurança:

- Roubo de dados e sessões
- Injeção de scripts em páginas sensíveis
- Cryptojacking
- Bypass de políticas corporativas

Antes de bloquear extensões via GPO com **ADMX/ADM**, é essencial saber
**o que já existe** nos ativos pode haver extensões legítimas e críticas
para o negócio que seriam bloqueadas por engano.

## A solução

Um pipeline em 3 camadas:

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   COLETA     │ ──▶ │  CONSOLIDAÇÃO    │ ──▶ │   DASHBOARD     │
│  (estações)  │     │   (servidor)     │     │   (navegador)   │
└──────────────┘     └──────────────────┘     └─────────────────┘
   GPO + .bat            .ps1 único              HTML + JS
   gera JSON             gera JSON/CSV/log       busca em tempo real
   por máquina           + dashboard HTML        + rankings
```

**Coleta via GPO → consolidação central → dashboard HTML interativo.**

---

## Principais recursos

### Coleta
- ✅ Automática via GPO (boot/logon)
- ✅ Suporte a múltiplos usuários e perfis do Chrome
- ✅ Identificação por nome, ID e versão
- ✅ Tradução de nomes internacionalizados (`__MSG_*__`)
- ✅ Fallback para `_locales/pt_BR` → `_locales/en`
- ✅ Tratamento de erros sem interromper a varredura

### Consolidação
- ✅ Lê todos os JSONs do compartilhamento
- ✅ Valida arquivos vazios / corrompidos
- ✅ Gera `dados_consolidados.json`, `relatorio_completo.csv` e `consolidacao_log.txt`
- ✅ Estatísticas: máquinas, usuários, extensões únicas, arquivos processados/erro
- ✅ Top 10 extensões mais instaladas
- ✅ **Detecção de extensões presentes em apenas 1 estação** ⚠️

### Dashboard
- ✅ HTML estático, sem backend
- ✅ Pesquisa em tempo real (computador / usuário / extensão / ID)
- ✅ Ranking das extensões mais instaladas
- ✅ Exportação para CSV direto do navegador
- ✅ Geração automática ao final da consolidação

---

## Estrutura do repositório

| Caminho | Descrição |
|---|---|
| `Scripts/Executar-ColetaExtensoes.bat` | Wrapper chamado pela GPO para invocar o PowerShell |
| `Scripts/lista_extensoes_json.ps1` | Script de coleta executado nas estações |
| `Scripts/Consolidar-Extensoes-html.ps1` | Consolida os JSONs, gera CSV, log e dashboard HTML |
| `docs/implantacao.md` | **Guia completo de implantação** (GPO, permissões, execução) |

---

## 🚀 Como usar

### 📖 Guia completo

O passo a passo detalhado — criação da GPO, permissões de compartilhamento,
`gpupdate`, agendamento da consolidação e troubleshooting — está em:

 **[docs/implantacao.md](docs/implantacao.md)**

### Resumo em 3 passos

1. **Coleta** — publique os scripts no SYSVOL e crie uma GPO apontando para
   `Executar-ColetaExtensoes.bat` (Computer Configuration → Startup Scripts).
2. **Consolidação** — rode `Consolidar-Extensoes-html.ps1` no mesmo
   compartilhamento onde os JSONs foram gerados.
3. **Dashboard** — o `Relatorio_Extensoes.html` é gerado automaticamente
   e abre no navegador.

<details>
<summary>📋 Ver exemplo de execução da consolidação</summary>

```powershell
cd \\fileserver.dominio.local\Extensoes
.\Consolidar-Extensoes-html.ps1
```

Ou com caminho explícito (sem abrir o navegador — útil em Task Scheduler):

```powershell
.\Consolidar-Extensoes-html.ps1 `
    -PastaExtensoes "\\fileserver.dominio.local\Extensoes" `
    -NaoAbrirNavegador
```

**Saída gerada:**

```
dados_consolidados.json      → base única consolidada
relatorio_completo.csv       → para Excel / Power BI
consolidacao_log.txt         → log detalhado da execução
Relatorio_Extensoes.html     → dashboard interativo
```

</details>

---

## Por que um `.bat` e não chamar o `.ps1` direto?

Em muitos ambientes, usuários comuns **não têm permissão** para executar
scripts PowerShell diretamente — seja por `ExecutionPolicy`, AppLocker,
WDAC ou políticas restritivas.

O `.bat` atua como **wrapper**: é executado pela GPO e invoca o PowerShell
com `-ExecutionPolicy Bypass -NoProfile`, garantindo que a coleta funcione
sem exigir privilégios administrativos do usuário logado.

---

## Exemplo de saída e Pré-visualização do Dashboard

🔗 **[Clique aqui para explorar o dashboard interativo](https://htmlpreview.github.io/?https://github.com/MatheusCDB/FileServer-Permission-Auditor/blob/main/docs/Dashboard_Permissoes.html)**

![Dashboard do inventário de extensões](https://github.com/user-attachments/assets/6a3a27a3-bba9-4730-896c-829228230f31)

---

## Possíveis evoluções

- Suporte a **Microsoft Edge** e **Firefox**
- Execução periódica via **Task Scheduler** (já documentada em `docs/implantacao.md`)
- Integração com **SIEM** (envio de eventos para Splunk / Sentinel / Wazuh)
- Dashboard hospedado em **GitHub Pages** ou servidor interno
- Alertas automáticos para extensões novas / suspeitas

---

## 📄 Licença

Este projeto está sob a licença **MIT**. Veja o arquivo [LICENSE](LICENSE) para detalhes.
