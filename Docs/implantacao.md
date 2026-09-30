# 🚀 Guia de Implantação

Passo a passo completo para implantar a solução de auditoria de extensões
do Chrome em um domínio Active Directory.

O guia está dividido em 4 partes:

1. [Pré-requisitos](#1-pré-requisitos)
2. [Coleta nas estações (via GPO)](#2-coleta-nas-estações-via-gpo)
3. [Consolidação e geração do dashboard](#3-consolidação-e-geração-do-dashboard)
4. [Verificação e troubleshooting](#4-verificação-e-troubleshooting)

---

## 1. Pré-requisitos

Antes de começar, confirme que o ambiente atende aos requisitos abaixo.

### Ambiente

- ✅ Active Directory operacional
- ✅ GPOs funcionando corretamente no domínio
- ✅ PowerShell 5.1+ disponível nas estações
- ✅ Google Chrome instalado nas estações que serão auditadas
- ✅ Acesso administrativo ao **GPMC** (`gpmc.msc`) e ao controlador de domínio

### Permissões de rede

| Compartilhamento | Finalidade | Permissão mínima |
|---|---|---|
| `\\dominio.local\SYSVOL\dominio.local\scripts\extensoes` | Armazenar o `.bat` e o `.ps1` de coleta | **Leitura** para `Domain Computers` |
| `\\fileserver.dominio.local\Extensoes` | Receber os `.json` gerados pelas estações | **Leitura + Escrita** para `Domain Computers` |

> 💡 **Dica:** o compartilhamento `SYSVOL` já é replicado automaticamente pelo AD
> e é acessível por todas as máquinas do domínio por padrão. Use-o para os
> scripts. Já a pasta de saída dos JSONs precisa ser um compartilhamento
> **separado**, com permissão de escrita.

### Estrutura de pastas esperada

```
\\dominio.local\SYSVOL\dominio.local\scripts\extensoes\
├── Executar-ColetaExtensoes.bat
└── lista_extensoes_json.ps1

\\fileserver.dominio.local\Extensoes\
├── PC-001.json          ← gerado pelas estações
├── PC-002.json
├── ...
├── dados_consolidados.json     ← gerado pela consolidação
├── relatorio_completo.csv      ← gerado pela consolidação
├── consolidacao_log.txt        ← gerado pela consolidação
└── Relatorio_Extensoes.html    ← gerado pela consolidação
```

---

## 2. Coleta nas estações (via GPO)

A coleta é executada **no logon do usuário**. Vamos criar uma GPO que dispara
o `.bat`, que por sua vez chama o PowerShell de coleta.

### 2.1. Por que um `.bat` e não chamar o `.ps1` direto?

Em muitos ambientes corporativos, usuários comuns **não têm permissão** para
executar scripts PowerShell diretamente — seja por `ExecutionPolicy`,
AppLocker, WDAC ou políticas restritivas de scripts.

O `.bat` atua como **wrapper**: ele é executado pela GPO e invoca o
PowerShell com `-ExecutionPolicy Bypass -NoProfile`, garantindo que a
coleta funcione sem exigir privilégios administrativos do usuário logado.

### 2.2. Copiar os scripts para o SYSVOL

Copie os dois arquivos para o compartilhamento de scripts do domínio:

```
\\dominio.local\SYSVOL\dominio.local\scripts\extensoes\
├── Executar-ColetaExtensoes.bat
└── lista_extensoes_json.ps1
```

Certifique-se de que o grupo `Domain Computers` tem permissão de **Leitura**
nessa pasta.

### 2.3. Conteúdo do `Executar-ColetaExtensoes.bat`

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\dominio.local\SYSVOL\dominio.local\scripts\extensoes\lista_extensoes_json.ps1" >> C:\Temp\PowerShellLog.txt 2>&1
```

**O que cada parâmetro faz:**

| Parâmetro | Função |
|---|---|
| `-NoProfile` | Não carrega o perfil do usuário (evita scripts indesejados no logon) |
| `-ExecutionPolicy Bypass` | Contorna a política de execução local |
| `-File` | Caminho UNC do script de coleta |
| `>> C:\Temp\PowerShellLog.txt 2>&1` | Redireciona stdout e stderr para log local (útil para debug) |

> ⚠️ **Atenção:** garanta que `C:\Temp` exista nas estações, ou o redirecionamento
> vai falhar silenciosamente. Se preferir, remova o redirecionamento ou aponte
> para `%TEMP%`.

### 2.4. Criar a GPO

1. No controlador de domínio, abra o **GPMC**:
   ```
   gpmc.msc
   ```

2. Navegue até a **OU** onde estão os computadores que serão auditados:
   ```
   Forest → Domains → dominio.local → <Sua_OU>
   ```

3. Clique com o botão direito na OU → **"Create a GPO in this domain, and Link it here..."**

4. Nomeie a GPO, por exemplo:
   ```
   GPO - Auditoria de Extensoes do Chrome
   ```

5. Clique com o botão direito na GPO → **Edit...** para abrir o editor.

### 2.5. Vincular o script à GPO

Como o script roda **no contexto do computador** (precisa ler todos os perfis
de `C:\Users`), use a seção de **Computer Configuration**:

1. Navegue até:
   ```
   Computer Configuration
     → Policies
       → Windows Settings
         → Scripts (Startup/Shutdown)
   ```

2. Dê duplo clique em **Startup**.

3. Na aba **Scripts**, clique em **Add...** → **Browse...**

4. Cole o caminho UNC do `.bat`:
   ```
   \\dominio.local\SYSVOL\dominio.local\scripts\extensoes\Executar-ColetaExtensoes.bat
   ```

5. Em **Script Parameters**, deixe em branco.

6. Clique em **OK** em todas as janelas.

> 💡 **Por que Startup e não Logon?**
>
> Scripts de **Startup** rodam como `SYSTEM` (ou `Computer Account`), o que
> garante acesso de leitura a **todos os perfis** em `C:\Users` — essencial
> para o script de coleta. Já scripts de **Logon** rodam no contexto do
> usuário e só enxergariam o próprio perfil.
>
> Se você precisar rodar no **logon** (por exemplo, porque o usuário fica
> logado por dias), o script funcionará mesmo assim, mas só conseguirá ler
> os perfis que o usuário tiver permissão.

### 2.6. Forçar aplicação da GPO

Nas estações (ou via `psexec`, ou remotamente):

```powershell
gpupdate /force
```

Ou reinicie as estações — a GPO de Startup só é aplicada no boot.

### 2.7. Validar a aplicação da GPO

Para confirmar que a GPO chegou na estação:

```powershell
gpresult /h C:\Temp\gpresult.html
```

Abra o HTML gerado e procure pela sua GPO em **"Computer Configuration"**.
Se aparecer, está aplicada.

Também verifique se o script foi executado:

```powershell
Get-Content C:\Temp\PowerShellLog.txt
```

---

## 3. Consolidação e geração do dashboard

Após os usuários logarem (ou as máquinas reiniciarem), o compartilhamento
`\\fileserver.dominio.local\Extensoes` deve estar cheio de arquivos
`NOME-DA-MAQUINA.json`.

Agora execute **manualmente** o script de consolidação a partir de uma
máquina (ou do próprio servidor).

### 3.1. Onde colocar o script

O script `Consolidar-Extensoes-html.ps1` deve ser salvo **no mesmo
compartilhamento onde estão os JSONs**:

```
\\fileserver.dominio.local\Extensoes\
├── Consolidar-Extensoes-html.ps1   ← aqui
├── PC-001.json
├── PC-002.json
└── ...
```

Isso é necessário porque o script usa o caminho da pasta para:

- Ler todos os `*.json`
- Salvar `dados_consolidados.json`, `relatorio_completo.csv`, `consolidacao_log.txt`
- Gerar `Relatorio_Extensoes.html`

### 3.2. Executar

Abra o PowerShell **como administrador** na máquina de onde vai rodar a
consolidação e execute:

```powershell
cd \\fileserver.dominio.local\Extensoes
.\Consolidar-Extensoes-html.ps1
```

Ou passando a pasta explicitamente:

```powershell
.\Consolidar-Extensoes-html.ps1 -PastaExtensoes "\\fileserver.dominio.local\Extensoes"
```

Se **não** quiser que o navegador abra automaticamente ao final:

```powershell
.\Consolidar-Extensoes-html.ps1 -PastaExtensoes "\\fileserver.dominio.local\Extensoes" -NaoAbrirNavegador
```

### 3.3. O que o script faz

1. Lê todos os `*.json` do compartilhamento
2. Valida arquivos vazios / corrompidos
3. Consolida todos os registros em memória
4. Salva:
   - `dados_consolidados.json` — base única consolidada
   - `relatorio_completo.csv` — para Excel / Power BI
   - `consolidacao_log.txt` — log detalhado da execução
5. Gera `Relatorio_Extensoes.html` com o dashboard interativo
6. Exibe no console estatísticas:
   - Arquivos processados / com erro
   - Total de registros
   - Máquinas únicas
   - Usuários únicos
   - Extensões únicas
   - Top 10 extensões mais instaladas
   - Extensões presentes em apenas 1 máquina ⚠️

### 3.4. Permissões do compartilhamento

O compartilhamento `\\fileserver.dominio.local\Extensoes` precisa:

| Grupo | Permissão |
|---|---|
| `Domain Computers` | **Leitura + Escrita** (para gravar os `.json` de coleta) |
| `Domain Admins` | **Controle Total** (para rodar a consolidação) |
| `Domain Users` | Leitura (opcional, se quiser que consultem os resultados) |

Sem essas permissões, a coleta falha silenciosamente no logon.

### 3.5. (Opcional) Agendar a consolidação

Se quiser rodar a consolidação periodicamente em vez de manualmente, use o
**Task Scheduler** no servidor de arquivos:

1. Abra **Task Scheduler** → **Create Task**
2. **General** → marque "Run whether user is logged on or not"
3. **Triggers** → New → Daily, por exemplo às 03:00
4. **Actions** → New → Start a program:
   ```
   Program:   powershell.exe
   Arguments: -NoProfile -ExecutionPolicy Bypass -File "\\fileserver.dominio.local\Extensoes\Consolidar-Extensoes-html.ps1" -NaoAbrirNavegador
   ```
5. **Conditions** → desmarque "Start the task only if the computer is on AC power"

---

## 4. Verificação e troubleshooting

### 4.1. Checklist rápido

Após a implantação, valide:

- [ ] A GPO aparece no `gpresult /h` das estações
- [ ] Arquivos `*.json` estão aparecendo em `\\fileserver.dominio.local\Extensoes`
- [ ] Cada JSON tem registros (`Get-Content PC-001.json | ConvertFrom-Json`)
- [ ] O script de consolidação roda sem erros
- [ ] O dashboard HTML abre no navegador
- [ ] A busca do dashboard retorna resultados

### 4.2. Problemas comuns

| Problema | Possível causa | Solução |
|---|---|---|
| Nenhum JSON é gerado | GPO não aplicada | Validar com `gpresult /h` |
| Arquivo JSON vazio | Chrome não instalado ou sem perfis | Verificar `C:\Users\<user>\AppData\Local\Google\Chrome\User Data` |
| Erro ao gravar JSON | Permissão no compartilhamento | Validar permissões NTFS e de Compartilhamento |
| Dashboard vazio | Consolidação não executada | Rodar `Consolidar-Extensoes-html.ps1` |
| HTML não abre | Template ausente ou erro de geração | Regenerar o dashboard |
| Script `.ps1` não executa | ExecutionPolicy bloqueando | Usar o `.bat` com `-ExecutionPolicy Bypass` |
| `C:\Temp\PowerShellLog.txt` não criado | Pasta `C:\Temp` não existe | Criar via GPO ou usar `%TEMP%` |
| Extensão aparece como `ERRO: ...` | `manifest.json` corrompido | Investigar a extensão específica manualmente |
| Extensão aparece como `__MSG_*__` | Tradução não encontrada em `_locales` | Normal — o script tenta `pt_BR` e depois `en` |

### 4.3. Logs úteis

| Arquivo | Onde | O que contém |
|---|---|---|
| `C:\Temp\PowerShellLog.txt` | Nas estações | Saída do script de coleta no logon |
| `consolidacao_log.txt` | No compartilhamento | Log detalhado da consolidação |
| `gpresult /h` | Nas estações | Confirmação de aplicação da GPO |

---

## 📌 Considerações finais

- A coleta ocorre **no boot** (Startup Script) ou **no logon** (Logon Script), dependendo de como você configurou a GPO.
- Cada computador gera **um único arquivo JSON** identificado pelo `COMPUTERNAME`.
- A consolidação pode ser executada **manualmente** ou via **Task Scheduler**.
- O dashboard é **estático** — precisa ser regenerado sempre que houver uma nova coleta.
- Para bloquear extensões depois da auditoria, use **ADMX/ADM** ou a **ExtensionInstallBlocklist** via registro/GPO.