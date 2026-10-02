# Criação de usuário no AD

Script de criação no Active Directory adicionado. Ele puxará os dados de uma lista do sharepoint, realizará o tratamento de dados e, por fim, realizará a criação do usuário, juntamente de seus atributos e grupos padrões.


## Requisitos e Pré-requisitos

Antes de executar a automação ou o script, garanta que o ambiente atenda aos seguintes requisitos:

### Módulos PowerShell:

1. PnP.PowerShell — Manipulação e leitura das listas do SharePoint.

2. ActiveDirectory / RSAT-AD-PowerShell — Gerenciamento e criação de usuários no AD.

### Active Directory:

1. Permissão delegada para criação/edição de objetos nas Unidades Organizacionais (OUs).

2. Servidor de Execução: Servidor Domain Controller / Bastion com acesso ao AD local (ex: SRV-DC-PROD01). 


## Arquitetura do Fluxo

<p align="center">
[ Microsoft Forms ] <br>
↓ <br>
[ Power Automate ] ──► (Tratamento de dados, consulta em base de dados e alimentação da lista do sharepoint com todos os campos necessários no AD) <br>
↓ <br>
[ Lista SharePoint ] ──► Status: "Pendente" (O powershell executará apenas as linhas que conterem "Pendente" na coluna "Status") <br>
↓ <br>
[ Script PowerShell ] ──► (Executa `PnP` + `New-ADUser` + Trata os dados necessários, como senhas, datas e objetos) <br>
↓ <br> 
[ Active Directory ] ──► Após a criação do usuário no AD. O script atualiza o status da lista sharepoint para "Concluído" ou "Erro" <br>
</p>

## Como Funciona

### 1. Entrada de Dados (Microsoft Forms): 
O solicitante preenche as informações do novo integrante (Nome, Cargo, Departamento, Escritório, etc.).

### 2. Processamento (Power Automate):

Trata os dados de entrada (UPN, Primeiro e Último nome).

Consulta as tabelas auxiliares no SharePoint para mapear o caminho correto da OU (Path).

Adiciona o registro na lista do Sharepoint principal com o status Pendente.

### 3. Criação da Conta (PowerShell):

Conecta ao SharePoint via PnP.PowerShell e busca itens pendentes.

Valida duplicidade de e-mail/login no AD.

Trata os dados necessários conforme a necessidade e aceitação do Active Directory.

Cria a conta via New-ADUser, atribui grupos de segurança e senha temporária.

Atualiza o status na lista do SharePoint para Concluído ou Erro.