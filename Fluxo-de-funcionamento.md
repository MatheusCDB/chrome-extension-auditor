##Fluxo de funcionamento
1. Coleta

Uma GPO executa o script de coleta durante o logon do usuário.

O script percorre os perfis existentes em:

C:\Users\<usuario>\AppData\Local\Google\Chrome\User Data

e identifica os diretórios de extensões.

Para cada extensão são coletadas informações como:

Computer
User
Profile
Extension
ID
Version
ScanDate
2. Armazenamento

Cada estação gera seu próprio arquivo JSON em um compartilhamento de rede.

Exemplo:

\\fileserver\Extensoes\PC-001.json
\\fileserver\Extensoes\PC-002.json
\\fileserver\Extensoes\PC-003.json
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
