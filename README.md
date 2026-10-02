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