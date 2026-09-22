# chrome-extension-auditor

Solução em PowerShell para inventário centralizado das extensões instaladas no Google Chrome em estações Windows pertencentes a um domínio Active Directory.

O projeto utiliza PowerShell · Active Directory · GPO · JSON · HTML/CSS/JS

🎯 Auditar extensões instaladas manualmente em centenas de máquinas é inviável.
Extensões não autorizadas representam risco real de segurança (roubo de dados,
injeção de scripts, cryptojacking).

## Principais recursos
Coleta automática das extensões do Chrome
Suporte a múltiplos usuários e perfis do Chrome
Identificação da extensão pelo nome, ID e versão
Registro do computador e usuário
Armazenamento individual em JSON
Consolidação centralizada dos inventários
Exportação para CSV
Geração de logs
Ranking das extensões mais encontradas
Identificação de extensões presentes em apenas uma estação
Dashboard HTML com pesquisa
