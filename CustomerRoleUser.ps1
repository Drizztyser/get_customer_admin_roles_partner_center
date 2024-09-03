# Connexion au module Partner PowerShell & recuperation de la liste complete des tenants
try {
        $list_customer = Get-PartnerCustomer -ErrorAction Stop
    }
    catch {
        Connect-PartnerCenter
    }
    finally {
        $list_customer = Get-PartnerCustomer
    }

# Création d'une collection pour l'enregistrement des fichiers
$admin_role_collection = @()
$error_log_collection = @()
$index = @()

# Début de la récupération des roles Admin pour chaque utilisateur de chaque tenant
foreach($customer in $list_customer[6..8]) {

    # Obtenir l'index du tenant pour le nom d'enregistrement du fichier
    $index += $list_customer.indexof($customer) + 1

    # Affichage du tenant en cours d'analyse
    write-output ("`nVerification du tenant : {0} ({1}/{2}) ..." -f $customer.name, ($list_customer::indexof($list_customer,$customer)+1), $list_customer.Length)

    # Recuperation de la liste des utilisateurs du tenant
    try {
        $list_user = get-partnercustomeruser -customerid $customer.CustomerId -ErrorAction stop

        # Creation d'une Array pour conserver les Custom PSObject {tenant/user/role}
        $table_users = @()
        $table_error = @()

        # # Obtenir les droits des utilisateurs
        foreach ($user in $list_user) {
        
            # Obtenir les droits d'un utilisateur
            $role = (get-partnercustomeruserrole -CustomerId $customer.CustomerId -userid $user.userid | select -expandproperty name) -join ", "       
        
            # Custom PSObject {tenant/user/role}
            $psobject = new-object psobject -property @{
                CustomerID = $customer.CustomerId
                Customer = $customer.name
                user = $user.UserPrincipalName
                role = $role
            }      
        
            # Analyse des droits utilisateur & ajout dans l'Array Custom PSObject
            if($role -gt 1) {
                $newuser = [pscustomobject] @{CustomerID = $customer.CustomerId; CustomerName = $customer.name ; UserName = $user.DisplayName; UserPrincipalName = $user.UserPrincipalName; UserID = $user.UserId; Role = $role}
                $table_users += $newuser
            }
        }

        $table_users | ft
    }
    catch {
        $_.exception.message        
        $error_log_collection += @($customer.customerid, $customer.name, $_.exception.message,"`n")
    }

    $admin_role_collection += $table_users    
}

# SAuvegarde des fichiers
 
$fileName = Join-Path -Path (Get-Location) -ChildPath ("liste_admin_tenant{0}_{1}.csv" -f $index[0], $index[-1])
$admin_role_collection | Export-Csv -Path $fileName -Delimiter ";" -NoTypeInformation

$errorLogFileName = Join-Path -Path (Get-Location) -ChildPath ("error_admin_role_tenant{0}_{1}.txt" -f $index[0], $index[-1])
$error_log_collection | Out-file -FilePath $errorLogFileName