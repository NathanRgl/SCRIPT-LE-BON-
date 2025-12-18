#!/bin/bash
##################################################################
#                          SCRIPT_PRINCIPAL                      #
#                      SCRIPT_BY ANIS FRED EROS                  #
#                          WILD_CODE_SCHOOL                      #
##################################################################

###############################################################
#                CONFIGURATION ET VARIABLES                   #
###############################################################

#PORT POUR LES CONNEXIONS SSH
port_ssh="22222"
# DOSSIER OU SE TROUVE LE SCRIPT PRINCIPAL
script_dir="$(cd "$(dirname "$0")" && pwd)"
#RESEAU A SCANNER
ip_reseau="172.16.20."
#DELAI PING
delai_ping=1
#FICHIER TEMPORAIRE POUR  LES ADRESSES IP DES MACHINES
fichier_temp="/tmp/machines_actives_$$.txt"
#FICHIER TEMPORAIRE POUR LES NOMS DES MACHINES
fichier_noms="/tmp/noms_machines_$$.txt"
#EMPLACEMNT DU SCRIPT LINUX QUI SERA ENVOYE SUR LA MACHINE LINUX
script_linux="$script_dir/scriptbash.sh"
#EMPLACEMENT DU SCRIPT WINDOWS QUI SERA ENVOYE SUR LA MACHINE WINDOWS
script_windows="$script_dir/scriptpowershell.ps1"
#UTILISATEUR LINUX PAR DEFAUT 
utilisateur_linux="wilder"
#LISTE DES COMPTES WINDOWS QUE LON VA TESTER POUR SE CONNECTER
utilisateurs_windows=("wilder1" "wilder" "admin" "administrateur" "administrator" "user")
#DATE 
date_actuelle=$(date "+%Y-%m-%d")
#HEURE
heure_actuelle=$(date "+%H-%M-%S")
#ADRESSE IP LOCAL POUR NE PAS LE METTRE DANS LA LISTE
local_ip=""
#TABLEAU OU ON GARDE TOUTES LES ADRESSES IP TROUVEES SUR LE RESEAU
declare -a liste_ip
#TABLEAU OU ON ASSOCIE CHAQUE ADRESSE IP AVEC LE NOM DE LA MACHINE
declare -A noms_machines
#TABLEAU OU ON NOTE LE SYSTEME DE CHAQUE MACHINE LINUX WINDOWS OU INCONNU
declare -A type_os
#TABLEAU OU ON GARDE LE BON UTILISATEUR WINDOWS POUR CHAQUE ADRESSE IP
declare -A utilisateur_windows 

###############################################################
#CONFIGURATION DE LA JOURNALISATION
###############################################################

#CHEMIN DU DOSSIER OU ON MET LE FICHIER DE LOG
log_dir="/var/log"

#CHEMIN COMPLET DU FICHIER DE LOG
log_file="$log_dir/log_evt.log"

#DOSSIER OU ON MET LES INFORMATIONS RECUPEREES SUR LES MACHINES
info_dir="$script_dir/info"

###############################################################
#FONCTIONS DE JOURNALISATION
###############################################################

####################################################################
#FONCTION QUI PREPARE LE FICHIER DE LOG ET LE DOSSIER INFO
initialiser_journal() {

    #ON REGARDE SI LE FICHIER DE LOG EXISTE DEJA SUR LE SERVEUR
    if [ -f "$log_file" ]; then

        #LE FICHIER EXISTE DONC ON TESTE SI ON PEUT ECRIRE DEDANS
        if echo "" >> "$log_file" 2>/dev/null; then
            #ON PEUT ECRIRE DANS LE FICHIER DONC TOUT VA BIEN
            :
        else
            #LE FICHIER EXISTE MAIS ON NE PEUT PAS ECRIRE DEDANS
            #CELA VEUT DIRE QUE LES DROITS NE SONT PAS BONS
            echo "LE FICHIER $log_file EXISTE MAIS VOUS NE POUVEZ PAS ECRIRE DEDANS"

            #ON AFFICHE UN MESSAGE POUR DIRE QU ON VA ESSAYER DE CORRIGER
            echo "TENTATIVE DE CORRECTION DES DROITS"

            #ON ESSAIE DE CHANGER LES DROITS DU FICHIER AVEC SUDO
            sudo chmod 666 "$log_file" 2>/dev/null

            #ON REGARDE SI LA COMMANDE CHMOD A MARCHE OU PAS
            if [ $? -ne 0 ]; then
                #LA COMMANDE NA PAS MARCHE DONC ON CHANGE LEMPLACEMENT DU LOG
                echo "IMPOSSIBLE DE MODIFIER LES PERMISSIONS LE LOG SERA DANS LE SCRIPT"

                #ON MET LE LOG DANS LE MEME DOSSIER QUE LE SCRIPT
                log_dir="$script_dir"

                #ON MET A JOUR LE CHEMIN COMPLET DU FICHIER DE LOG
                log_file="$script_dir/log_evt.log"
            fi
        fi

    else
        #LE FICHIER DE LOG NEXISTE PAS DONC ON VA LE CREER
        echo "CREATION DU FICHIER DE LOG DANS VAR LOG"

        #ON PREVIENT QU IL FAUDRA PEUT ETRE LE MOT DE PASSE SUDO
        echo "MOT DE PASSE SUDO REQUIS"

        #ON CREE LE FICHIER AVEC SUDO ET ON MET LES DROITS POUR TOUT LE MONDE
        sudo touch "$log_file" 2>/dev/null && sudo chmod 666 "$log_file" 2>/dev/null

        #ON REGARDE SI LA CREATION A MARCHE OU PAS
        if [ $? -ne 0 ]; then
            #LA CREATION NA PAS MARCHE DONC ON MET LE LOG DANS LE SCRIPT
            echo "IMPOSSIBLE DE CREER LE FICHIER DANS VAR LOG LE LOG SERA DANS LE SCRIPT"

            #ON MET LE LOG DANS LE MEME DOSSIER QUE LE SCRIPT
            log_dir="$script_dir"

            #ON MET A JOUR LE CHEMIN COMPLET DU FICHIER DE LOG
            log_file="$script_dir/log_evt.log"

            #ON CREE LE FICHIER DANS LE DOSSIER DU SCRIPT
            touch "$log_file" 2>/dev/null
        else
            #LA CREATION A MARCHE DONC ON AFFICHE UN MESSAGE DE SUCCES
            echo "FICHIER DE LOG CREE AVEC SUCCES"
        fi
    fi

    #ON REGARDE SI LE DOSSIER INFO EXISTE DEJA
    if [ ! -d "$info_dir" ]; then
        #LE DOSSIER INFO NEXISTE PAS DONC ON LE CREE
        mkdir -p "$info_dir" 2>/dev/null
    fi
}
####################################################################
#FONCTION QUI ENREGISTRE UN EVENEMENT DANS LE FICHIER DE LOG
#LE FORMAT EST DATE HEURE UTILISATEUR EVENEMENT
sauvegarder_log() {
    #ON RECUPERE LE NOM DE L EVENEMENT PASSE EN ARGUMENT
    local evenement="$1"

    #ON DECLARE UNE VARIABLE POUR LA DATE
    local date_evt

    #ON DECLARE UNE VARIABLE POUR LHEURE
    local heure_evt

    #ON DECLARE UNE VARIABLE POUR LUTILISATEUR
    local utilisateur_evt

    #ON RECUPERE LA DATE DU JOUR AU FORMAT ANNEE MOIS JOUR
    date_evt=$(date "+%Y%m%d")

    #ON RECUPERE L HEURE ACTUELLE AU FORMAT HEURE MINUTE SECONDE
    heure_evt=$(date "+%H%M%S")

    #ON RECUPERE LE NOM DE L UTILISATEUR QUI LANCE LE SCRIPT
    utilisateur_evt="${USER:-inconnu}"

    #ON ECRIT LA LIGNE DANS LE FICHIER DE LOG
    echo "${date_evt}_${heure_evt}_${utilisateur_evt}_${evenement}" >> "$log_file" 2>/dev/null
}
####################################################################
#FONCTION QUI RECUPERE LES FICHIERS INFO ET LOG SUR UNE MACHINE LINUX
recuperer_info_linux() {
    #ON RECUPERE L ADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON RECUPERE LE NOM DE L UTILISATEUR PASSE EN ARGUMENT
    local utilisateur="$2"
    
    #ON REGARDE SI LE FICHIER DE LOG EXISTE SUR LA MACHINE LINUX
    if ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "test -f /tmp/log_evt.log" 2>/dev/null; then
        #LE FICHIER EXISTE DONC ON LE COPIE SUR LE SERVEUR
        scp -P $port_ssh -q -o stricthostkeychecking=no "${utilisateur}@${ip}:/tmp/log_evt.log" "/tmp/log_client_$$.log" 2>/dev/null

        #ON REGARDE SI LE FICHIER A BIEN ETE COPIE SUR LE SERVEUR
        if [ -f "/tmp/log_client_$$.log" ]; then
            #LE FICHIER A ETE COPIE DONC ON AJOUTE SON CONTENU AU LOG CENTRAL
            cat "/tmp/log_client_$$.log" >> "$log_file" 2>/dev/null

            #ON SUPPRIME LE FICHIER TEMPORAIRE SUR LE SERVEUR
            rm -f "/tmp/log_client_$$.log"
        fi

        #ON SUPPRIME LE FICHIER DE LOG SUR LA MACHINE LINUX
        ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "rm -f /tmp/log_evt.log" 2>/dev/null
    fi
    
    #ON REGARDE SI LE DOSSIER INFO EXISTE SUR LA MACHINE LINUX
    if ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "test -d /tmp/info" 2>/dev/null; then
        #LE DOSSIER EXISTE DONC ON COPIE TOUS LES FICHIERS SUR LE SERVEUR
        scp -P $port_ssh -q -o stricthostkeychecking=no "${utilisateur}@${ip}:/tmp/info/*" "$info_dir/" 2>/dev/null

        #ON SUPPRIME LE DOSSIER INFO SUR LA MACHINE LINUX
        ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "rm -rf /tmp/info" 2>/dev/null
    fi
}
####################################################################
#FONCTION QUI RECUPERE LES FICHIERS INFO ET LOG SUR UNE MACHINE WINDOWS
recuperer_info_windows() {
    #ON RECUPERE L ADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON RECUPERE LE NOM DE L UTILISATEUR PASSE EN ARGUMENT
    local utilisateur="$2"
    
    #ON REGARDE SI LE FICHIER DE LOG EXISTE DANS DOCUMENTS SUR WINDOWS
    if ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "cmd /c if exist %userprofile%\\Documents\\log_evt.log echo OK" 2>/dev/null | grep -q "OK"; then
        #LE FICHIER EXISTE DONC ON LE COPIE SUR LE SERVEUR
        scp -P $port_ssh -q -o stricthostkeychecking=no "${utilisateur}@${ip}:Documents/log_evt.log" "/tmp/log_client_$$.log" 2>/dev/null

        #ON REGARDE SI LE FICHIER A BIEN ETE COPIE SUR LE SERVEUR
        if [ -f "/tmp/log_client_$$.log" ]; then
            #LE FICHIER A ETE COPIE DONC ON AJOUTE SON CONTENU AU LOG CENTRAL
            cat "/tmp/log_client_$$.log" >> "$log_file" 2>/dev/null

            #ON SUPPRIME LE FICHIER TEMPORAIRE SUR LE SERVEUR
            rm -f "/tmp/log_client_$$.log"
        fi

        #ON SUPPRIME LE FICHIER DE LOG SUR LA MACHINE WINDOWS
        ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "cmd /c del /F /Q %userprofile%\\Documents\\log_evt.log" 2>/dev/null
    fi
    
    #ON REGARDE SI LE DOSSIER INFO EXISTE DANS DOCUMENTS SUR WINDOWS
    if ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "cmd /c if exist %userprofile%\\Documents\\info echo OK" 2>/dev/null | grep -q "OK"; then
        #LE DOSSIER EXISTE DONC ON COPIE TOUS LES FICHIERS SUR LE SERVEUR
        scp -P $port_ssh -q -r -o stricthostkeychecking=no "${utilisateur}@${ip}:Documents/info/*" "$info_dir/" 2>/dev/null

        #ON SUPPRIME LE DOSSIER INFO SUR LA MACHINE WINDOWS
        ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "cmd /c rmdir /S /Q %userprofile%\\Documents\\info" 2>/dev/null
    fi
}

###################################################################################
#        FONCTIONS POUR DETECTER  UTILISATEURS WINDOWS/SYSTEME/NOM DE MACHINE     #
###################################################################################
####################################################################
#FONCTION QUI CHERCHE QUEL UTILISATEUR WINDOWS PEUT SE CONNECTER EN SSH
#ON PASSE LADRESSE IP DE LA MACHINE EN ARGUMENT
trouver_utilisateur_windows() {
    #ON RECUPERE LADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON DECLARE UNE VARIABLE POUR STOCKER LE NOM DE LUTILISATEUR
    local utilisateur

    #ON PARCOURT CHAQUE UTILISATEUR DANS LA LISTE DES UTILISATEURS WINDOWS
    for utilisateur in "${utilisateurs_windows[@]}"; do

        #ON ESSAIE UNE CONNEXION SSH AVEC CET UTILISATEUR
        #SI LA MACHINE REPOND AVEC LE MOT WINDOWS ALORS LUTILISATEUR EST BON
        if timeout 3 ssh -p $port_ssh -o connecttimeout=2 -o stricthostkeychecking=no -o batchmode=yes "${utilisateur}@${ip}" "cmd /c echo Windows" 2>/dev/null | grep -qi "windows"; then

            #ON A TROUVE LE BON UTILISATEUR DONC ON AFFICHE SON NOM
            echo "$utilisateur"

            #ON SORT DE LA FONCTION AVEC LE CODE DE SUCCES
            return 0
        fi
    done

    #AUCUN UTILISATEUR NA MARCHE DONC ON AFFICHE UNE VALEUR VIDE
    echo ""

    #ON SORT DE LA FONCTION AVEC LE CODE D4ECHEC
    return 1
}
####################################################################
#FONCTION QUI DETERMINE LE SYSTEME DEXPLOITATION DE LA MACHINE
#ON REGARDE SI LADRESSE IP EST UNE MACHINE LINUX WINDOWS OU INCONNU
#ON PASSE LADRESSE IP EN ARGUMENT
detecter_systeme() {
    #ON RECUPERE LADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON DECLARE UNE VARIABLE POUR STOCKER LE NOM DE LUTILISATEUR WINDOWS
    local utilisateur_win

    #ON TESTE DABORD SI CEST UNE MACHINE LINUX AVEC *UNAME*
    if timeout 2 ssh -p $port_ssh -o connecttimeout=2 -o stricthostkeychecking=no -o batchmode=yes "${utilisateur_linux}@${ip}" "uname" 2>/dev/null | grep -qi linux; then
        #LA MACHINE A REPONDU *LINUX* DONC ON NOTE LINUX DANS LE TABLEAU
        type_os["$ip"]="linux"

        #ON SORT DE LA FONCTION AVEC LE CODE DE  SUCCES
        return 0
    fi

    #CE NEST PAS LINUX DONC ON TESTE WINDOWS EN CHERCHANT UN UTILISATEUR
    utilisateur_win=$(trouver_utilisateur_windows "$ip")

    #ON REGARDE SI ON A TROUVE UN UTILISATEUR WINDOWS QUI MARCHE
    if [ -n "$utilisateur_win" ]; then
        #ON A TROUVE UN UTILISATEUR DONC CEST UNE MACHINE WINDOWS
        type_os["$ip"]="windows"

        #ON GARDE LE NOM DE LUTILISATEUR WINDOWS POUR CETTE IP
        utilisateur_windows["$ip"]="$utilisateur_win"

        #ON SORT DE LA FONCTION AVEC LE CODE DE SUCCES
        return 0
    fi

    #ON NA TROUVE NI LINUX NI WINDOWS DONC LE SYSTEME EST INCONNU
    type_os["$ip"]="inconnu"

    #ON SORT DE LA FONCTION AVEC LE CODE ECHEC
    return 1
}
####################################################################
#FONCTION QUI RECUPERE LE NOM DE LA MACHINE A DISTANCE
#ON PASSE  ADRESSE IP EN ARGUMENT
recuperer_nom_machine() {
    #ON RECUPERE LADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON DECLARE UNE VARIABLE POUR STOCKER LE NOM DE LA MACHINE
    local nom=""

    #ON DECLARE UNE VARIABLE POUR STOCKER LE NOM DE LUTILISATEUR
    local utilisateur=""

    #ON REGARDE SI LE TYPE DU SYSTEME EST DEJA CONNU OU PAS
    if [ -z "${type_os[$ip]}" ]; then
        #LE TYPE NEST PAS CONNU DONC ON APPELLE LA FONCTION POUR LE TROUVER
        detecter_systeme "$ip"
    fi

    #ON CHOISIT LUTILISATEUR SELON LE TYPE DE SYSTEME TROUVE
    if [ "${type_os[$ip]}" = "windows" ]; then
        #CEST WINDOWS DONC ON PREND LUTILISATEUR WINDOWS ENREGISTRE
        utilisateur="${utilisateur_windows[$ip]}"

        #ON REGARDE SI LUTILISATEUR WINDOWS EST VIDE
        if [ -z "$utilisateur" ]; then
            #LUTILISATEUR EST VIDE DONC ON EN CHERCHE UN QUI MARCHE
            utilisateur=$(trouver_utilisateur_windows "$ip")

            #ON GARDE LUTILISATEUR TROUVE POUR CETTE IP
            utilisateur_windows["$ip"]="$utilisateur"
        fi
    else
        #CE NEST PAS WINDOWS DONC ON UTILISE LUTILISATEUR LINUX
        utilisateur="$utilisateur_linux"
    fi

    #ON DEMANDE LE NOM DE LA MACHINE AVEC LA COMMANDE *HOSTNAME* EN SSH
    nom=$(ssh -p $port_ssh -o connecttimeout=3 -o batchmode=yes -o loglevel=quiet "${utilisateur}@${ip}" "hostname" 2>/dev/null)

    #ON REGARDE SI LA COMMANDE A MARCHE ET SI LE NOM NEST PAS VIDE
    if [ $? -eq 0 ] && [ -n "$nom" ]; then

        #LA COMMANDE A MARCHE DONC ON ENLEVE LES RETOURS CHARIOT PPOUR WINDOWS
        noms_machines["$ip"]=$(echo "$nom" | tr -d '\r')

    else
        #LA COMMANDE NA PAS MARCHE DONC ON MET UN *?*
        noms_machines["$ip"]="?"
    fi
}

##################################################################################
#                     FONCTION POUR SCANNER LE RESEAU                            #
##################################################################################
#ON PING DE 5 A 30 POUR TROUVER LES MACHINES ALLUMEES AVEC LEUR OS ET LEUR NOM
scanner_reseau() {
    #ON VIDE LE TABLEAU DES ADRESSES IP
    liste_ip=()
    #ON VIDE LE TABLEAU DES NOMS DE MACHINES
    noms_machines=()
    #ON VIDE LE TABLEAU DES TYPES DE SYSTEMES
    type_os=()
    #ON VIDE LE FICHIER TEMPORAIRE DES MACHINES ACTIVES
    > "$fichier_temp"
    #ON VIDE LE FICHIER TEMPORAIRE DES NOMS DE MACHINES
    > "$fichier_noms"

    #ON PARCOURT TOUTES LES ADRESSES 
    for i in {5..30}; do
        #ON FABRIQUE LADRESSE IP COMPLETE AVEC LE NUMERO
        local ip="${ip_reseau}${i}"

        #ON LANCE LE PING EN ARRIERE PLAN POUR ALLER PLUS VITE
        (
            #ON ENVOIE UN SEUL PING AVEC UN DELAI MAXIMUM
            ping -c 1 -W "$delai_ping" "$ip" &>/dev/null

            #ON REGARDE SI LE PING A RECU UNE REPONSE
            if [ $? -eq 0 ]; then
                #LA MACHINE A REPONDU DONC ON AJOUTE SON IP DANS LE FICHIER
                echo "$ip" >> "$fichier_temp"
            fi
        ) &
    done

    #ON ATTEND QUE TOUS LES PINGS SE TERMINES
    wait

    #ON REGARDE SI LE FICHIER DES IP ACTIVES CONTIENT DES DONNEES
    if [ -s "$fichier_temp" ]; then
        #LE FICHIER NEST PAS VIDE DONC ON CHARGE LES IP DANS LE TABLEAU
        mapfile -t liste_ip < "$fichier_temp"

        #ON REGARDE SI ON CONNAIT DEJA LIP DU SERVEUR LOCAL
        if [ -z "$local_ip" ]; then
            #ON NE LA CONNAIT PAS DONC ON LA RECUPERE AVEC HOSTNAME
            local_ip=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep "^$ip_reseau" | head -n1)
        fi

        #ON REGARDE SI ON A BIEN RECUPERE LIP LOCALE
        if [ -n "$local_ip" ]; then
            #ON DECLARE UN TABLEAU POUR GARDER LES IP QUON AS FILTREE
            local liste_filtree=()

            #ON DECLARE UNE VARIABLE POUR LIP EN COURS
            local ip

            #ON PARCOURT TOUTES LES IP TROUVEES
            for ip in "${liste_ip[@]}"; do

                #ON REGARDE SI LIP EST DIFFERENTE DE LIP LOCALE
                if [ "$ip" != "$local_ip" ]; then
                    #LIP EST DIFFERENTE DONC ON LA GARDE DANS LA LISTE
                    liste_filtree+=("$ip")
                fi
            done

            #ON REMPLACE LA LISTE DES IP PAR LA LISTE FILTREE
            liste_ip=("${liste_filtree[@]}")
        fi

        #ON REGARDE SI LA LISTE DES IP EST VIDE APRES LE FILTRAGE
        if [ ${#liste_ip[@]} -eq 0 ]; then
            #LA LISTE EST VIDE DONC ON SUPPRIME LES FICHIERS TEMPORAIRES
            rm -f "$fichier_temp" "$fichier_noms"

            #ON SORT DE LA FONCTION CAR IL NY A PLUS DE MACHINE
            return 0
        fi

        #ON DECLARE UNE VARIABLE POUR LIP EN COURS
        local ip

        #ON PARCOURT CHAQUE IP POUR DETECTER LE SYSTEME ET LE NOM
        for ip in "${liste_ip[@]}"; do
            #ON LANCE LA DETECTION EN ARRIERE PLAN POUR ALLER PLUS VITE
            (
                #ON DETECTE LE SYSTEME DEXPLOITATION DE LA MACHINE
                detecter_systeme "$ip"

                #ON RECUPERE LE NOM DE LA MACHINE
                recuperer_nom_machine "$ip"

                #ON ENREGISTRE TOUTES LES INFOS DANS LE FICHIER TEMPORAIRE
                echo "$ip:${type_os[$ip]}:${noms_machines[$ip]}:${utilisateur_windows[$ip]}" >> "$fichier_noms"
            ) &
        done

        #ON ATTEND QUE TOUTES LES DETECTIONS SE TERMINEES
        wait

        #ON RECHARGE TOUTES LES INFOS EN MEMOIRE DEPUIS LE FICHIER
        while IFS=: read -r ip systeme nom utilisateur; do
            #ON MET LE TYPE DE SYSTEME DANS LE TABLEAU
            type_os["$ip"]="$systeme"

            #ON MET LE NOM DE LA MACHINE DANS LE TABLEAU
            noms_machines["$ip"]="$nom"

            #ON REGARDE SI LUTILISATEUR NEST PAS VIDE
            if [ -n "$utilisateur" ]; then
                #LUTILISATEUR NEST PAS VIDE DONC ON LE GARDE DANS LE TABLEAU
                utilisateur_windows["$ip"]="$utilisateur"
            fi
        done < "$fichier_noms"
    fi

    #SUPPRIME LES FICHIERS TEMPORAIRES
    rm -f "$fichier_temp" "$fichier_noms"
}

##################################################################################
#                   FONCTIONS DE CONNEXION AUX MACHINES                          #
##################################################################################
####################################################################
#FONCTION POUR SE CONNECTER A UNE MACHINE LINUX
#ON PASSE LADRESSE IP DE LA MACHINE EN ARGUMENT
connexion_machine_linux() {
    #ON RECUPERE LADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON RECUPERE LE NOM DE LA MACHINE DEPUIS LE TABLEAU
    local nom_machine="${noms_machines[$ip]}"

    #ON RECUPERE LE NOM DE LUTILISATEUR QUI LANCE LE SCRIPT
    local utilisateur_local="${USER:-inconnu}"

    #ON REGARDE SI LE SCRIPT LINUX EXISTE SUR LE SERVEUR
    if [ ! -f "$script_linux" ]; then
        #LE SCRIPT NEXISTE PAS DONC ON AFFICHE UNE ERREUR
        echo "ERREUR SCRIPT LINUX INTROUVABLE $script_linux"

        #ON ARRETE LE SCRIPT 
        exit 1
    fi

    #ON AFFICHE UN MESSAGE POUR DIRE QUON SE CONNECTE
    echo "CONNEXION A $ip LINUX" >/dev/null

    #LOG
    sauvegarder_log "Action_ConnexionSSH_${nom_machine}_${ip}"

    #ON COPIE LE SCRIPT LINUX SUR LA MACHINE DISTANTE DANS TMP
    scp -P $port_ssh -q -o stricthostkeychecking=no "$script_linux" "${utilisateur_linux}@${ip}:/tmp/scriptbash.sh"

    #ON REGARDE SI LA COPIE A MARCHE OU PAS
    if [ $? -ne 0 ]; then
        #LA COPIE NA PAS MARCHE DONC ON AFFICHE UNE ERREUR
        echo "ERREUR ECHEC DE COPIE DU SCRIPT LINUX"

        #ON ARRETE LE SCRIPT
        exit 1
    fi

    #ON SE CONNECTE EN SSH SUR LA MACHINE LINUX/ON ENLEVE LES RETOURS CHARIOT WINDOWS DU SCRIPT/ON REND LE SCRIPT EXECUTABLE/ON EXECUTE LE SCRIPT AVEC LE NOM DE LUTILISATEUR LOCAL/SUPPRIME LE SCRIPT APRES EXECUTION
    
    ssh -p $port_ssh -tt "${utilisateur_linux}@${ip}" "sed -i 's/\r$//' /tmp/scriptbash.sh && chmod +x /tmp/scriptbash.sh && /tmp/scriptbash.sh '$utilisateur_local'; rm -f /tmp/scriptbash.sh" 2>/dev/null 2>/dev/null

    #ON RECUPERE LES FICHIERS INFO ET LOG DEPUIS LA MACHINE LINUX
    recuperer_info_linux "$ip" "$utilisateur_linux"
}
####################################################################
#FONCTION POUR SE CONNECTER A UNE MACHINE WINDOWS
#ON PASSE LADRESSE IP DE LA MACHINE EN ARGUMENT
connexion_machine_windows() {
    #ON RECUPERE LADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON RECUPERE LE NOM DE LUTILISATEUR WINDOWS DEPUIS LE TABLEAU
    local utilisateur="${utilisateur_windows[$ip]}"

    #ON RECUPERE LE NOM DE LA MACHINE DEPUIS LE TABLEAU
    local nom_machine="${noms_machines[$ip]}"

    #ON RECUPERE LE NOM DE LUTILISATEUR QUI LANCE LE SCRIPT
    local utilisateur_local="${USER:-inconnu}"

    #ON REGARDE SI ON CONNAIT LUTILISATEUR WINDOWS POUR CETTE MACHINE
    if [ -z "$utilisateur" ]; then
        #ON NE CONNAIT PAS LUTILISATEUR DONC ON AFFICHE UN MESSAGE
        echo "RECHERCHE DE L'UTILISATEUR WINDOWS POUR $ip"

        #ON CHERCHE UN UTILISATEUR WINDOWS QUI MARCHE EN SSH
        utilisateur=$(trouver_utilisateur_windows "$ip")

        #ON REGARDE SI ON A TROUVE UN UTILISATEUR OU PAS
        if [ -z "$utilisateur" ]; then
            #ON NA TROUVE AUCUN UTILISATEUR DONC ON AFFICHE UNE ERREUR
            echo "ERREUR AUCUN UTILISATEUR WINDOWS NE FONCTIONNE EN SSH SUR $ip"

            #ON ARRETE LE SCRIPT 
            exit 1
        fi

        #ON GARDE LUTILISATEUR TROUVE DANS LE TABLEAU
        utilisateur_windows["$ip"]="$utilisateur"
    fi

    #ON REGARDE SI LE SCRIPT WINDOWS EXISTE SUR LE SERVEUR
    if [ ! -f "$script_windows" ]; then
        #LE SCRIPT NEXISTE PAS DONC ON AFFICHE UNE ERREUR
        echo "ERREUR SCRIPT WINDOWS INTROUVABLE $script_windows"

        #ON ARRETE LE SCRIPT COMPLETEMENT
        exit 1
    fi

    #ON AFFICHE UN MESSAGE POUR DIRE QU ON SE CONNECTE
    echo "CONNEXION A $ip WINDOWS UTILISATEUR $utilisateur" >/dev/null

    #ON ENREGISTRE LA CONNEXION DANS LE FICHIER DE LOG
    sauvegarder_log "Action_ConnexionSSH_${nom_machine}_${ip}"

    #ON SUPPRIME LANCIEN SCRIPT SUR WINDOWS SI IL EXISTAIT
    ssh -p $port_ssh -o batchmode=yes "${utilisateur}@${ip}" "cmd /c if exist %userprofile%\\Documents\\scriptpowershell.ps1 del /F /Q %userprofile%\\Documents\\scriptpowershell.ps1" 2>/dev/null

    #ON COPIE LE SCRIPT POWERSHELL DANS LE DOSSIER DOCUMENTS DE WINDOWS
    scp -P $port_ssh -q -o stricthostkeychecking=no "$script_windows" "${utilisateur}@${ip}:Documents/scriptpowershell.ps1"

    #ON REGARDE SI LA COPIE A MARCHE OU PAS
    if [ $? -ne 0 ]; then
        #LA COPIE NA PAS MARCHE DONC ON AFFICHE UNE ERREUR
        echo "ERREUR ECHEC DU TRANSFERT DU SCRIPT WINDOWS"

        #ON AFFICHE UN CONSEIL POUR AIDER LUTILISATEUR
        echo "VERIFIEZ LES DROITS DE L'UTILISATEUR WINDOWS"

        #ON ARRETE LE SCRIPT 
        exit 1
    fi

    #ON SE CONNECTE EN SSH SUR LA MACHINE WINDOWS/ON EXECUTE LE SCRIPT POWERSHELL AVEC LE NOM DE LUTILISATEUR LOCAL/SUPPRIME LE SCRIPT APRES EXECUTION

    ssh -p $port_ssh -tt "${utilisateur}@${ip}" "powershell -executionpolicy bypass -file %userprofile%\\Documents\\scriptpowershell.ps1 -UtilisateurLocal '$utilisateur_local' && del /F /Q %userprofile%\\Documents\\scriptpowershell.ps1" 2>/dev/null

    #ON RECUPERE LES FICHIERS INFO ET LOG DEPUIS LA MACHINE WINDOWS
    recuperer_info_windows "$ip" "$utilisateur"
}
####################################################################
#FONCTION POUR SE CONNECTER A UNE MACHINE
#ON PASSE LADRESSE IP DE LA MACHINE EN ARGUMENT
connexion_machine() {
    #ON RECUPERE LADRESSE IP DE LA MACHINE PASSEE EN ARGUMENT
    local ip="$1"

    #ON RECUPERE LE TYPE DE SYSTEME DEPUIS LE TABLEAU
    local systeme="${type_os[$ip]}"

    #ON REGARDE SI ON CONNAIT LE TYPE DE SYSTEME OU PAS
    if [ -z "$systeme" ]; then
        #ON NE CONNAIT PAS LE SYSTEME DONC ON ESSAIE DE LE DETECTER
        detecter_systeme "$ip"

        #ON RECUPERE LE TYPE DE SYSTEME APRES LA DETECTION
        systeme="${type_os[$ip]}"
    fi

    #ON REGARDE SI LE SYSTEME EST LINUX
    if [ "$systeme" = "linux" ]; then
        #C EST LINUX DONC ON APPELLE LA FONCTION DE CONNEXION LINUX
        connexion_machine_linux "$ip"

        #ON SORT DE LA FONCTION AVEC LE CODE DE  SUCCES
        return 0

    #ON REGARDE SI LE SYSTEME EST WINDOWS
    elif [ "$systeme" = "windows" ]; then
        #C EST WINDOWS DONC ON APPELLE LA FONCTION DE CONNEXION WINDOWS
        connexion_machine_windows "$ip"

        #ON SORT DE LA FONCTION AVEC LE CODE DE SUCCES
        return 0

    else
        #LE SYSTEME NEST PAS RECONNU DONC ON NE PEUT PAS SE CONNECTER/ON NE QUITTE PAS LE SCRIPT PRINCIPAL/SORT DE LA FONCTION AVEC LE CODE ECHEC
        return 1
    fi
}

##################################################################################
#                            MENU PRINCIPAL                                      #
##################################################################################
#COULEURS ENTETE
BLEU='\e[34m'
BLANC='\e[97m'
ROUGE='\e[31m'
ROSE='\e[95m'
RESET='\e[0m'
####################################################################
#FONCTION QUI AFFICHE LE MENU PRINCIPAL 
menu_principal() {
    # BOUCLE POUR AFFICHER LE MENU
    while true; do
        
        clear

        #BANNIERE BLEU-BLANC-ROUGE
        printf "%b\n" "${BLEU}####################${BLANC}##############${ROUGE}####################${RESET}"
        printf "%b\n" "${BLEU}#${RESET}                  ${BLANC}SCRIPT_PRINCIPAL${RESET}                  ${ROUGE}#${RESET}"
        printf "%b\n" "${BLEU}#${RESET}                ${BLANC}$date_actuelle|$heure_actuelle${RESET}                 ${ROUGE}#${RESET}"
        printf "%b\n" "${BLEU}#${RESET}                  ${BLANC}WILD_CODE_SCHOOL${RESET}                  ${ROUGE}#${RESET}"
        printf "%b\n" "${BLEU}#${RESET}              ${BLANC}SCRIPT_BY:ANIS|FRED|EROS${RESET}              ${ROUGE}#${RESET}"
        printf "%b\n" "${BLEU}####################${BLANC}##############${ROUGE}####################${RESET}"
        echo ""

        #OPTIONS DU MENU
        echo "1.SE CONNECTER A UNE MACHINE"
        echo "Q.QUITTER"
        echo "___________________________"
        echo ""


        echo -n "CHOISISSEZ UNE OPTION [1 OU Q]: "

        #POSITION DU CURSEUR
        tput sc

        echo ""
        echo ""
        echo -e "${ROSE}\$\$\\      \$\$\\ \$\$\$\$\$\$\\ \$\$\\       \$\$\$\$\$\$\$\\  \$\$\$\$\$\$\$\$\\ \$\$\$\$\$\$\$\\  ${RESET}"
        echo -e "${ROSE}\$\$ | \$\\  \$\$ |\\_\$\$  _|\$\$ |      \$\$  __\$\$\\ \$\$  _____|\$\$  __\$\$\\ ${RESET}"
        echo -e "${ROSE}\$\$ |\$\$\$\\ \$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$ |      \$\$ |  \$\$ |${RESET}"
        echo -e "${ROSE}\$\$ \$\$ \$\$\\\$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$\$\$\$\\    \$\$\$\$\$\$\$  |${RESET}"
        echo -e "${ROSE}\$\$\$\$  _\$\$\$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$  __|   \$\$  __\$\$< ${RESET}"
        echo -e "${ROSE}\$\$\$  / \\\$\$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$ |      \$\$ |  \$\$ |${RESET}"
        echo -e "${ROSE}\$\$  /   \\\$\$ |\$\$\$\$\$\$\\ \$\$\$\$\$\$\$\$\\ \$\$\$\$\$\$\$  |\$\$\$\$\$\$\$\$\\ \$\$ |  \$\$ |${RESET}"
        echo -e "${ROSE}\\__/     \\__|\\______|\\________|\\_______/ \\________|\\__|  \\__|${RESET}"
        echo -e "${ROSE}            W I L D   C O D E   S C H O O L${RESET}"

        #POSITION DU CURSEUR 
        tput rc

        #CHOIX DE LUTILISATEUR
        read choix

        #QUEL CHOIX LUTILISATEUR A FAIT
        case "$choix" in
            1)
                #LOG
                sauvegarder_log "Navigation_MenuConnexion"
                
                #MESSAGE PENDANT LE SCAN DU RESEAU
                echo ""
                echo "SCAN DU RESEAU EN COURS..."

                #SCAN DU RESEAU POUR TROUVER LES MACHINES
                scanner_reseau 2>/dev/null

                #ON REGARDE SI ON A TROUVE AU MOINS UNE MACHINE
                if [ ${#liste_ip[@]} -gt 0 ]; then

                    #BOUCLE POUR CHOISIR UNE MACHINE
                    while true; do
                        
                        clear

                        #BANNIERE BLEU-BLANC-ROUGE
                        printf "%b\n" "${BLEU}####################${BLANC}##############${ROUGE}####################${RESET}"
                        printf "%b\n" "${BLEU}#${RESET}                  ${BLANC}SCRIPT_PRINCIPAL${RESET}                  ${ROUGE}#${RESET}"
                        printf "%b\n" "${BLEU}#${RESET}                ${BLANC}$date_actuelle|$heure_actuelle${RESET}                 ${ROUGE}#${RESET}"
                        printf "%b\n" "${BLEU}#${RESET}                  ${BLANC}WILD_CODE_SCHOOL${RESET}                  ${ROUGE}#${RESET}"
                        printf "%b\n" "${BLEU}#${RESET}              ${BLANC}SCRIPT_BY:ANIS|FRED|EROS${RESET}              ${ROUGE}#${RESET}"
                        printf "%b\n" "${BLEU}####################${BLANC}##############${ROUGE}####################${RESET}"
                        echo ""

                        #TITRE 
                        echo "MACHINES DISPONIBLES :"
                        echo ""

                        #VARIABLE POUR LE COMPTEUR
                        local i

                        #ON PARCOURT CHAQUE MACHINE TROUVEE
                        for i in "${!liste_ip[@]}"; do
                            #ON RECUPERE LADRESSE IP DE LA MACHINE
                            ip="${liste_ip[$i]}"

                            #ON RECUPERE LE NOM DE LA MACHINE
                            nom="${noms_machines[$ip]}"

                            #ON AFFICHE LE NUMERO IP ET LE NOM DE LA MACHINE
                            echo -e "  $((i+1)).\t$ip\t$nom"
                        done

                        #ON AFFICHE LOPTION POUR QUITTER
                        echo "  Q.QUITTER"
                        echo ""

                        #ON CALCULE LE NOMBRE MAXIMUM DE MACHINES
                        local max="${#liste_ip[@]}"

                        #ON DECLARE UNE VARIABLE POUR LA PLAGE DE CHOIX
                        local plage

                        #ON REGARDE SI IL YA UNE SEULE MACHINE OU PLUSIEURS
                        if [ "$max" -eq 1 ]; then
                            #IL YA UNE SEULE MACHINE DONC LA PLAGE EST 1
                            plage="1"
                        else
                            #IL YA PLUSIEURS MACHINES DONC LA PLAGE VA DE 1 AU MAXX
                            plage="1-$max"
                        fi
                        
                        echo -n "CHOISISSEZ UNE OPTION [$plage OU Q]: "

                        #POSITION DU CURSEUR
                        tput sc
                        
                        echo ""
                        echo ""
                        echo -e "${ROSE}\$\$\\      \$\$\\ \$\$\$\$\$\$\\ \$\$\\       \$\$\$\$\$\$\$\\  \$\$\$\$\$\$\$\$\\ \$\$\$\$\$\$\$\\  ${RESET}"
                        echo -e "${ROSE}\$\$ | \$\\  \$\$ |\\_\$\$  _|\$\$ |      \$\$  __\$\$\\ \$\$  _____|\$\$  __\$\$\\ ${RESET}"
                        echo -e "${ROSE}\$\$ |\$\$\$\\ \$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$ |      \$\$ |  \$\$ |${RESET}"
                        echo -e "${ROSE}\$\$ \$\$ \$\$\\\$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$\$\$\$\\    \$\$\$\$\$\$\$  |${RESET}"
                        echo -e "${ROSE}\$\$\$\$  _\$\$\$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$  __|   \$\$  __\$\$< ${RESET}"
                        echo -e "${ROSE}\$\$\$  / \\\$\$\$ |  \$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$ |      \$\$ |  \$\$ |${RESET}"
                        echo -e "${ROSE}\$\$  /   \\\$\$ |\$\$\$\$\$\$\\ \$\$\$\$\$\$\$\$\\ \$\$\$\$\$\$\$  |\$\$\$\$\$\$\$\$\\ \$\$ |  \$\$ |${RESET}"
                        echo -e "${ROSE}\\__/     \\__|\\______|\\________|\\_______/ \\________|\\__|  \\__|${RESET}"
                        echo -e "${ROSE}            W I L D   C O D E   S C H O O L${RESET}"

                        #POSITION DU CURSEUR
                        tput rc

                        #CHOIX DE LUTILISATEUR
                        read selection

                        #ON REGARDE SI LUTILISATEUR A ENTRE UN NUMERO VALIDE
                        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#liste_ip[@]} ]; then

                            #ON RECUPERE LADRESSE IP DE LA MACHINE CHOISIE
                            ip_cible="${liste_ip[$((selection-1))]}"

                            #ON ESSAIE DE SE CONNECTER A LA MACHINE
                            if connexion_machine "$ip_cible"; then
                                #LA CONNEXION A MARCHE DONC ON SORT DU MENU DES MACHINES
                                break
                            fi

                        #ON REGARDE SI LUTILISATEUR A CHOISI Q POUR QUITTER
                        elif [ "$selection" = "Q" ] || [ "$selection" = "q" ]; then
                            #LOG
                            sauvegarder_log "Navigation_Retour"

                            #SORT DU MENU DES MACHINES
                            break
                        else
                            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
                            echo ""
                            echo "CHOIX INVALIDE"

                            #UNE SECONDE AVANT DE REAFFICHER LE MENU
                            sleep 1
                        fi

                    done

                else
                    #AUCUNE MACHINE NA ETE TROUVEE SUR LE RESEAU
                    echo ""

                    #ON AFFICHE UN MESSAGE POUR PREVENIR LUTILISATEUR
                    echo "AUCUNE MACHINE TROUVEE SUR LE RESEAU"

                    #ON AFFICHE UN MESSAGE DE RETOUR
                    echo "RETOUR AU MENU"

                    #UNE SECONDE AVANT DE REVENIR AU MENU
                    sleep 1
                fi
                ;;
            Q|q)
                #LOG
                sauvegarder_log "EndScript"

                echo ""
                echo "A BIENTOT WILDER!"

                #ON QUITTE LE SCRIPT 
                exit 0
                ;;
            *)
                #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
                echo ""
                echo "CHOIX INVALIDE"

                #UNE SECONDE AVANT DE REAFFICHER LE MENU
                sleep 1
                ;;
        esac
    done
}
##################################################################################
#DEMARRAGE DU SCRIPT PRINCIPAL
##################################################################################

#ON PREPARE LE FICHIER DE LOG ET LE DOSSIER INFO
initialiser_journal

#LOG
sauvegarder_log "StartScript"

#ON REGARDE SI LE SCRIPT LINUX EXISTE SUR LE SERVEUR
if [ ! -f "$script_linux" ]; then
    #LE SCRIPT NEXISTE PAS DONC ON AFFICHE UN AVERTISSEMENT
    echo "ATTENTION SCRIPT LINUX INTROUVABLE $script_linux"
fi

#ON REGARDE SI LE SCRIPT WINDOWS EXISTE SUR LE SERVEUR
if [ ! -f "$script_windows" ]; then
    #LE SCRIPT NEXISTE PAS DONC ON AFFICHE UN AVERTISSEMENT
    echo "ATTENTION SCRIPT WINDOWS INTROUVABLE $script_windows"
fi

#MENU PRINCIPAL QUI GERE TOUT LE SCRIPT
menu_principal