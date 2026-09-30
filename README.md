# chrome-extension-auditor

Solução em PowerShell para inventário centralizado das extensões instaladas no Google Chrome em estações Windows pertencentes a um domínio Active Directory.

O projeto utiliza PowerShell · Active Directory · GPO · JSON · HTML/CSS/JS

🎯 Auditar extensões instaladas manualmente em centenas de máquinas é inviável. Extensões não autorizadas representam risco real de segurança (roubo de dados,injeção de scripts, cryptojacking).
Antes de bloquear as extensões via GPO com ADM/ADMX é importante o que tem de extensão nos ativos, pode ter alguma importante.

Coleta via GPO → consolidação central → dashboard HTML interativo.

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

##Fluxo de funcionamento

Coleta
Uma GPO executa o script de coleta durante o logon do usuário.
O script percorre os perfis existentes em: C:\Users<usuario>\AppData\Local\Google\Chrome\User Data

e identifica os diretórios de extensões. Para cada extensão são coletadas informações como:

Computer
User
Profile
Extension ID
Version
ScanDate

2. Armazenamento

Cada estação gera seu próprio arquivo JSON em um compartilhamento de rede.

Exemplo:

\fileserver\Extensoes\PC-001.json
\fileserver\Extensoes\PC-002.json

3. Consolidação

O script de consolidação lê os inventários individuais e gera:

dados_consolidados.json 
relatorio_completo.csv 
consolidacao_log.txt

Também apresenta estatísticas da coleta, como:

Máquinas processadas
Usuários encontrados
Extensões únicas
Total de registros
Arquivos processados
Arquivos com erro

4. Dashboard

Os dados consolidados são utilizados para gerar um dashboard HTML contendo:

Total de máquinas
Total de usuários
Total de extensões
Total de instalações
Pesquisa por computador
Pesquisa por usuário
Pesquisa por extensão
Ranking das extensões mais encontradas

Possíveis evoluções

Algumas melhorias que podem ser implementadas futuramente:

Suporte a Microsoft Edge e Firefox
Execução periódica via Task Scheduler
Integração com SIEM

Exemplo da Saida HTML:

<img width="1447" height="919" alt="image" src="https://github.com/user-attachments/assets/6a3a27a3-bba9-4730-896c-829228230f31" />

