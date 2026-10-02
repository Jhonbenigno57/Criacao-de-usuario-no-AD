[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ==============================================================================
# CONFIGURAÇÕES DO SHAREPOINT & AD
# ==============================================================================
$siteUrl   = "https://SUAEMPRESA/sites/"
$nomeLista = "NOME DA LISTA SHAREPOINT"

# 1. Conexão ao SharePoint Online via PnP PowerShell
try {
    Write-Host "Conectando ao SharePoint Online..." -ForegroundColor Cyan
    Connect-PnPOnline -Url $siteUrl -UseWebLogin
    Write-Host "Conectado com sucesso!" -ForegroundColor Green
}
catch {
    Write-Error "FALHA CRITICA: Nao foi possivel conectar ao SharePoint: $_"
    Exit
}

# 2. Busca apenas itens pendentes na lista "Lista de base de dados"
$solicitacoes = Get-PnPListItem -List $nomeLista | Where-Object { 
    $_.FieldValues.Status -eq "Pendente" -or [string]::IsNullOrWhiteSpace($_.FieldValues.Status) 
}

if ($null -eq $solicitacoes -or $solicitacoes.Count -eq 0) {
    Write-Host "Nenhuma solicitacao pendente encontrada para processar." -ForegroundColor Yellow
    Disconnect-PnPOnline
    Exit
}

Write-Host "Encontradas $($solicitacoes.Count) solicitacoes pendentes." -ForegroundColor Cyan

# 3. Processamento de cada usuário
foreach ($item in $solicitacoes) {
    $u = $item.FieldValues
    $itemId = $item.Id

    # Validação da samAccountName
    if ([string]::IsNullOrWhiteSpace($u.samAccountName)) { 
        Write-Warning "Pulando Item ID ${itemId}: samAccountName esta em branco na lista."
        continue 
    }

    Write-Host "`nIniciando criacao do usuario: $($u.samAccountName)..." -ForegroundColor Cyan

    # Tratamento dinâmico dos extensionAttributes
    $atributosCustomizados = @{}
    
    if (-not [string]::IsNullOrWhiteSpace($u.proxyAddresses)) {
        $atributosCustomizados['proxyAddresses'] = @($u.proxyAddresses)
    }

    2..7 | ForEach-Object {
        $attrName = "extensionAttribute$_"
        if (-not [string]::IsNullOrWhiteSpace($u.$attrName)) {
            $atributosCustomizados[$attrName] = $u.$attrName
        }
    }

    # Formatação de data no extensionAttribute4 (dd/MM/yyyy)
    if ($atributosCustomizados.ContainsKey('extensionAttribute4')) {
        try {
            $atributosCustomizados['extensionAttribute4'] = ([datetime]$atributosCustomizados['extensionAttribute4']).ToString("dd/MM/yyyy")
        } catch {
            Write-Warning "Nao foi possivel formatar a data do extensionAttribute4."
        }
    }

    # Busca do DistinguishedName do Gestor (Manager) no AD
    $managerDN = $null
    if (-not [string]::IsNullOrWhiteSpace($u.Manager)) {
        try {
            $adManager = Get-ADUser -Filter "Name -eq '$($u.Manager)'" -ErrorAction Stop
            $managerDN = $adManager.DistinguishedName
        }
        catch {
            Write-Warning "Gestor '$($u.Manager)' nao encontrado no AD. Usuario sera criado sem gestor vinculado."
        }
    }

    # Validação de Senha
    if ([string]::IsNullOrWhiteSpace($u.Password)) {
        Write-Warning "Usuario $($u.samAccountName) sem senha informada. Alterando Status para 'Erro'..."
        Set-PnPListItem -List $nomeLista -Identity $itemId -Values @{"Status" = "Erro"}
        continue
    }
    $securePassword = ConvertTo-SecureString $u.Password -AsPlainText -Force

    try {
        # Montagem dos Parâmetros para criação no Active Directory
        $params = @{
            Name              = $u.Name
            DisplayName       = $u.NomeCompleto
            SamAccountName    = $u.samAccountName
            GivenName         = $u.GivenName
            Surname           = $u.Surname
            UserPrincipalName = $u.UserPrincipalName
            Path              = $u.Path
            Department        = $u.Department
            Title             = $u.Title
            Company           = $u.Company
            Description       = $u.Description
            Office            = $u.Office
            EmailAddress      = $u.Mail
            AccountPassword   = $SecurePassword
            Enabled           = $true
            ErrorAction       = 'Stop'
        }
        
        if ($null -ne $managerDN) {
            $params['Manager'] = $managerDN
        }

        if ($atributosCustomizados.Count -gt 0) {
            $params['OtherAttributes'] = $atributosCustomizados
        }

        # Criar Usuário no Active Directory
        New-ADUser @params
        Write-Host "Usuario $($u.samAccountName) criado com sucesso no AD!" -ForegroundColor Green

        # Adição aos Grupos do Active Directory
        if (-not [string]::IsNullOrWhiteSpace($u.Groups)) {
            $listaGrupos = $u.Groups -split ';'
            foreach ($grupo in $listaGrupos) {
                if ([string]::IsNullOrWhiteSpace($grupo)) { continue }
                $grupoLimpo = $grupo.Replace('"', '').Trim()
                
                if (-not [string]::IsNullOrWhiteSpace($grupoLimpo)) {
                    try {
                        Add-ADGroupMember -Identity $grupoLimpo -Members $u.samAccountName -ErrorAction Stop
                        Write-Host "   + Adicionado ao grupo: $grupoLimpo" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "   x Erro ao adicionar ao grupo '$grupoLimpo': $_"
                    }
                }
            }
        }

        # Atualiza a coluna Status na lista do SharePoint para "Concluído"
        Set-PnPListItem -List $nomeLista -Identity $itemId -Values @{"Status" = "Concluído"}
        Write-Host "Item ID $itemId na lista '$nomeLista' atualizado para 'Concluído'." -ForegroundColor Green

    }
    catch {
        Write-Error "Falha geral ao criar o usuario $($u.samAccountName): $_"
        Set-PnPListItem -List $nomeLista -Identity $itemId -Values @{"Status" = "Erro"}
    }
    Write-Host "--------------------------------------------------"
}

# Desconecta da sessão do SharePoint Online
Disconnect-PnPOnline
Write-Host "`nProcessamento finalizado!" -ForegroundColor Green