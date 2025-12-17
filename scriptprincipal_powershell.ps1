##################################################################
#                   SCRIPT PRINCIPAL POWERSHELL                  #
#                    Script_By: ANIS|FRED|EROS                   #
#                        WILD_CODE_SCHOOL                        # 
##################################################################

###############################################################
# CONFIGURATION & VARIABLES                                   #
###############################################################

# REPERTOIRE OU SE TROUVE LE SCRIPT PRINCIPAL
if ($PSScriptRoot) {
    $script_dir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $script_dir = Get-Location
}

# PORT SSH POUR LES CONNEXIONS AUX MACHINES
$port_ssh = "22222"

# BASE POUR SCANNER LE RESEAU 
$ip_reseau = "172.16.20."

# FICHIERS TEMPORAIRES POUR STOCKER LES RESULTATS DU SCAN RESEAU
$fichier_temp = "$env:TEMP\machines_actives_$PID.txt"
$fichier_noms = "$env:TEMP\noms_machines_$PID.txt"

# SCRIPT LINUX A COPIER SUR LA MACHINE DISTANTE LINUX
$script_linux = "$script_dir\scriptbash.sh"

# SCRIPT POWERSHELL A COPIER SUR LA MACHINE DISTANTE WINDOWS
$script_windows = "$script_dir\scriptpowershell.ps1"

# UTILISATEUR LINUX PAR DEFAUT
$utilisateur_linux = "wilder"

# UTILISATEURS WINDOWS A TESTER EN SSH
$utilisateurs_windows = @("wilder1", "wilder", "admin", "administrateur", "administrator", "user")

# AFFICHAGE DE LA DATE ET L'HEURE
$date_actuelle = Get-Date -Format "yyyy-MM-dd"
$heure_actuelle = Get-Date -Format "HH-mm-ss"

# IP LOCALE DE LA MACHINE MAITRE (POUR NE PAS L'AFFICHER DANS LA LISTE APRES SCAN)
$script:local_ip = ""

# TABLEAU LISTE DES IP TROUVEES
$script:liste_ip = @()
# TABLEAU QUI ASSOCIE L'IP AU NOM DE LA MACHINE
$script:noms_machines = @{}
# TABLEAU QUI ASSOCIE L'IP AU TYPE D'OS (LINUX/WINDOWS/INCONNU)
$script:type_os = @{}
# TABLEAU QUI ASSOCIE L'IP A L'UTILISATEUR WINDOWS TROUVE
$script:utilisateur_windows_trouve = @{}

##################################################################################
#                   CONFIGURATION DE LA JOURNALISATION                           #
##################################################################################

# DOSSIER ET FICHIER DE LOG
$script:log_dir = "C:\Windows\System32\LogFiles"
$script:log_file = "$script:log_dir\log_evt.log"

# DOSSIER POUR LES INFORMATIONS (A COTE DU SCRIPT)
$info_dir = "$script_dir\info"

##################################################################################
#                  FONCTIONS DE JOURNALISATION                                   #
##################################################################################
######################################################################
# FONCTION POUR INITIALISER LE FICHIER DE LOG ET LE DOSSIER INFO
function InitialiserJournal {
    # VERIFIE SI LE DOSSIER LOGS EXISTE
    if (-not (Test-Path $script:log_dir)) {
        try {
            New-Item -Path $script:log_dir -ItemType Directory -Force | Out-Null
            Write-Host "Dossier de log cree : $script:log_dir"
        } catch {
            #SI IMPOSSIBLE DE CREER DANS C:\LOGS, ON UTILISE LE DOSSIER DU SCRIPT
            Write-Host "Impossible de creer C:\Logs. Le log sera dans le dossier du script."
            $script:log_dir = $script_dir
            $script:log_file = "$script_dir\log_evt.log"
        }
    }
    
    # VERIFIE SI LE FICHIER LOG EXISTE
    if (-not (Test-Path $script:log_file)) {
        try {
            New-Item -Path $script:log_file -ItemType File -Force | Out-Null
        } catch {
            $script:log_file = "$script_dir\log_evt.log"
            New-Item -Path $script:log_file -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    # CREATION DU DOSSIER INFO S'IL N'EXISTE PAS
    if (-not (Test-Path $info_dir)) {
        New-Item -Path $info_dir -ItemType Directory -Force | Out-Null
    }
}
######################################################################
# FONCTION POUR SAUVEGARDER UN EVENEMENT DANS LE LOG. FORMAT : <Date>_<Heure>_<UtilisateurLocal>_<Evenement>
function SauvegarderLog {
    param([string]$Evenement)
    $date_evt = Get-Date -Format "yyyyMMdd"
    $heure_evt = Get-Date -Format "HHmmss"
    $utilisateur_evt = $env:USERNAME
    $ligne = "${date_evt}_${heure_evt}_${utilisateur_evt}_${Evenement}"
    Add-Content -Path $script:log_file -Value $ligne -ErrorAction SilentlyContinue
}
######################################################################
# FONCTION POUR RECUPERER LES FICHIERS INFO ET LOG DEPUIS UNE MACHINE LINUX
function RecupererInfoLinux {
    param(
        [string]$ip,
        [string]$utilisateur
    )
    # RECUPERATION DES LOGS ET AJOUT AU FICHIER LOG CENTRAL
    $testLog = ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "test -f /tmp/log_evt.log && echo OK" 2>$null
    if ($testLog -match "OK") {
        scp -P $port_ssh -q -o StrictHostKeyChecking=no "${utilisateur}@${ip}:/tmp/log_evt.log" "$env:TEMP\log_client_$PID.log" 2>$null
        if (Test-Path "$env:TEMP\log_client_$PID.log") {
            Get-Content "$env:TEMP\log_client_$PID.log" | Add-Content -Path $script:log_file -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\log_client_$PID.log" -Force -ErrorAction SilentlyContinue
        }
        ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "rm -f /tmp/log_evt.log" 2>$null
    }
    
    # RECUPERATION DES FICHIERS INFO
    $testInfo = ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "test -d /tmp/info && echo OK" 2>$null
    if ($testInfo -match "OK") {
        scp -P $port_ssh -q -r -o StrictHostKeyChecking=no "${utilisateur}@${ip}:/tmp/info/*" "$info_dir/" 2>$null
        ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "rm -rf /tmp/info" 2>$null
    }
}
######################################################################
# FONCTION POUR RECUPERER LES FICHIERS INFO ET LOG DEPUIS UNE MACHINE WINDOWS
function RecupererInfoWindows {
    param(
        [string]$ip,
        [string]$utilisateur
    )
    
    # RECUPERATION DES LOGS ET AJOUT AU FICHIER LOG CENTRAL
    $testLog = ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "cmd /c if exist %userprofile%\Documents\log_evt.log echo OK" 2>$null
    if ($testLog -match "OK") {
        scp -P $port_ssh -q -o StrictHostKeyChecking=no "${utilisateur}@${ip}:Documents/log_evt.log" "$env:TEMP\log_client_$PID.log" 2>$null
        if (Test-Path "$env:TEMP\log_client_$PID.log") {
            Get-Content "$env:TEMP\log_client_$PID.log" | Add-Content -Path $script:log_file -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\log_client_$PID.log" -Force -ErrorAction SilentlyContinue
        }
        ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "cmd /c del /F /Q %userprofile%\Documents\log_evt.log" 2>$null
    }

    # RECUPERATION DES FICHIERS INFO
    $testInfo = ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "cmd /c if exist %userprofile%\Documents\info echo OK" 2>$null
    if ($testInfo -match "OK") {
        scp -P $port_ssh -q -r -o StrictHostKeyChecking=no "${utilisateur}@${ip}:Documents/info/*" "$info_dir/" 2>$null
        ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "cmd /c rmdir /S /Q %userprofile%\Documents\info" 2>$null
    }
}
#####################################################################################
# FONCTIONS POUR DETECTER LES UTILISATEURS WINDOWS/LE SYSTEME /LE NOM DE MACHINE    #
#####################################################################################
######################################################################
# FONCTION POUR TROUVER L'UTILISATEUR WINDOWS VALIDE EN SSH
function TrouverUtilisateurWindows {
    param([string]$ip)
    # ON PARCOURT LA LISTE DES UTILISATEURS A TESTER
    foreach ($utilisateur in $utilisateurs_windows) {
        # ON TENTE UNE CONNEXION SSH RAPIDE SUR WINDOWS AVEC L'UTILISATEUR COURANT
        # SI LA COMMANDE "cmd /c echo Windows" RENVOIE "WINDOWS", L'UTILISATEUR EST VALIDE
        $result = ssh -p $port_ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes "${utilisateur}@${ip}" "cmd /c echo Windows" 2>$null
        if ($result -match "Windows") {
            # ON A TROUVE UN UTILISATEUR VALIDE POUR CETTE MACHINE
            return $utilisateur
        }
    }
    
    # SI AUCUN UTILISATEUR NE FONCTIONNE, ON RENVOIE UNE CHAINE VIDE
    return ""
}
######################################################################
# FONCTION POUR DETECTER LE SYSTEME D'EXPLOITATION DE LA MACHINE DISTANTE
# DETERMINER SI UNE IP CORRESPOND A UNE MACHINE LINUX / WINDOWS / INCONNU
function DetecterSysteme {
    param([string]$ip)
    # ON TESTE D'ABORD LINUX AVEC LA COMMANDE "UNAME" EN SSH
    $result_linux = ssh -p $port_ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes "${utilisateur_linux}@${ip}" "uname" 2>$null
    if ($result_linux -match "Linux") {
        $script:type_os[$ip] = "linux"
        return
    }

    # SI CE N'EST PAS LINUX, ON TESTE WINDOWS EN CHERCHANT UN UTILISATEUR VALIDE
    $utilisateur_win = TrouverUtilisateurWindows -ip $ip
    if ($utilisateur_win -ne "") {
        $script:type_os[$ip] = "windows"
        $script:utilisateur_windows_trouve[$ip] = $utilisateur_win
        return
    }
    
    # SI AUCUN SYSTEME N'A PU ETRE DETECTE, ON CLASSE LA MACHINE EN "INCONNU"
    $script:type_os[$ip] = "inconnu"
}
######################################################################
# FONCTION POUR RECUPERER LE NOM (HOSTNAME) DE LA MACHINE DISTANTE
function RecupererNomMachine {
    param([string]$ip)
    $nom = ""
    $utilisateur = ""
    # SI LE TYPE D'OS N'EST PAS ENCORE CONNU, ON ESSAIE DE LE DETECTER
    if ($script:type_os[$ip] -eq $null -or $script:type_os[$ip] -eq "") {
        DetecterSysteme -ip $ip
    }
    # ON CHOISIT L'UTILISATEUR SELON LE TYPE D'OS
    if ($script:type_os[$ip] -eq "windows") {
        $utilisateur = $script:utilisateur_windows_trouve[$ip]
        # SI AUCUN UTILISATEUR N'EST EN MEMOIRE, ON LE RECHERCHE
        if ($utilisateur -eq $null -or $utilisateur -eq "") {
            $utilisateur = TrouverUtilisateurWindows -ip $ip
            $script:utilisateur_windows_trouve[$ip] = $utilisateur
        }
    } else {
        $utilisateur = $utilisateur_linux
    }
    
    # ON LANCE LA COMMANDE HOSTNAME A DISTANCE VIA SSH (ON CACHE LES ERREURS)
    $nom = ssh -p $port_ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no "${utilisateur}@${ip}" "hostname" 2>$null
    
    # SI LA COMMANDE A REUSSI ET QUE LE NOM N'EST PAS VIDE
    if ($LASTEXITCODE -eq 0 -and $nom -ne $null -and $nom -ne "") {
        # ON SUPPRIME LES RETOURS CHARIOT EVENTUELS (PLATEFORME WINDOWS)
        $script:noms_machines[$ip] = $nom -replace "`r", "" -replace "`n", ""
    } else {
        # SI ON N'ARRIVE PAS A RECUPERER LE NOM, ON AFFICHE "?"
        $script:noms_machines[$ip] = "?"
    }
}
##################################################################################
#                   FONCTION POUR SCANNER LE RESEAU                              #
##################################################################################
######################################################################
# ON PING DE 5 A 30 POUR DETECTER DES MACHINES ACTIVES OS & NOM
function ScannerReseau {
    # ON REINITIALISE LES TABLEAUX EN MEMOIRE
    $script:liste_ip = @()
    $script:noms_machines = @{}
    $script:type_os = @{}
    $script:utilisateur_windows_trouve = @{}
    
    # ON VIDE LES FICHIERS TEMPORAIRES
    if (Test-Path $fichier_temp) { Remove-Item $fichier_temp -Force }
    if (Test-Path $fichier_noms) { Remove-Item $fichier_noms -Force }
    New-Item -Path $fichier_temp -ItemType File -Force | Out-Null
    New-Item -Path $fichier_noms -ItemType File -Force | Out-Null
    Write-Host "SCAN DU RESEAU EN COURS..."
    
    # ON LANCE TOUS LES PINGS EN PARALLELE
    $jobs = @()
    for ($i = 5; $i -le 30; $i++) {
        $ip = "${ip_reseau}${i}"
        $jobs += Start-Process -FilePath "cmd.exe" -ArgumentList "/c ping -n 1 -w 500 $ip >nul 2>&1 && echo $ip >> `"$fichier_temp`"" -WindowStyle Hidden -PassThru
    }
    
    # ON ATTEND QUE TOUS LES PINGS SE TERMINENT (MAX 15 SECONDES)
    $timeout = 15
    $start = Get-Date
    while (($jobs | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if (((Get-Date) - $start).TotalSeconds -gt $timeout) {
            $jobs | Where-Object { -not $_.HasExited } | ForEach-Object { 
                try { $_.Kill() } catch {} 
            }
            break
        }
        Start-Sleep -Milliseconds 200
    }
    
    # SI LE FICHIER DES IP ACTIVES N'EST PAS VIDE
    if ((Test-Path $fichier_temp) -and (Get-Item $fichier_temp).Length -gt 0) {
        # ON CHARGE LA LISTE DES IP ACTIVES
        $ips_brutes = Get-Content $fichier_temp -ErrorAction SilentlyContinue
        # ON DETERMINE L'IP LOCALE POUR NE PAS L'AFFICHER DANS LE MENU
        if ($script:local_ip -eq "") {
            $interfaces = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "${ip_reseau}*" }
            if ($interfaces) {
                $script:local_ip = $interfaces[0].IPAddress
            }
        }
        
        # ON FILTRE L'IP LOCALE ET ON NETTOIE
        $liste_filtree = @()
        foreach ($ip in $ips_brutes) {
            $ip_clean = $ip.Trim()
            if ($ip_clean -ne "" -and $ip_clean -ne $script:local_ip) {
                $liste_filtree += $ip_clean
            }
        }
        
        #SI FILTRAGE EFFECTUE ET AUCUNE IP, ON SUPPRIME ET ON SORT
        if ($liste_filtree.Count -eq 0) {
            Remove-Item $fichier_temp -Force -ErrorAction SilentlyContinue
            Remove-Item $fichier_noms -Force -ErrorAction SilentlyContinue
            return
        }
        
        # ON DETECTE LE SYSTEME D'EXPLOITATION + NOM DE MACHINE POUR CHAQUE IP
        foreach ($ip in $liste_filtree) {
            DetecterSysteme -ip $ip
            RecupererNomMachine -ip $ip
            #ON ENREGISTRE TOUTES LES INFOS [IP:OS:NOM:UTILISATEUR_WINDOWS] DANS LE FICHIER
            $ligne = "$ip`:$($script:type_os[$ip])`:$($script:noms_machines[$ip])`:$($script:utilisateur_windows_trouve[$ip])"
            Add-Content -Path $fichier_noms -Value $ligne -ErrorAction SilentlyContinue
        }
        
        # ON RECHARGE LES INFOS EN MEMOIRE DEPUIS LE FICHIER
        $contenu = Get-Content $fichier_noms -ErrorAction SilentlyContinue
        foreach ($ligne in $contenu) {
            $parts = $ligne -split ":"
            if ($parts.Count -ge 3) {
                $ip = $parts[0]
                $systeme = $parts[1]
                $nom = $parts[2]
                $utilisateur = if ($parts.Count -ge 4) { $parts[3] } else { "" }
                # ON AJOUTE TOUTES LES MACHINES (LINUX + WINDOWS) SAUF INCONNU
                if ($systeme -ne "inconnu") {
                    $script:liste_ip += $ip
                    $script:type_os[$ip] = $systeme
                    $script:noms_machines[$ip] = $nom
                    if ($utilisateur -ne "") {
                        $script:utilisateur_windows_trouve[$ip] = $utilisateur
                    }
                }
            }
        }
    }
    # ON SUPPRIME LES FICHIERS TEMPORAIRES
    Remove-Item $fichier_temp -Force -ErrorAction SilentlyContinue
    Remove-Item $fichier_noms -Force -ErrorAction SilentlyContinue
}
##################################################################################
#                      FONCTIONS DE CONNEXION AUX MACHINES                       #
##################################################################################
######################################################################
#FONCTION POUR SE CONNECTER A UNE MACHINE LINUX
function ConnexionMachineLinux {
    param([string]$ip)
    
    $nom_machine = $script:noms_machines[$ip]
    $utilisateur_local = $env:USERNAME
    
    # ON VERIFIE QUE LE SCRIPT CLIENT LINUX EXISTE SUR LA MACHINE PRINCIPALE
    if (-not (Test-Path $script_linux)) {
        Write-Host "Erreur : Script Linux introuvable ($script_linux)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Connexion a $ip *Linux*"
    # LOG DE LA CONNEXION
    SauvegarderLog "Action_ConnexionSSH_${nom_machine}_${ip}"
    # ON COPIE LE SCRIPT SUR LA MACHINE DISTANTE DANS LES FICHIERS TEMPORAIRES
    $scpArgs = @("-P", $port_ssh, "-o", "StrictHostKeyChecking=no", $script_linux, "${utilisateur_linux}@${ip}:/tmp/scriptbash.sh")
    & scp $scpArgs
    
    # SI LA COPIE ECHOUE, ON AFFICHE UNE ERREUR
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur : Echec de copie du script Linux (code: $LASTEXITCODE)" -ForegroundColor Red
        return $false
    }
    
    # ON REND LE SCRIPT EXECUTABLE PUIS ON L'EXECUTE AVEC L'UTILISATEUR LOCAL EN ARGUMENT, ENSUITE ON LE SUPPRIME
    $cible = "${utilisateur_linux}@${ip}"
    $commande = "sed -i 's/\r$//' /tmp/scriptbash.sh && chmod +x /tmp/scriptbash.sh && /tmp/scriptbash.sh '$utilisateur_local'; rm -f /tmp/scriptbash.sh"
    Start-Process -FilePath "ssh" -ArgumentList "-p", $port_ssh, "-t", $cible, "`"$commande`"" -NoNewWindow -Wait
    Clear-Host
    
    # RECUPERATION DES FICHIERS INFO ET LOG DEPUIS LA MACHINE DISTANTE
    RecupererInfoLinux -ip $ip -utilisateur $utilisateur_linux
    return $true
}
######################################################################
# FONCTION POUR SE CONNECTER A UNE MACHINE WINDOWS
function ConnexionMachineWindows {
    param([string]$ip)
    $utilisateur = $script:utilisateur_windows_trouve[$ip]
    $nom_machine = $script:noms_machines[$ip]
    $utilisateur_local = $env:USERNAME
    
    # SI AUCUN UTILISATEUR N'EST CONNU POUR CETTE IP ON ESSAIE D'EN TROUVER UN
    if ($utilisateur -eq $null -or $utilisateur -eq "") {
        Write-Host "Recherche de l'utilisateur Windows pour $ip"
        $utilisateur = TrouverUtilisateurWindows -ip $ip
        if ($utilisateur -eq "") {
            Write-Host "Erreur : Aucun utilisateur Windows ne fonctionne en SSH sur $ip" -ForegroundColor Red
            return $false
        }
        $script:utilisateur_windows_trouve[$ip] = $utilisateur
    }
    
    # ON VERIFIE QUE LE SCRIPT POWERSHELL EXISTE SUR LA MACHINE PRINCIPALE
    if (-not (Test-Path $script_windows)) {
        Write-Host "Erreur : Script Windows introuvable ($script_windows)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Connexion a $ip (Windows - Utilisateur : $utilisateur)"
    # LOG DE LA CONNEXION
    SauvegarderLog "Action_ConnexionSSH_${nom_machine}_${ip}"
    # NETTOYAGE DU SCRIPT SUR LA MACHINE DISTANTE S'IL EXISTAIT DEJA DANS DOCUMENTS
    $cible = "${utilisateur}@${ip}"
    & ssh -p $port_ssh -o BatchMode=yes $cible "cmd /c if exist %userprofile%\Documents\scriptpowershell.ps1 del /F /Q %userprofile%\Documents\scriptpowershell.ps1" 2>$null
    # COPIE DU SCRIPT POWERSHELL DANS LE DOSSIER DOCUMENTS DE L'UTILISATEUR
    $scpArgs = @("-P", $port_ssh, "-o", "StrictHostKeyChecking=no", $script_windows, "${utilisateur}@${ip}:Documents/scriptpowershell.ps1")
    & scp $scpArgs
    # SI LA COPIE ECHOUE ON AFFICHE UNE ERREUR
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur : Echec du transfert du script Windows" -ForegroundColor Red
        Write-Host "Verifiez les droits de l'utilisateur distant."
        return $false
    }
    
    # EXECUTION DU SCRIPT AVEC L'UTILISATEUR LOCAL EN ARGUMENT, PUIS SUPPRESSION DU FICHIER
    Start-Process -FilePath "ssh" -ArgumentList "-p", $port_ssh, "-t", "${utilisateur}@${ip}", "`"powershell -ExecutionPolicy Bypass -File %userprofile%\Documents\scriptpowershell.ps1 -UtilisateurLocal '$utilisateur_local'`"" -NoNewWindow -Wait
    # SUPPRESSION DU SCRIPT APRES EXECUTION
    & ssh -p $port_ssh -o BatchMode=yes "${utilisateur}@${ip}" "cmd /c del /F /Q %userprofile%\Documents\scriptpowershell.ps1" 2>$null
    # NETTOIE L'ECRAN APRES RETOUR
    Clear-Host
    # RECUPERATION DES FICHIERS INFO ET LOG DEPUIS LA MACHINE DISTANTE
    RecupererInfoWindows -ip $ip -utilisateur $utilisateur
    return $true
}
######################################################################
#FONCTION POUR SE CONNECTER A UNE MACHINE ET CHOISIR AUTOMATIQUEMENT LA BONNE FONCTION (LINUX / WINDOWS)
function ConnexionMachine {
    param([string]$ip)
    $systeme = $script:type_os[$ip]
    # SI LE SYSTEME N'EST PAS ENCORE CONNU ON TENTE DE LE DETECTER
    if ($systeme -eq $null -or $systeme -eq "") {
        DetecterSysteme -ip $ip
        $systeme = $script:type_os[$ip]
    }
    
    # ON APPELLE LA BONNE FONCTION SELON LE SYSTEME
    if ($systeme -eq "linux") {
        return ConnexionMachineLinux -ip $ip
    } elseif ($systeme -eq "windows") {
        return ConnexionMachineWindows -ip $ip
    } else {
        #ICI : SYSTEME NON RECONNU (NI LINUX NI WINDOWS) DONC ON NE QUITTE PAS LE SCRIPT CENTRAL : ON RENVOIE JUSTE UN CODE ERREUR
        return $false
    }
}
##################################################################################
#                              MENU PRINCIPAL                                    #
##################################################################################
######################################################################
function MenuPrincipal {
    # ON BOUCLE LE MENU PRINCIPAL
    while ($true) {
        Clear-Host
        # ON AFFICHE LA BANNIERE EN BLEU BLANC ROUGE
        Write-Host "####################" -NoNewline -ForegroundColor DarkBlue
        Write-Host "##############" -NoNewline -ForegroundColor White
        Write-Host "####################" -ForegroundColor DarkRed
        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
        Write-Host "                  SCRIPT_PRINCIPAL                  " -NoNewline -ForegroundColor White
        Write-Host "#" -ForegroundColor DarkRed
        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
        Write-Host "                $date_actuelle|$heure_actuelle                 " -NoNewline -ForegroundColor White
        Write-Host "#" -ForegroundColor DarkRed
        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
        Write-Host "                  WILD_CODE_SCHOOL                  " -NoNewline -ForegroundColor White
        Write-Host "#" -ForegroundColor DarkRed
        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
        Write-Host "              SCRIPT_BY:ANIS|FRED|EROS              " -NoNewline -ForegroundColor White
        Write-Host "#" -ForegroundColor DarkRed
        Write-Host "####################" -NoNewline -ForegroundColor DarkBlue
        Write-Host "##############" -NoNewline -ForegroundColor White
        Write-Host "####################" -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "1.SE CONNECTER A UNE MACHINE"
        Write-Host "Q.QUITTER"
        Write-Host "___________________________"
        Write-Host ""
        Write-Host "CHOISISSEZ UNE OPTION [1 OU Q]: " -NoNewline
        
        $cursorPos = $Host.UI.RawUI.CursorPosition
        Write-Host ""
        Write-Host ""
        Write-Host ""
        Write-Host ""        
        Write-Host " ██╗    ██╗██╗██╗     ██████╗      ██████╗ ██████╗ ██████╗ ███████╗" -ForegroundColor Magenta
        Write-Host " ██║    ██║██║██║     ██╔══██╗    ██╔════╝██╔═══██╗██╔══██╗██╔════╝" -ForegroundColor Magenta
        Write-Host " ██║ █╗ ██║██║██║     ██║  ██║    ██║     ██║   ██║██║  ██║█████╗  " -ForegroundColor Magenta
        Write-Host " ██║███╗██║██║██║     ██║  ██║    ██║     ██║   ██║██║  ██║██╔══╝  " -ForegroundColor Magenta
        Write-Host " ╚███╔███╔╝██║███████╗██████╔╝    ╚██████╗╚██████╔╝██████╔╝███████╗" -ForegroundColor Magenta
        Write-Host "  ╚══╝╚══╝ ╚═╝╚══════╝╚═════╝      ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝" -ForegroundColor Magenta
        Write-Host "                ███████╗ ██████╗██╗  ██╗ ██████╗  ██████╗ ██╗     " -ForegroundColor Magenta
        Write-Host "                ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔═══██╗██║     " -ForegroundColor Magenta
        Write-Host "                ███████╗██║     ███████║██║   ██║██║   ██║██║     " -ForegroundColor Magenta
        Write-Host "                ╚════██║██║     ██╔══██║██║   ██║██║   ██║██║     " -ForegroundColor Magenta
        Write-Host "                ███████║╚██████╗██║  ██║╚██████╔╝╚██████╔╝███████╗" -ForegroundColor Magenta
        Write-Host "                ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor Magenta
        Write-Host ""
        
        # ON REMET LE CURSEUR A COTE DE "CHOISISSEZ UNE OPTION"
        $Host.UI.RawUI.CursorPosition = $cursorPos
        $choix = Read-Host
        switch ($choix) {
            "1" {
                # LOG NAVIGATION
                SauvegarderLog "Navigation_MenuConnexion"
                # ON SCANNE LE RESEAU
                Write-Host ""
                ScannerReseau
                # SI AU MOINS UNE IP A ETE TROUVEE
                if ($script:liste_ip.Count -gt 0) {
                    # TANT QUE L'UTILISATEUR N'A PAS CHOISI UNE MACHINE VALIDE ON RESTE DANS LE MENU
                    while ($true) {
                        Clear-Host
                        # ON AFFICHE LA BANNIERE EN BLEU BLANC ROUGE
                        Write-Host "####################" -NoNewline -ForegroundColor DarkBlue
                        Write-Host "##############" -NoNewline -ForegroundColor White
                        Write-Host "####################" -ForegroundColor DarkRed
                        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
                        Write-Host "                  SCRIPT_PRINCIPAL                  " -NoNewline -ForegroundColor White
                        Write-Host "#" -ForegroundColor DarkRed
                        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
                        Write-Host "                $date_actuelle|$heure_actuelle                 " -NoNewline -ForegroundColor White
                        Write-Host "#" -ForegroundColor DarkRed
                        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
                        Write-Host "                  WILD_CODE_SCHOOL                  " -NoNewline -ForegroundColor White
                        Write-Host "#" -ForegroundColor DarkRed
                        Write-Host "#" -NoNewline -ForegroundColor DarkBlue
                        Write-Host "              SCRIPT_BY:ANIS|FRED|EROS              " -NoNewline -ForegroundColor White
                        Write-Host "#" -ForegroundColor DarkRed
                        Write-Host "####################" -NoNewline -ForegroundColor DarkBlue
                        Write-Host "##############" -NoNewline -ForegroundColor White
                        Write-Host "####################" -ForegroundColor DarkRed
                        Write-Host ""
                        Write-Host "MACHINES DISPONIBLES :"
                        Write-Host ""
                        
                        # AFFICHAGE DES MACHINES TROUVEES [NUMERO + IP + NOM]
                        for ($i = 0; $i -lt $script:liste_ip.Count; $i++) {
                            $ip = $script:liste_ip[$i]
                            $nom = $script:noms_machines[$ip]
                            Write-Host "  $($i+1).`t$ip`t$nom"
                        }
                        
                        Write-Host "  Q.QUITTER"
                        Write-Host ""
                        
                        # ON DEMANDE UNE SAISIE PAR EX [1-3 OU Q]
                        $max = $script:liste_ip.Count
                        if ($max -eq 1) {
                            $plage = "1"
                        } else {
                            $plage = "1-$max"
                        }
                        
                        # ON DEMANDE LE CHOIX DE LA MACHINE
                        Write-Host "CHOISISSEZ UNE OPTION [$plage OU Q]: " -NoNewline
                        
                        $cursorPos = $Host.UI.RawUI.CursorPosition                   
                        Write-Host ""
                        Write-Host ""
                        Write-Host ""
                        Write-Host ""
                        Write-Host " ██╗    ██╗██╗██╗     ██████╗      ██████╗ ██████╗ ██████╗ ███████╗" -ForegroundColor Magenta
                        Write-Host " ██║    ██║██║██║     ██╔══██╗    ██╔════╝██╔═══██╗██╔══██╗██╔════╝" -ForegroundColor Magenta
                        Write-Host " ██║ █╗ ██║██║██║     ██║  ██║    ██║     ██║   ██║██║  ██║█████╗  " -ForegroundColor Magenta
                        Write-Host " ██║███╗██║██║██║     ██║  ██║    ██║     ██║   ██║██║  ██║██╔══╝  " -ForegroundColor Magenta
                        Write-Host " ╚███╔███╔╝██║███████╗██████╔╝    ╚██████╗╚██████╔╝██████╔╝███████╗" -ForegroundColor Magenta
                        Write-Host "  ╚══╝╚══╝ ╚═╝╚══════╝╚═════╝      ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝" -ForegroundColor Magenta
                        Write-Host "                ███████╗ ██████╗██╗  ██╗ ██████╗  ██████╗ ██╗     " -ForegroundColor Magenta
                        Write-Host "                ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔═══██╗██║     " -ForegroundColor Magenta
                        Write-Host "                ███████╗██║     ███████║██║   ██║██║   ██║██║     " -ForegroundColor Magenta
                        Write-Host "                ╚════██║██║     ██╔══██║██║   ██║██║   ██║██║     " -ForegroundColor Magenta
                        Write-Host "                ███████║╚██████╗██║  ██║╚██████╔╝╚██████╔╝███████╗" -ForegroundColor Magenta
                        Write-Host "                ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor Magenta
                        Write-Host ""
                        
                        # POSITION DU CURSEUR
                        $Host.UI.RawUI.CursorPosition = $cursorPos
                        $selection = Read-Host
                        
                        # SI L'UTILISATEUR CHOISIT UN NUMERO DE MACHINE QUI EST VALIDE
                        if ($selection -match '^\d+$') {
                            $selectionInt = [int]$selection
                            
                            if ($selectionInt -ge 1 -and $selectionInt -le $script:liste_ip.Count) {
                                # ON RECUPERE L'IP CIBLE A PARTIR DU NUMERO CHOISI
                                $ip_cible = $script:liste_ip[$selectionInt - 1]
                                
                                # ON TENTE LA CONNEXION
                                if (ConnexionMachine -ip $ip_cible) {
                                    # CONNEXION REUSSIE ON SORT DE LA BOUCLE MACHINES ET ON REVIENT ENSUITE AU MENU PRINCIPAL
                                    break
                                }
                            }
                            else {
                                Write-Host ""
                                Write-Host "CHOIX INVALIDE"
                                Start-Sleep -Seconds 1
                            }
                        }
                        elseif ($selection -eq "Q" -or $selection -eq "q") {
                            # RETOUR AU MENU PRINCIPAL
                            SauvegarderLog "Navigation_Retour"
                            break
                        }
                        else {
                            Write-Host ""
                            Write-Host "CHOIX INVALIDE"
                            Start-Sleep -Seconds 1
                        }
                    }
                }
                else {
                    # SI AUCUNE MACHINE TROUVEE SUR LE RESEAU
                    Write-Host ""
                    Write-Host "AUCUNE MACHINE TROUVEE SUR LE RESEAU"
                    Write-Host "RETOUR AU MENU"
                    Start-Sleep -Seconds 1
                }
            }
            {$_ -eq "Q" -or $_ -eq "q"} {
                # LOG DE FIN DE SCRIPT
                SauvegarderLog "EndScript"
                # SI OPTION Q ON QUITTE LE SCRIPT PRINCIPAL
                Write-Host ""
                Write-Host "A BIENTOT WILDER!"
                exit
            }
            default {
                # SI LE CHOIX EST INVALIDE ON AFFICHE
                Write-Host ""
                Write-Host "CHOIX INVALIDE"
                Start-Sleep -Seconds 1
            }
        }
    }
}
##################################################################################
#      DEMARRAGE DU SCRIPT PRINCIPAL                                             #
##################################################################################
######################################################################
# INITIALISATION DU FICHIER DE JOURNAL ET DU DOSSIER INFO
InitialiserJournal

# LOG DE DEMARRAGE DU SCRIPT
SauvegarderLog "StartScript"

# ON VERIFIE SI LE SCRIPT DISTANT LINUX EXISTE
if (-not (Test-Path $script_linux)) {
    Write-Host "ATTENTION : SCRIPT LINUX INTROUVABLE ($script_linux)"
}

# ON VERIFIE SI LE SCRIPT DISTANT WINDOWS EXISTE
if (-not (Test-Path $script_windows)) {
    Write-Host "ATTENTION : SCRIPT WINDOWS INTROUVABLE ($script_windows)"
}

# ON LANCE LE MENU PRINCIPAL
MenuPrincipal