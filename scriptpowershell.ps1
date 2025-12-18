##################################################################
#                        SCRIPT_WINDOWS                          #
#                  Script_By: ANIS|FRED|EROS                     #
#                      WILD_CODE_SCHOOL                          #   
#                        06/12/2025                              #
##################################################################

#PARAMETRE POUR RECEVOIR L'UTILISATEUR LOCAL DEPUIS LE SCRIPT PRINCIPAL
param(
    [string]$UtilisateurLocal = $env:USERNAME
)
###############################################################
#           CONFIGURATION DE LA JOURNALISATION                #
###############################################################

#DOSSIER ET FICHIER DE LOG QUI SERA RECUPERE PAR LE SCRIPT PRINCIPAL
$log_dir = "$env:USERPROFILE\Documents"
$log_file = "$log_dir\log_evt.log"

#DOSSIER POUR LES INFORMATIONS QUI SERA RECUPERE PAR LE SCRIPT PRINCIPAL
$info_dir = "$log_dir\info"

#NOM DE LA MACHINE DISTANTE
$nom_machine = $env:COMPUTERNAME

#UTILISATEUR DISTANT 
$utilisateur_distant = $env:USERNAME

#IDENTIFIANT DE SESSION DATE/HEURE DE LANCEMENT
$session_id = Get-Date -Format "yyyyMMdd_HHmmss"

#VARIABLE POUR STOCKER LE MOT DE PASSE ADMIN
$script:MOT_DE_PASSE_ADMIN = $null
$script:CREDENTIAL_ADMIN = $null

###############################################################
#           FONCTIONS DE JOURNALISATION                       #
###############################################################
##############################################################
function InitialiserJournal {
    #CREE LE FICHIER LOG S'IL N'EXISTE PAS
    if (-not (Test-Path $log_file)) {
        New-Item -Path $log_file -ItemType File -Force | Out-Null
    }
    
    #CREE DOSSIER INFO S'IL N'EXISTE PAS
    if (-not (Test-Path $info_dir)) {
        New-Item -Path $info_dir -ItemType Directory -Force | Out-Null
    }
}
##############################################################
function SauvegarderLog {
    param([string]$Evenement)
    
    $date_evt = Get-Date -Format "yyyyMMdd"
    $heure_evt = Get-Date -Format "HHmmss"
    
    $ligne = "${date_evt}_${heure_evt}_${UtilisateurLocal}_${utilisateur_distant}_${nom_machine}_${Evenement}"
    Add-Content -Path $log_file -Value $ligne -ErrorAction SilentlyContinue
}
##############################################################
function SauvegarderInfo {
    param([string]$Contenu)
    
    $fichier_info = "$info_dir\info_${nom_machine}_${utilisateur_distant}_${session_id}.txt"
    
    if (-not (Test-Path $info_dir)) {
        New-Item -Path $info_dir -ItemType Directory -Force | Out-Null
    }
    
    Add-Content -Path $fichier_info -Value $Contenu -ErrorAction SilentlyContinue
}
###############################################################
#                 MOT DE PASSE ADMINISTRATEUR                 #
###############################################################
function VerifierMotDePasseAdmin {
    param([string]$Action)
    
    Write-Host ""
    Write-Host "=== ACTION SENSIBLE : $Action ==="
    Write-Host ""
    
    $securePassword = Read-Host "MOT DE PASSE ADMINISTRATEUR" -AsSecureString
    
    #ON CONVERTIE  LE MOT DE PASSE SECURE EN TEXTE POUR VERIFICATION
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $mdp = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    #VERIFIER LE MOT DE PASSE AVEC UNE AUTHENTIFICATION LOCALE
    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Machine
        $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($contextType)
        $validationResult = $principalContext.ValidateCredentials($env:USERNAME, $mdp)
        
        if ($validationResult) {
            #SI MDP CORRECT ON  STOCKER POUR UTILISATION
            $script:MOT_DE_PASSE_ADMIN = $mdp
            $script:CREDENTIAL_ADMIN = New-Object System.Management.Automation.PSCredential($env:USERNAME, $securePassword)
            return $true
        } else {
            Write-Host ""
            Write-Host "[ERREUR] MOT DE PASSE INCORRECT" -ForegroundColor Red
            Write-Host ""
            Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            return $false
        }
    } catch {
        Write-Host ""
        Write-Host "[ERREUR] MOT DE PASSE INCORRECT" -ForegroundColor Red
        Write-Host ""
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        return $false
    }
}
###############################################################
#                       FONCTION ENTETE                       #
###############################################################
function AfficherEntete {
    Clear-Host
    #NOM MACHINE 
    $NomMachine = $env:COMPUTERNAME
    #RECUPERATION DE  L'IP 
    $AllIPs = [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME) | Where-Object { $_.AddressFamily -eq "InterNetwork" }
    $AdresseIP = ($AllIPs | Where-Object { $_.IPAddressToString -like "172.16.20.*" } | Select-Object -First 1).IPAddressToString
    if (-not $AdresseIP) {
        $AdresseIP = ($AllIPs | Where-Object { $_.IPAddressToString -notlike "127.*" } | Select-Object -First 1).IPAddressToString
    }
    if (-not $AdresseIP) {
        $AdresseIP = "NON DISPONIBLE"
    }
    Write-Host "##################" -NoNewline -ForegroundColor DarkBlue
    Write-Host "##################" -NoNewline -ForegroundColor White
    Write-Host "##################" -ForegroundColor DarkRed
    Write-Host "#                    " -NoNewline -ForegroundColor DarkBlue
    Write-Host "  $NomMachine  " -NoNewline -ForegroundColor White
    Write-Host "                    #" -ForegroundColor DarkRed
    Write-Host "#                  " -NoNewline -ForegroundColor DarkBlue
    Write-Host "  $AdresseIP  " -NoNewline -ForegroundColor White
    Write-Host "                  #" -ForegroundColor DarkRed
    Write-Host "##################" -NoNewline -ForegroundColor DarkBlue
    Write-Host "##################" -NoNewline -ForegroundColor White
    Write-Host "##################" -ForegroundColor DarkRed
    Write-Host ""
}
###############################################################
#              FONCTION AFFICHER UTILISATEURS                 #
###############################################################
function AfficherUtilisateursLocaux {
    Write-Host "  UTILISATEURS LOCAUX"
    Write-Host ""
    Get-LocalUser | Format-Table Name, Enabled, LastLogon -AutoSize
    Write-Host ""
}
###############################################################
#                    FONCTIONS REPERTOIRES                    #
###############################################################
##############################################################
#FONCTION POUR CREER UN REPERTOIRE
function CreerRepertoire {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "CREATION DE REPERTOIRE"
    Write-Host ""
    #ON DEMANDE LE CHEMIN DU REPERTOIRE A CREER
    $Chemin = Read-Host "CHEMIN COMPLET DU REPERTOIRE A CREER (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($Chemin -eq "q" -or $Chemin -eq "Q") {
        #ENREGISTREMENT DANS LE LOG
        SauvegarderLog "Navigation_Retour"
        MenuRepertoires
        return
    }
    #ON REGARDE SI LE CHEMIN EST VIDE
    if ([string]::IsNullOrEmpty($Chemin)) {
        #LE CHEMIN EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "CHEMIN NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        CreerRepertoire
        return
    }
    #ON VERIFIE SI LE REPERTOIRE EXISTE DEJA
    if (Test-Path $Chemin) {
        #LE REPERTOIRE EXISTE DEJA DONC ON AFFICHE UN MESSAGE
        Write-Host "LE REPERTOIRE EXISTE DEJA" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        CreerRepertoire
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DE CREER
    $Confirm = Read-Host "CONFIRMER LA CREATION DE *$Chemin* ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "CREATION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuRepertoires
        return
    }
    #ON CREE LE REPERTOIRE 
    try {
        New-Item -ItemType Directory -Path $Chemin -Force | Out-Null
        #LE REPERTOIRE A ETE CREE DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host "REPERTOIRE CREE AVEC SUCCES" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_CreationRepertoire_$Chemin"
    } catch {
        #ERREUR LORS DE LA CREATION
        Write-Host "IMPOSSIBLE DE CREER LE REPERTOIRE" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT CREER UN AUTRE REPERTOIRE
    $Continuer = Read-Host "VOULEZ-VOUS CREER UN AUTRE REPERTOIRE ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        CreerRepertoire
    } else {
        MenuRepertoires
    }
}
##############################################################
#FONCTION POUR SUPPRIMER UN REPERTOIRE
function SupprimerRepertoire {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "  SUPPRESSION DE REPERTOIRE"
    Write-Host ""
    #ON DEMANDE LE CHEMIN DU REPERTOIRE A SUPPRIMER
    $Chemin = Read-Host "CHEMIN COMPLET DU REPERTOIRE A SUPPRIMER (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($Chemin -eq "q" -or $Chemin -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuRepertoires
        return
    }
    #ON REGARDE SI LE CHEMIN EST VIDE
    if ([string]::IsNullOrEmpty($Chemin)) {
        #LE CHEMIN EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "CHEMIN NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        SupprimerRepertoire
        return
    }
    #ON VERIFIE SI LE REPERTOIRE EXISTE
    if (-not (Test-Path $Chemin)) {
        #LE REPERTOIRE NEXISTE PAS DONC ON AFFICHE UN MESSAGE
        Write-Host "LE REPERTOIRE N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        SupprimerRepertoire
        return
    }
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if (-not (VerifierMotDePasseAdmin "SUPPRIMER REPERTOIRE *$Chemin*")) {
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        SupprimerRepertoire
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DE SUPPRIMER
    $Confirm = Read-Host "CONFIRMER LA SUPPRESSION DE *$Chemin* ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "SUPPRESSION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuRepertoires
        return
    }
    #ON SUPPRIME LE REPERTOIRE 
    try {
        Remove-Item -Path $Chemin -Recurse -Force
        #LE REPERTOIRE A ETE SUPPRIME DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host "REPERTOIRE SUPPRIME AVEC SUCCES" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_SuppressionRepertoire_$Chemin"
    } catch {
        #ERREUR LORS DE LA SUPPRESSION
        Write-Host "IMPOSSIBLE DE SUPPRIMER LE REPERTOIRE" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT SUPPRIMER UN AUTRE REPERTOIRE
    $Continuer = Read-Host "VOULEZ-VOUS SUPPRIMER UN AUTRE REPERTOIRE ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        SupprimerRepertoire
    } else {
        MenuRepertoires
    }
}
###############################################################
#                    FONCTIONS LOGICIELS                      #
###############################################################
##############################################################
function AfficherApplicationsInstallees {
    #ENTETE
    AfficherEntete
    #TITRE
    Write-Host "  APPLICATIONS INSTALLEES"
    Write-Host ""
    
    #ENREGISTREMENT LOG
    SauvegarderLog "Consultation_ApplicationsInstallees"
    
        #RECUPERER LA LISTE DES APPLICATIONS INSTALLEES EN EVITANT LES MESSAGES D'ERREUR  
        $apps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName } | 
        Select-Object DisplayName, DisplayVersion | 
        Sort-Object DisplayName
    
        #DETERMINE LE NOMBRE D'APPLICATIONS
        $nb_apps = ($apps | Measure-Object).Count
        #CONVERTIT LA LISTE EN CHAINE DE CARACTERES
        $liste_apps = $apps | Out-String
    
    #ENREGISTRER DANS FICHIER INFO
    SauvegarderInfo "=== APPLICATIONS INSTALLEES === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$liste_apps"
    
        #DETERMINE L'AFFICHAGE SELON LE NOMBRE D'APPLICATIONS
        if ($nb_apps -le 10) {
        
        #PETITE LISTE -> AFFICHE ET ENREGISTRE
        Write-Host $liste_apps
        Write-Host "($nb_apps APPLICATIONS ENREGISTREES)"
        } else {
        
        #GRANDE LISTE -> ENREGISTRE SEULEMENT
        Write-Host "LISTE DES APPLICATIONS ENREGISTREE ($nb_apps APPLICATIONS)"
        }

    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuLogiciels
}
##############################################################
function AfficherMisesAJourManquantes {
    #ENTETE
    AfficherEntete
    Write-Host "  MISES A JOUR CRITIQUES"
    Write-Host ""
    
    #ENREGISTRER DANS LOG
    SauvegarderLog "Consultation_MisesAJourCritiques"
    
    try {
        #INITIALISER LES OBJETS POUR MISE A JOUR
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        #RECHERCHER LES MISES A JOUR NON INSTALLEES
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0")
        
        #COMPTE LE NOMBRE DE MISES A JOUR TROUVEES
        $nb_maj = $SearchResult.Updates.Count
        
        #VERIFIE SI DES MISES A JOUR SONT DISPONIBLES
        if ($nb_maj -eq 0) {
            Write-Host "AUCUNE MISE A JOUR DISPONIBLE"
            SauvegarderInfo "=== MISES A JOUR === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nAUCUNE MISE A JOUR"
        } else {
            #RECUPERE LA LISTE DES MISES A JOUR
            $mises_a_jour = $SearchResult.Updates | Select-Object Title | Out-String
            
            #ENREGISTRE DANS FICHIER INFO
            SauvegarderInfo "=== MISES A JOUR === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$mises_a_jour"
            
            #AFFICHAGE DES MISES A JOUR SELON LE NOMBRE
            if ($nb_maj -le 10) {
                Write-Host "$nb_maj MISE(S) A JOUR DISPONIBLE(S):"
                Write-Host ""
                Write-Host $mises_a_jour
                Write-Host "($nb_maj MISES A JOUR ENREGISTREES)"
            } else {
                #AFFICHE SEULEMENT LE NOMBRE DE MISES A JOUR
                Write-Host "LISTE DES MISES A JOUR ENREGISTREE ($nb_maj MISES A JOUR)"
            }
        }
    } catch {
        #AFFICHER MESSAGE ERREUR SI IMPOSSIBLE DE VERIFIER LES MISES A JOUR
        Write-Host "VERIFICATION DES MISES A JOUR IMPOSSIBLE" -ForegroundColor DarkGray
        SauvegarderInfo "=== MISES A JOUR === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nVERIFICATION IMPOSSIBLE"
    }

    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuLogiciels
}
###############################################################
#                    FONCTIONS SERVICES                       #
###############################################################
##############################################################
function AfficherServicesEnCours {
    #ENTETE
    AfficherEntete
    Write-Host "  SERVICES EN COURS D'EXECUTION"
    Write-Host ""
    
    #ENREGISTREMENT LOG
    SauvegarderLog "Consultation_ServicesEnCours"
    
        #RECUPERE LA LISTE DES SERVICES EN COURS
        $liste_services = net start | Out-String
        #EVITER DE COMPTER LES LIGNES VIDES
        $nb_lignes = ($liste_services -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
    
    #ENREGISTRER INFO
    SauvegarderInfo "=== SERVICES EN COURS === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$liste_services"
    
    #VERIFIER LE NOMBRE DE LIGNES POUR L'AFFICHAGE
    if ($nb_lignes -le 10) {
        Write-Host $liste_services
    } else {
        #SI AFFICHAGE TROP LONG, N'AFFICHE QUE LE NOMBRE DE SERVICES
        Write-Host "LISTE DES SERVICES ENREGISTREE ($nb_lignes SERVICES)"
    }
    
    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuServices
}
###############################################################
#                    FONCTIONS RESEAU                         #
###############################################################
##############################################################
#FONCTION POUR AFFICHER LA CONFIGURATION IP
function AfficherConfigIP {
    #ENTETE
    AfficherEntete
    #TITRE
    Write-Host "  CONFIGURATION IP"
    Write-Host ""
    #LOG
    SauvegarderLog "Consultation_ConfigurationIP"
    #ON RECUPERE LA CONFIG IP COMPLETE
    $config_complete = ipconfig | Out-String
    #ON SAUVEGARDE LA CONFIG COMPLETE DANS LE FICHIER INFO
    SauvegarderInfo "=== CONFIGURATION IP === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$config_complete"
    $lignes = ipconfig
    #VARIABLE POUR STOCKER LA PASSERELLE
    $passerelle = ""
    #ON PARCOURT CHAQUE LIGNE 
    foreach ($ligne in $lignes) {
        #SI ON TROUVE UNE CARTE ETHERNET
        if ($ligne -match "^Ethernet adapter|^Carte Ethernet") {
            #ON AFFICHE LA PASSERELLE PRECEDENTE SI ELLE EXISTE
            if ($passerelle -ne "") {
                Write-Host "  PASSERELLE: $passerelle"
            }
            Write-Host ""
            #ON AFFICHE LE NOM DE LA CARTE
            Write-Host " $ligne "
            #ON REINITIALISE LA PASSERELLE
            $passerelle = "[AUCUNE]"
        }
        #SI ON TROUVE LADRESSE IPV4
        elseif ($ligne -match "IPv4.*:\s*(\d+\.\d+\.\d+\.\d+)") {
            Write-Host "  IP:         $($Matches[1])"
        }
        #SI ON TROUVE LE MASQUE EN ANGLAIS
        elseif ($ligne -match "Subnet.*:\s*(\d+\.\d+\.\d+\.\d+)") {
            Write-Host "  MASQUE:     $($Matches[1])"
        }
        #SI ON TROUVE LE MASQUE EN FRANCAIS
        elseif ($ligne -match "Masque.*:\s*(\d+\.\d+\.\d+\.\d+)") {
            Write-Host "  MASQUE:     $($Matches[1])"
        }
        #SI ON TROUVE LA PASSERELLE EN ANGLAIS
        elseif ($ligne -match "Gateway.*:\s*(\d+\.\d+\.\d+\.\d+)") {
            $passerelle = $Matches[1]
        }
        #SI ON TROUVE LA PASSERELLE EN FRANCAIS
        elseif ($ligne -match "Passerelle.*:\s*(\d+\.\d+\.\d+\.\d+)") {
            $passerelle = $Matches[1]
        }
    }
    #ON AFFICHE LA DERNIERE PASSERELLE SI ELLE EXISTE
    if ($passerelle -ne "") {
        Write-Host "  PASSERELLE: $passerelle"
    }
    Write-Host ""
    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    #ON RETOURNE AU MENU RESEAU
    MenuReseau
}
##############################################################
#FONCTION POUR AFFICHER LES PORTS OUVERTS
function AfficherPortsOuverts {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "  PORTS OUVERTS "
    Write-Host ""
    #ENREGISTREMENT DANS LE LOG
    SauvegarderLog "Consultation_PortsOuverts"
    #ON RECUPERE LA LISTE DES PORTS 
    $liste_ports = netstat -an | Select-String "LISTENING"
    #ON CONVERTIT EN CHAINE DE CARACTERES
    $liste_ports_str = $liste_ports | Out-String
    #COMPTE NOMBRE DE LIGNES
    $nb_lignes = ($liste_ports_str -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
    #ON SAUVEGARDE LA LISTE DANS LE FICHIER INFO
    SauvegarderInfo "=== PORTS OUVERTS === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$liste_ports_str"
    #PEU DE PORTS ON LES AFFICHE
    if ($nb_lignes -le 10) {
        Write-Host $liste_ports_str
    } else {
        #LA LISTE EST ENREGISTREE
        Write-Host "LISTE DES PORTS ENREGISTREE ($nb_lignes PORTS)"
    }
    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuReseau
}
##############################################################
#FONCTION POUR ACTIVER LE PARE-FEU WINDOWS
function ActiverPareFeu {
    #ENTETE
    AfficherEntete
    #LOG
    SauvegarderLog "Navigation_MenuPareFeu"
    #TITRE 
    Write-Host "  ACTIVATION DU PARE-FEU"
    Write-Host ""
    #ON RECUPERE LETAT DU PARE-FEU POUR CHAQUE PROFIL
    $etatDomain = (netsh advfirewall show domainprofile state | Select-String "State" | Out-String).Trim()
    $etatPrivate = (netsh advfirewall show privateprofile state | Select-String "State" | Out-String).Trim()
    $etatPublic = (netsh advfirewall show publicprofile state | Select-String "State" | Out-String).Trim()
    #ON DETERMINE SI CHAQUE PROFIL EST ACTIF OU NON
    $statusDomain = if ($etatDomain -match "ON") { "ON" } else { "OFF" }
    $statusPrivate = if ($etatPrivate -match "ON") { "ON" } else { "OFF" }
    $statusPublic = if ($etatPublic -match "ON") { "ON" } else { "OFF" }
    #ON AFFICHE LE MENU AVEC LETAT DE CHAQUE PROFIL
    Write-Host "  1. DOMAINE      [$statusDomain]"
    Write-Host "  2. PRIVE        [$statusPrivate]"
    Write-Host "  3. PUBLIC       [$statusPublic]"
    Write-Host "  4. TOUS LES PROFILS"
    Write-Host "  5. QUITTER"
    Write-Host ""
    #ON SAUVEGARDE LETAT COMPLET DANS LE FICHIER INFO
    $etat_complet = "DOMAINE: $statusDomain`nPRIVE: $statusPrivate`nPUBLIC: $statusPublic"
    SauvegarderInfo "=== ETAT PARE-FEU === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$etat_complet"
    #ON DEMANDE LE CHOIX DE LUTILISATEUR
    $Choix = Read-Host "TAPEZ [1-5]"
    # CHOIX UTILISATEUR
    switch ($Choix) {
        1 {
            #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
            if (-not (VerifierMotDePasseAdmin "ACTIVER PARE-FEU *DOMAINE*")) {
                #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
                ActiverPareFeu
                return
            }
            #ON ACTIVE LE PARE-FEU DOMAINE
            netsh advfirewall set domainprofile state on 2>$null
            #ON VERIFIE SI LA COMMANDE A REUSSI
            if ($LASTEXITCODE -eq 0) {
                #LE PARE-FEU A ETE ACTIVE DONC ON AFFICHE UN MESSAGE DE SUCCES
                Write-Host "PARE-FEU DOMAINE ACTIVE" -ForegroundColor Green
                #LOG
                SauvegarderLog "Action_ActivationPareFeu_Domaine"
            } else {
                #ERREUR DE PRIVILEGES
                Write-Host "IMPOSSIBLE D'ACTIVER (PRIVILEGES REQUIS)" -ForegroundColor DarkGray
            }
            Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            ActiverPareFeu
        }
        2 {
            #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
            if (-not (VerifierMotDePasseAdmin "ACTIVER PARE-FEU *PRIVE*")) {
                #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
                ActiverPareFeu
                return
            }
            #ON ACTIVE LE PARE-FEU PRIVE 
            netsh advfirewall set privateprofile state on 2>$null
            #ON VERIFIE SI LA COMMANDE A REUSSI
            if ($LASTEXITCODE -eq 0) {
                #LE PARE-FEU A ETE ACTIVE DONC ON AFFICHE UN MESSAGE DE SUCCES
                Write-Host "PARE-FEU PRIVE ACTIVE" -ForegroundColor Green
                #ENREGISTREMENT DANS LE LOG
                SauvegarderLog "Action_ActivationPareFeu_Prive"
            } else {
                #ERREUR DE PRIVILEGES
                Write-Host "IMPOSSIBLE D'ACTIVER (PRIVILEGES REQUIS)" -ForegroundColor DarkGray
            }
            Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            ActiverPareFeu
        }
        3 {
            #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
            if (-not (VerifierMotDePasseAdmin "ACTIVER PARE-FEU *PUBLIC*")) {
                #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
                ActiverPareFeu
                return
            }
            #ON ACTIVE LE PARE-FEU PUBLIC
            netsh advfirewall set publicprofile state on 2>$null
            #ON VERIFIE SI LA COMMANDE A REUSSI
            if ($LASTEXITCODE -eq 0) {
                #LE PARE-FEU A ETE ACTIVE DONC ON AFFICHE UN MESSAGE DE SUCCES
                Write-Host "PARE-FEU PUBLIC ACTIVE" -ForegroundColor Green
                #LOG
                SauvegarderLog "Action_ActivationPareFeu_Public"
            } else {
                #ERREUR DE PRIVILEGES
                Write-Host "IMPOSSIBLE D'ACTIVER (PRIVILEGES REQUIS)" -ForegroundColor DarkGray
            }
            Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            ActiverPareFeu
        }
        4 {
            #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
            if (-not (VerifierMotDePasseAdmin "ACTIVER *TOUS LES PARE-FEU*")) {
                #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
                ActiverPareFeu
                return
            }
            #ON ACTIVE TOUS LES PROFILS DU PARE-FEU 
            netsh advfirewall set allprofiles state on 2>$null
            #ON VERIFIE SI LA COMMANDE A REUSSI
            if ($LASTEXITCODE -eq 0) {
                #TOUS LES PARE-FEU ONT ETE ACTIVES DONC ON AFFICHE UN MESSAGE DE SUCCES
                Write-Host "TOUS LES PARE-FEU ACTIVES" -ForegroundColor Green
                #LOG
                SauvegarderLog "Action_ActivationPareFeu_Tous"
            } else {
                #ERREUR DE PRIVILEGES 
                Write-Host "IMPOSSIBLE D'ACTIVER (PRIVILEGES REQUIS)" -ForegroundColor DarkGray
            }
            Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            ActiverPareFeu
        }
        5 {
            #LOG
            SauvegarderLog "Navigation_Retour"
            MenuReseau
        }
        default {
            #SI CHOIX INVALIDE
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            ActiverPareFeu
        }
    }
}

###############################################################
#                  FONCTIONS SYSTEME                          #
###############################################################
##############################################################
function AfficherInfoSysteme {
    #ENTETE
    AfficherEntete
    Write-Host "  INFORMATIONS SYSTEME"
    Write-Host ""
    
    #ENREGISTREMENT CONSULTATION
    SauvegarderLog "Consultation_InfoSysteme"
    
            #RECUPERATION DES INFORMATIONS SYSTEME
            $OsName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductName
            $OsVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DisplayVersion
            $OsBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).CurrentBuild
            
            #RECUPERER L'ARCHITECTURE DU SYSTEME
            $OsArch = if ([Environment]::Is64BitOperatingSystem) { 
                "64-bit" 
                } else { 
                "32-bit" 
            }
    
    #RECUPERE LES INFORMATIONS DU POSTE
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $fabricant = $cs.Manufacturer
        $modele = $cs.Model
        $type = $cs.SystemType
    } catch {
        # SI ERREUR, => NON DISPONIBLE
        $fabricant = "NON DISPONIBLE"
        $modele = "NON DISPONIBLE"
        $type = "NON DISPONIBLE"
    }
    
        #AFFICHAGE UTILISATEUR DES INFORMATIONS
        $info_systeme = "NOM: $OsName`nVERSION: $OsVersion (BUILD $OsBuild)`nARCHITECTURE: $OsArch`nFABRICANT: $fabricant`nMODELE: $modele`nTYPE: $type"
    
    #ENREGISTREMENT DANS FICHIER INFO
    SauvegarderInfo "=== INFORMATIONS SYSTEME === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$info_systeme"
    
            #AFFICHER LES INFOS SYSTEME RECUPEREES
            Write-Host "NOM: $OsName"
            Write-Host "VERSION: $OsVersion (BUILD $OsBuild)"
            Write-Host "ARCHITECTURE: $OsArch"
            Write-Host "FABRICANT: $fabricant"
            Write-Host "MODELE: $modele"
            Write-Host "TYPE: $type"
    
    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuSysteme
}
##############################################################
function AfficherUtilisationRAM {
    AfficherEntete
    Write-Host "  UTILISATION DE LA MEMOIRE RAM"
    Write-Host ""
    
    SauvegarderLog "Consultation_UtilisationRAM"
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $ramLibre = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $ramUtilisee = [math]::Round($totalRAM - $ramLibre, 2)
        
        $ram_info = "RAM TOTALE: $totalRAM GO`nRAM UTILISEE: $ramUtilisee GO`nRAM LIBRE: $ramLibre GO"
        
        SauvegarderInfo "=== UTILISATION RAM === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$ram_info"
        
        Write-Host "RAM TOTALE: $totalRAM GO"
        Write-Host "RAM UTILISEE: $ramUtilisee GO"
        Write-Host "RAM LIBRE: $ramLibre GO"
    } catch {
        Write-Host "IMPOSSIBLE DE RECUPERER LES INFORMATIONS RAM" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuSysteme
}
##############################################################
#FONCTION POUR AFFICHER LE STATUT DE LUAC

function AfficherStatutUAC {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "  STATUT DE L'UAC"
    Write-Host ""
    #LOG
    SauvegarderLog "Consultation_StatutUAC"
    
    try {
        #UAC DANS LE REGISTRE
        $uac = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
        #ON REGARDE SI LUAC EST ACTIVE
        if ($uac.EnableLUA -eq 1) {
            #LUAC EST ACTIVE DONC ON AFFICHE EN VERT
            Write-Host "UAC: " -NoNewline
            Write-Host "ACTIVE" -ForegroundColor Green
            $uac_info = "UAC: ACTIVE"
        } else {
            #LUAC EST DESACTIVE 
            Write-Host "UAC: " -NoNewline
            Write-Host "DESACTIVE" -ForegroundColor Red
            $uac_info = "UAC: DESACTIVE"
        }
        #FICHIER INFO
        SauvegarderInfo "=== STATUT UAC === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$uac_info"
    } catch {
        #ERREUR
        Write-Host "IMPOSSIBLE DE RECUPERER LE STATUT UAC" -ForegroundColor DarkGray
    }
    Write-Host ""
    Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    MenuSysteme
}
###############################################################
#                  FONCTIONS CONTROLES                        #
###############################################################
##############################################################
#REDEMARRER LA MACHINE
function RedemarrerMachine {
    AfficherEntete
    Write-Host "  REDEMARRAGE DE LA MACHINE"
    Write-Host ""

    $Confirm1 = Read-Host "REDEMARRER LA MACHINE ? [O/N]"
    if ($Confirm1 -ne "O" -and $Confirm1 -ne "o") {
        Write-Host "REDEMARRAGE ANNULE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuControles
        return
    }
    $Confirm2 = Read-Host "CONFIRMER LE REDEMARRAGE ? [O/N]"
    if ($Confirm2 -ne "O" -and $Confirm2 -ne "o") {
        Write-Host "REDEMARRAGE ANNULE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuControles
        return
    }
    
    Write-Host ""
    Write-Host "REDEMARRAGE EN COURS..."
    SauvegarderLog "Action_RedemarrageMachine"
    
    shutdown /r /t 5
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "LA MACHINE REDEMARRERA DANS 5 SECONDES..." -ForegroundColor Green
        Start-Sleep -Seconds 2
        exit
    } else {
        Write-Host "ECHEC DU REDEMARRAGE (PRIVILEGES INSUFFISANTS)" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuControles
    }
}
##############################################################
# EXECUTER UN SCRIPT DISTANT
function ExecuterScriptDistant {
    AfficherEntete
    Write-Host "  EXECUTION D'UN SCRIPT"
    Write-Host ""
    $CheminScript = Read-Host "CHEMIN COMPLET DU SCRIPT A EXECUTER (Q POUR QUITTER)"

    if ($CheminScript -eq "q" -or $CheminScript -eq "Q") {
        SauvegarderLog "Navigation_Retour"
        MenuControles
        return
    }
    if ([string]::IsNullOrEmpty($CheminScript)) {
        Write-Host "CHEMIN NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        ExecuterScriptDistant
        return
    }
    if (-not (Test-Path $CheminScript)) {
        Write-Host "LE FICHIER N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        ExecuterScriptDistant
        return
    }
    
    # VERIFICATION MOT DE PASSE ADMIN
    if (-not (VerifierMotDePasseAdmin "EXECUTER SCRIPT *$CheminScript*")) {
        ExecuterScriptDistant
        return
    }
    
    $Confirm = Read-Host "EXECUTER LE SCRIPT *$CheminScript* ? [O/N]"
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        Write-Host "EXECUTION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuControles
        return
    }
    Write-Host ""
    Write-Host "EXECUTION DU SCRIPT EN COURS..."
    Write-Host ""
    SauvegarderLog "Action_ExecutionScript_$CheminScript"
    try {
        & $CheminScript
        Write-Host ""
        Write-Host "SCRIPT EXECUTE" -ForegroundColor Green
    } catch {
        Write-Host "ERREUR LORS DE L'EXECUTION" -ForegroundColor Red
    }
    Write-Host ""
    $Continuer = Read-Host "VOULEZ-VOUS EXECUTER UN AUTRE SCRIPT ? [O/N]"
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        ExecuterScriptDistant
    } else {
        MenuControles
    }
}
##############################################################
#OUVRIR UNE CONSOLE DISTANTE
function OuvrirConsoleDistante {
    AfficherEntete
    Write-Host "  PRISE DE MAIN A DISTANCE (CLI)"
    Write-Host ""
    Write-Host "TAPEZ *EXIT* POUR REVENIR AU MENU"
    Write-Host ""
    SauvegarderLog "Action_OuvertureConsole"
    powershell.exe -NoLogo
    SauvegarderLog "Action_FermetureConsole"
    MenuControles
}
###############################################################
#                  FONCTIONS UTILISATEURS                     #
###############################################################
##############################################################
#FONCTION POUR CREER UN COMPTE UTILISATEUR LOCAL
function CreerUtilisateurLocal {
    #ENTETE
    AfficherEntete
    #TITRE
    Write-Host "  CREATION D'UN COMPTE UTILISATEUR"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DU NOUVEL UTILISATEUR
    $NomUtilisateur = Read-Host "NOM DU NOUVEL UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        CreerUtilisateurLocal
        return
    }
    #ON VERIFIE QUE LUTILISATEUR NEXISTE PAS DEJA
    if (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue) {
        #SI LUTILISATEUR EXISTE DEJA ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" EXISTE DEJA" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        CreerUtilisateurLocal
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DE CREER
    $Confirm = Read-Host "CONFIRMER LA CREATION DE `"$NomUtilisateur`" ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "CREATION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuUtilisateurs
        return
    }
    #ON CREE LUTILISATEUR 
    try {
        New-LocalUser -Name $NomUtilisateur -NoPassword
        #LUTILISATEUR A ETE CREE DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host ""
        Write-Host "UTILISATEUR `"$NomUtilisateur`" CREE AVEC SUCCES" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_CreationUtilisateur_$NomUtilisateur"
    } catch {
        #ERREUR LORS DE LA CREATION
        Write-Host "IMPOSSIBLE DE CREER L'UTILISATEUR" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT CREER UN AUTRE COMPTE
    $Continuer = Read-Host "VOULEZ-VOUS CREER UN AUTRE UTILISATEUR ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        CreerUtilisateurLocal
    } else {
        MenuUtilisateurs
    }
}
##############################################################
#FONCTION POUR SUPPRIMER UN COMPTE UTILISATEUR LOCAL
function SupprimerUtilisateurLocal {
    #ENTETE
    AfficherEntete
    #TITRE
    Write-Host "  SUPPRESSION DE COMPTE UTILISATEUR"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    $NomUtilisateur = Read-Host "NOM D'UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        SupprimerUtilisateurLocal
        return
    }
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if (-not (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue)) {
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        SupprimerUtilisateurLocal
        return
    }
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if (-not (VerifierMotDePasseAdmin "SUPPRIMER UTILISATEUR `"$NomUtilisateur`"")) {
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        SupprimerUtilisateurLocal
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DE SUPPRIMER
    $Confirm = Read-Host "SUPPRIMER DEFINITIVEMENT `"$NomUtilisateur`" ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "SUPPRESSION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuUtilisateurs
        return
    }
    #ON SUPPRIME LUTILISATEUR 
    try {
        Remove-LocalUser -Name $NomUtilisateur
        #LUTILISATEUR A ETE SUPPRIME DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host ""
        Write-Host "UTILISATEUR `"$NomUtilisateur`" SUPPRIME" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_SuppressionUtilisateur_$NomUtilisateur"
    } catch {
        #ERREUR LORS DE LA SUPPRESSION
        Write-Host "IMPOSSIBLE DE SUPPRIMER L'UTILISATEUR" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT SUPPRIMER UN AUTRE COMPTE
    $Continuer = Read-Host "VOULEZ-VOUS SUPPRIMER UN AUTRE UTILISATEUR ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        SupprimerUtilisateurLocal
    } else {
        MenuUtilisateurs
    }
}
##############################################################
#FONCTION POUR DESACTIVER UN COMPTE UTILISATEUR LOCAL
function DesactiverUtilisateurLocal {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "  DESACTIVATION DE COMPTE UTILISATEUR"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    $NomUtilisateur = Read-Host "NOM D'UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        DesactiverUtilisateurLocal
        return
    }
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if (-not (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue)) {
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        DesactiverUtilisateurLocal
        return
    }
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if (-not (VerifierMotDePasseAdmin "DESACTIVER UTILISATEUR `"$NomUtilisateur`"")) {
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        DesactiverUtilisateurLocal
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DE DESACTIVER
    $Confirm = Read-Host "DESACTIVER `"$NomUtilisateur`" ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "DESACTIVATION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuUtilisateurs
        return
    }
    #ON DESACTIVE LUTILISATEUR
    try {
        Disable-LocalUser -Name $NomUtilisateur
        #LUTILISATEUR A ETE DESACTIVE DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host ""
        Write-Host "UTILISATEUR `"$NomUtilisateur`" DESACTIVE" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_DesactivationUtilisateur_$NomUtilisateur"
    } catch {
        #ERREUR LORS DE LA DESACTIVATION
        Write-Host "IMPOSSIBLE DE DESACTIVER L'UTILISATEUR" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT DESACTIVER UN AUTRE COMPTE
    $Continuer = Read-Host "VOULEZ-VOUS DESACTIVER UN AUTRE UTILISATEUR ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        DesactiverUtilisateurLocal
    } else {
        MenuUtilisateurs
    }
}
##############################################################
#FONCTION POUR MODIFIER LE MOT DE PASSE DUN UTILISATEUR
function ModifierMotDePasseUtilisateur {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "  CHANGEMENT DE MOT DE PASSE"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    $NomUtilisateur = Read-Host "NOM D'UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        ModifierMotDePasseUtilisateur
        return
    }
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if (-not (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue)) {
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        ModifierMotDePasseUtilisateur
        return
    }
    #ON DEMANDE LE NOUVEAU MOT DE PASSE 
    $Password = Read-Host "NOUVEAU MOT DE PASSE" -AsSecureString
    #ON DEMANDE CONFIRMATION AVANT DE MODIFIER
    $Confirm = Read-Host "CONFIRMER LE CHANGEMENT DE MOT DE PASSE POUR `"$NomUtilisateur`" ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "MODIFICATION ANNULEE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuUtilisateurs
        return
    }
    #ON MODIFIE LE MOT DE PASSE 
    try {
        Set-LocalUser -Name $NomUtilisateur -Password $Password
        #LE MOT DE PASSE A ETE MODIFIE DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host ""
        Write-Host "MOT DE PASSE MODIFIE POUR `"$NomUtilisateur`"" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_ModificationMotDePasse_$NomUtilisateur"
    } catch {
        #ERREUR LORS DE LA MODIFICATION
        Write-Host "IMPOSSIBLE DE MODIFIER LE MOT DE PASSE" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT MODIFIER UN AUTRE MOT DE PASSE
    $Continuer = Read-Host "VOULEZ-VOUS MODIFIER UN AUTRE MOT DE PASSE ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        ModifierMotDePasseUtilisateur
    } else {
        MenuUtilisateurs
    }
}
##############################################################
#FONCTION POUR AJOUTER UN UTILISATEUR A UN GROUPE LOCAL
function AjouterUtilisateurGroupe {
    #ENTETE
    AfficherEntete
    #TITRE
    Write-Host "  AJOUT A UN GROUPE"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    $NomUtilisateur = Read-Host "NOM D'UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupe
        return
    }
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if (-not (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue)) {
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupe
        return
    }
    Write-Host ""
    #LES GROUPES LOCAUX
    $tousGroupes = Get-LocalGroup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object
    $groupes_dispo = $tousGroupes -join " | "
    #ON AFFICHE LES GROUPES DISPONIBLES
    Write-Host "GROUPES DISPONIBLES: $groupes_dispo"
    Write-Host ""
    #ON DEMANDE LE NOM DU GROUPE
    $NomGroupe = Read-Host "NOM DU GROUPE (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomGroupe -eq "q" -or $NomGroupe -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM DU GROUPE EST VIDE
    if ([string]::IsNullOrEmpty($NomGroupe)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM DU GROUPE NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupe
        return
    }
    #ON VERIFIE QUE LE GROUPE EXISTE
    if (-not (Get-LocalGroup -Name $NomGroupe -ErrorAction SilentlyContinue)) {
        #SI LE GROUPE NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "LE GROUPE *$NomGroupe* N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupe
        return
    }
    #ON VERIFIE SI LUTILISATEUR EST DEJA MEMBRE DU GROUPE
    $membres = Get-LocalGroupMember -Group $NomGroupe -ErrorAction SilentlyContinue
    if ($membres.Name -like "*\$NomUtilisateur" -or $membres.Name -eq $NomUtilisateur) {
        #LUTILISATEUR EST DEJA DANS LE GROUPE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" EST DEJA DANS LE GROUPE *$NomGroupe*" -ForegroundColor DarkGray
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupe
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DAJOUTER
    $Confirm = Read-Host "AJOUTER `"$NomUtilisateur`" AU GROUPE *$NomGroupe* ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "AJOUT ANNULE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuUtilisateurs
        return
    }
    #ON AJOUTE LUTILISATEUR AU GROUPE 
    try {
        net localgroup "$NomGroupe" "$NomUtilisateur" /add 2>$null
        #ON VERIFIE SI LA COMMANDE A REUSSI
        if ($LASTEXITCODE -eq 0) {
            #LUTILISATEUR A ETE AJOUTE DONC ON AFFICHE UN MESSAGE DE SUCCES
            Write-Host ""
            Write-Host "UTILISATEUR `"$NomUtilisateur`" AJOUTE AU GROUPE *$NomGroupe*" -ForegroundColor Green
            #LOG
            SauvegarderLog "Action_AjoutGroupe_${NomUtilisateur}_${NomGroupe}"
        } else {
            #LUTILISATEUR NA PAS ETE AJOUTE DONC ON AFFICHE UNE ERREUR
            Write-Host "IMPOSSIBLE D'AJOUTER L'UTILISATEUR AU GROUPE" -ForegroundColor Red
        }
    } catch {
        #ERREUR LORS DE LAJOUT
        Write-Host "IMPOSSIBLE D'AJOUTER L'UTILISATEUR AU GROUPE" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT AJOUTER UN AUTRE COMPTE
    $Continuer = Read-Host "VOULEZ-VOUS AJOUTER UN AUTRE UTILISATEUR ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        AjouterUtilisateurGroupe
    } else {
        MenuUtilisateurs
    }
}
##############################################################
#FONCTION POUR AJOUTER UN UTILISATEUR AU GROUPE ADMINISTRATEURS
function AjouterUtilisateurGroupeAdmin {
    #ENTETE
    AfficherEntete
    #TITRE
    Write-Host "  AJOUT AUX ADMINISTRATEURS"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    $NomUtilisateur = Read-Host "NOM D'UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupeAdmin
        return
    }
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if (-not (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue)) {
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupeAdmin
        return
    }
    #ON VERIFIE SI LUTILISATEUR EST DEJA ADMIN FR
    $dejaAdmin = net localgroup "Administrateurs" 2>$null | Select-String -Pattern "^$NomUtilisateur$"
    #ON VERIFIE AUSSI EN VERSION ANG
    if (-not $dejaAdmin) {
        $dejaAdmin = net localgroup "Administrators" 2>$null | Select-String -Pattern "^$NomUtilisateur$"
    }
    #SI LUTILISATEUR EST DEJA ADMIN ON AFFICHE UN MESSAGE
    if ($dejaAdmin) {
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" EST DEJA DANS LE GROUPE *ADMINISTRATEURS*" -ForegroundColor DarkGray
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AjouterUtilisateurGroupeAdmin
        return
    }
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if (-not (VerifierMotDePasseAdmin "AJOUTER `"$NomUtilisateur`" AU GROUPE *ADMINISTRATEURS*")) {
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        AjouterUtilisateurGroupeAdmin
        return
    }
    #ON DEMANDE CONFIRMATION AVANT DAJOUTER
    $Confirm = Read-Host "AJOUTER `"$NomUtilisateur`" AU GROUPE *ADMINISTRATEURS* ? [O/N]"
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if ($Confirm -ne "O" -and $Confirm -ne "o") {
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        Write-Host "AJOUT ANNULE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        MenuUtilisateurs
        return
    }
    #ON AJOUTE LUTILISATEUR AU GROUPE ADMINISTRATEURS FR
    $resultat = net localgroup "Administrateurs" "$NomUtilisateur" /add 2>&1
    #SI CA NA PAS MARCHE ON ESSAIE EN ANG
    if ($LASTEXITCODE -ne 0) {
        $resultat = net localgroup "Administrators" "$NomUtilisateur" /add 2>&1
    }
    #ON VERIFIE SI LA COMMANDE A REUSSI
    if ($LASTEXITCODE -eq 0) {
        #LUTILISATEUR A ETE AJOUTE DONC ON AFFICHE UN MESSAGE DE SUCCES
        Write-Host ""
        Write-Host "UTILISATEUR `"$NomUtilisateur`" AJOUTE AU GROUPE *ADMINISTRATEURS*" -ForegroundColor Green
        #LOG
        SauvegarderLog "Action_AjoutGroupeAdmin_$NomUtilisateur"
    } else {
        #LUTILISATEUR NA PAS ETE AJOUTE DONC ON AFFICHE UNE ERREUR
        Write-Host ""
        Write-Host "IMPOSSIBLE D'AJOUTER L'UTILISATEUR AU GROUPE" -ForegroundColor Red
    }
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT AJOUTER UN AUTRE COMPTE
    $Continuer = Read-Host "VOULEZ-VOUS AJOUTER UN AUTRE UTILISATEUR ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        AjouterUtilisateurGroupeAdmin
    } else {
        MenuUtilisateurs
    }
}
##############################################################
#FONCTION POUR AFFICHER LES GROUPES DUN UTILISATEUR
function AfficherGroupesUtilisateur {
    #ENTETE
    AfficherEntete
    #TITRE 
    Write-Host "  GROUPES D'APPARTENANCE D'UN UTILISATEUR"
    Write-Host ""
    #ON LISTE LES UTILISATEURS ACTUELS
    AfficherUtilisateursLocaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    $NomUtilisateur = Read-Host "NOM D'UTILISATEUR (Q POUR QUITTER)"
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if ($NomUtilisateur -eq "q" -or $NomUtilisateur -eq "Q") {
        #LOG
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    #ON REGARDE SI LE NOM EST VIDE
    if ([string]::IsNullOrEmpty($NomUtilisateur)) {
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        Write-Host "NOM D'UTILISATEUR NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AfficherGroupesUtilisateur
        return
    }
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if (-not (Get-LocalUser -Name $NomUtilisateur -ErrorAction SilentlyContinue)) {
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        Write-Host "L'UTILISATEUR `"$NomUtilisateur`" N'EXISTE PAS" -ForegroundColor Red
        #ON ATTEND QUE LUTILISATEUR APPUIE SUR ENTREE
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AfficherGroupesUtilisateur
        return
    }
    #LOG
    SauvegarderLog "Consultation_GroupesUtilisateur_$NomUtilisateur"
    #ON CREE UN TABLEAU POUR STOCKER LES GROUPES TROUVES
    $groupesTrouves = @()
    #ON PARCOURT TOUS LES GROUPES LOCAUX
    Get-LocalGroup | ForEach-Object {
        #ON RECUPERE LES MEMBRES DU GROUPE
        $membres = Get-LocalGroupMember -Group $_.Name -ErrorAction SilentlyContinue
        #ON VERIFIE SI LUTILISATEUR EST MEMBRE DU GROUPE
        if ($membres.Name -like "*\$NomUtilisateur" -or $membres.Name -eq $NomUtilisateur) {
            #ON AJOUTE LE GROUPE A LA LISTE
            $groupesTrouves += $_.Name
        }
    }
    #ON VERIFIE SI ON A TROUVE DES GROUPES
    if ($groupesTrouves.Count -eq 0) {
        #AUCUN GROUPE TROUVE
        $groupes = "AUCUN GROUPE TROUVE"
    } else {
        #ON JOINT LES GROUPES AVEC UN SEPARATEUR
        $groupes = $groupesTrouves -join " | "
    }
    #ON SAUVEGARDE LES INFOS DANS LE FICHIER
    SauvegarderInfo "=== GROUPES UTILISATEUR === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nUTILISATEUR: $NomUtilisateur`nGROUPES: $groupes"
    #ON AFFICHE LES GROUPES
    Write-Host ""
    Write-Host "GROUPES DE `"$NomUtilisateur`": $groupes"
    Write-Host ""
    #ON DEMANDE SI LUTILISATEUR VEUT CONSULTER UN AUTRE COMPTE
    $Continuer = Read-Host "VOULEZ-VOUS CONSULTER UN AUTRE UTILISATEUR ? [O/N]"
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        AfficherGroupesUtilisateur
    } else {
        MenuUtilisateurs
    }
}
##############################################################
function AfficherPermissionsUtilisateur {
    AfficherEntete
    Write-Host "  DROITS ET PERMISSIONS SUR FICHIER"
    Write-Host ""
    $Chemin = Read-Host "CHEMIN DU FICHIER OU DOSSIER (Q POUR QUITTER)"
    if ($Chemin -eq "q" -or $Chemin -eq "Q") {
        SauvegarderLog "Navigation_Retour"
        MenuUtilisateurs
        return
    }
    if ([string]::IsNullOrEmpty($Chemin)) {
        Write-Host "CHEMIN NON SPECIFIE"
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AfficherPermissionsUtilisateur
        return
    }
    if (-not (Test-Path $Chemin)) {
        Write-Host "LE CHEMIN *$Chemin* N'EXISTE PAS" -ForegroundColor Red
        Read-Host "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        AfficherPermissionsUtilisateur
        return
    }
    
    SauvegarderLog "Consultation_Permissions_$Chemin"
    
    Write-Host ""
    Write-Host "PERMISSIONS:"
    Write-Host ""
    
    #SI C'EST UN DOSSIER ON LISTE LE CONTENU AVEC LES PERMISSIONS
    if (Test-Path $Chemin -PathType Container) {
        $items = Get-ChildItem $Chemin -Force
        foreach ($item in $items) {
            $acl = Get-Acl $item.FullName
            $type = if ($item.PSIsContainer) { "[DOSSIER]" } else { "[FICHIER]" }
            Write-Host "$type $($item.Name)"
            Write-Host "  PROPRIETAIRE: $($acl.Owner)"
            $acl.Access | ForEach-Object {
                Write-Host "  $($_.IdentityReference) - $($_.FileSystemRights) - $($_.AccessControlType)"
            }
            Write-Host ""
        }
        $permissions = $items | ForEach-Object { "$($_.Name) - $($(Get-Acl $_.FullName).Owner)" } | Out-String
    } else {
        #SI C'EST UN FICHIER ON AFFICHE SES PERMISSIONS
        $acl = Get-Acl $Chemin
        Write-Host "PROPRIETAIRE: $($acl.Owner)"
        Write-Host ""
        $acl.Access | ForEach-Object {
            Write-Host "$($_.IdentityReference) - $($_.FileSystemRights) - $($_.AccessControlType)"
        }
        $permissions = $acl.Access | Select-Object IdentityReference, FileSystemRights, AccessControlType | Out-String
    }
    
    SauvegarderInfo "=== PERMISSIONS === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nCHEMIN: $Chemin`n$permissions"
    
    Write-Host ""
    $Continuer = Read-Host "VOULEZ-VOUS CONSULTER UN AUTRE CHEMIN ? [O/N]"
    if ($Continuer -eq "O" -or $Continuer -eq "o") {
        AfficherPermissionsUtilisateur
    } else {
        MenuUtilisateurs
    }
}
###############################################################
#                         MENUS                               #
###############################################################
###############################################################
function MenuRepertoires {
    AfficherEntete
    SauvegarderLog "Navigation_MenuRepertoires"
    Write-Host "  REPERTOIRES"
    Write-Host ""
    Write-Host "  1.CREER UN REPERTOIRE"
    Write-Host "  2.SUPPRIMER UN REPERTOIRE"
    Write-Host "  3.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-3]"
    switch ($Choix) {
        1 { CreerRepertoire }
        2 { SupprimerRepertoire }
        3 { SauvegarderLog "Navigation_Retour"; MenuGestionMachine }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuRepertoires
        }
    }
}

##############################################################
function MenuLogiciels {
    AfficherEntete
    SauvegarderLog "Navigation_MenuLogiciels"
    Write-Host "  LOGICIELS"
    Write-Host ""
    Write-Host "  1.APPLICATIONS INSTALLEES"
    Write-Host "  2.MISES A JOUR CRITIQUES"
    Write-Host "  3.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-3]"
    switch ($Choix) {
        1 { AfficherApplicationsInstallees }
        2 { AfficherMisesAJourManquantes }
        3 { SauvegarderLog "Navigation_Retour"; MenuGestionMachine }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuLogiciels
        }
    }
}

##############################################################
function MenuServices {
    AfficherEntete
    SauvegarderLog "Navigation_MenuServices"
    Write-Host "  GESTION DES SERVICES"
    Write-Host ""
    Write-Host "  1.LISTER LES SERVICES EN COURS"
    Write-Host "  2.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-2]"
    switch ($Choix) {
        1 { AfficherServicesEnCours }
        2 { SauvegarderLog "Navigation_Retour"; MenuGestionMachine }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuServices
        }
    }
}

##############################################################
function MenuReseau {
    AfficherEntete
    SauvegarderLog "Navigation_MenuReseau"
    Write-Host "  RESEAU"
    Write-Host ""
    Write-Host "  1.PORTS OUVERTS"
    Write-Host "  2.INFORMATION RESEAU"
    Write-Host "  3.ACTIVATION DU PARE-FEU"
    Write-Host "  4.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-4]"
    switch ($Choix) {
        1 { AfficherPortsOuverts }
        2 { AfficherConfigIP }
        3 { ActiverPareFeu }
        4 { SauvegarderLog "Navigation_Retour"; MenuGestionMachine }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuReseau
        }
    }
}

##############################################################
function MenuSysteme {
    AfficherEntete
    SauvegarderLog "Navigation_MenuSysteme"
    Write-Host "  SYSTEME"
    Write-Host ""
    Write-Host "  1.INFORMATIONS SYSTEME"
    Write-Host "  2.INFORMATION SUR LA RAM"
    Write-Host "  3.STATUT UAC"
    Write-Host "  4.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-4]"
    switch ($Choix) {
        1 { AfficherInfoSysteme }
        2 { AfficherUtilisationRAM }
        3 { AfficherStatutUAC }
        4 { SauvegarderLog "Navigation_Retour"; MenuGestionMachine }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuSysteme
        }
    }
}

##############################################################
function MenuControles {
    AfficherEntete
    SauvegarderLog "Navigation_MenuControles"
    Write-Host "  CONTROLES"
    Write-Host ""
    Write-Host "  1.REDEMARRAGE"
    Write-Host "  2.EXECUTER UN SCRIPT"
    Write-Host "  3.PRISE DE MAIN A DISTANCE (CLI)"
    Write-Host "  4.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-4]"
    switch ($Choix) {
        1 { RedemarrerMachine }
        2 { ExecuterScriptDistant }
        3 { OuvrirConsoleDistante }
        4 { SauvegarderLog "Navigation_Retour"; MenuGestionMachine }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuControles
        }
    }
}

##############################################################
function MenuUtilisateurs {
    AfficherEntete
    SauvegarderLog "Navigation_MenuUtilisateurs"
    Write-Host "  GESTION DES UTILISATEURS"
    Write-Host ""
    Write-Host "  1.CREER UN COMPTE UTILISATEUR LOCAL"
    Write-Host "  2.CHANGER UN MOT DE PASSE"
    Write-Host "  3.DESACTIVER UN COMPTE"
    Write-Host "  4.SUPPRIMER UN COMPTE"
    Write-Host "  5.VERIFIER L'APPARTENANCE A UN GROUPE"
    Write-Host "  6.AJOUTER AUX ADMINISTRATEURS"
    Write-Host "  7.AJOUTER A UN GROUPE"
    Write-Host "  8.DROITS ET PERMISSIONS SUR FICHIER"
    Write-Host "  9.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-9]"
    switch ($Choix) {
        1 { CreerUtilisateurLocal }
        2 { ModifierMotDePasseUtilisateur }
        3 { DesactiverUtilisateurLocal }
        4 { SupprimerUtilisateurLocal }
        5 { AfficherGroupesUtilisateur }
        6 { AjouterUtilisateurGroupeAdmin }
        7 { AjouterUtilisateurGroupe }
        8 { AfficherPermissionsUtilisateur }
        9 { SauvegarderLog "Navigation_Retour"; MenuPrincipal }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuUtilisateurs
        }
    }
}

##############################################################
function MenuGestionMachine {
    AfficherEntete
    SauvegarderLog "Navigation_MenuGestionMachine"
    Write-Host "  GESTION DE LA MACHINE"
    Write-Host ""
    Write-Host "  1.REPERTOIRES"
    Write-Host "  2.LOGICIELS"
    Write-Host "  3.SERVICES"
    Write-Host "  4.RESEAU"
    Write-Host "  5.SYSTEME"
    Write-Host "  6.CONTROLES"
    Write-Host "  7.RETOUR"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-7]"
    switch ($Choix) {
        1 { MenuRepertoires }
        2 { MenuLogiciels }
        3 { MenuServices }
        4 { MenuReseau }
        5 { MenuSysteme }
        6 { MenuControles }
        7 { SauvegarderLog "Navigation_Retour"; MenuPrincipal }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuGestionMachine
        }
    }
}

##############################################################
function MenuPrincipal {
    AfficherEntete
    SauvegarderLog "Navigation_MenuPrincipal"
    Write-Host "  MENU PRINCIPAL"
    Write-Host ""
    Write-Host "  1.GESTION DE LA MACHINE"
    Write-Host "  2.GESTION DES UTILISATEURS"
    Write-Host "  Q.QUITTER"
    Write-Host ""
    $Choix = Read-Host "TAPEZ [1-2 OU Q]"
    switch ($Choix) {
        1 { MenuGestionMachine }
        2 { MenuUtilisateurs }
        "Q" {
            Clear-Host
            SauvegarderLog "DeconnexionMachine"
            exit
        }
        "q" {
            Clear-Host
            SauvegarderLog "DeconnexionMachine"
            exit
        }
        default {
            Read-Host "CHOIX INVALIDE, APPUYEZ SUR [ENTREE] POUR CONTINUER"
            MenuPrincipal
        }
    }
}
###############################################################
#                    DEMARAGE                                 #
###############################################################

#INITIALISATION DU FICHIER DE JOURNAL ET DU DOSSIER INFO
InitialiserJournal

#LOG DE CONNEXION A LA MACHINE
SauvegarderLog "ConnexionMachine"

#DEMARAGE DU  MENU PRINCIPAL
MenuPrincipal
