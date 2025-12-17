!/bin/bash

##################################################################
#                     SCRIPT_LINUX                               #
#                 SCRIPT_BY ANIS FRED EROS                       #
#                     WILD_CODE_SCHOOL                           #
#                      24/11/2025                                #
##################################################################

#################################################################
#   DECLARATIONS VARIABLE & CONFIGURATION DE LA JOURNALISATION  #
#################################################################

# EMPLACEMENT DOSSIER LOG TEMPORAIRE
log_dir="/tmp"

# EMPLACEMENT FICHIER DE LOG
log_file="$log_dir/log_evt.log"

# EMPLACEMENT DOSSIER INFO TEMPORAIRE
info_dir="/tmp/info"

# ON RECUPERE LE NOM DE LA MACHINE, DE L'UTILISATEUR SUR CETTE MACHINE, LE NOM DE L'UTILISATEUR QUI A LANCE LE SCRIPT PRINCIPAL : CE NOM PASSE EN ARGUMENT QUAND ON LANCE LE SCRIPT.
nom_machine=$(hostname)
utilisateur_distant="${USER:-inconnu}"
utilisateur_local="${1:-$utilisateur_distant}"

# IDENTIFIANT DE LA SESSION ACTUELLE
session_id=$(date "+%Y%m%d_%H%M%S")

# VALEUR DU MOT DE PASSE ADMIN
MOT_DE_PASSE_ADMIN=""

# COULEURS POUR L'AFFICHAGE
VERT='\e[32m'
GRIS='\e[90m'
BLEU='\e[34m'
BLANC='\e[97m'
ROUGE='\e[31m'
RESET='\e[0m'


####################################################################
#                     FONCTIONS DE JOURNALISATION                  #
####################################################################

#FONCTION QUI PREPARE LE FICHIER DE LOG ET LE DOSSIER INFO
initialiser_journal() {
    # ON CREE LE FICHIER DE LOG DANS LE DOSSIER TMP
    touch "$log_file" 2>/dev/null
    
    # ON REGARDE SI LE DOSSIER INFO EXISTE DEJA
    if [ ! -d "$info_dir" ]; then
        #LE DOSSIER INFO NEXISTE PAS DONC ON LE CREE
        mkdir -p "$info_dir" 2>/dev/null
    fi
}


#FONCTION QUI ENREGISTRE UN EVENEMENT DANS LE FICHIER DE LOG
sauvegarder_log() {
    # ON RECUPERE LE NOM DE L EVENEMENT PASSE EN ARGUMENT
    local evenement="$1"

    # ON DECLARE UNE VARIABLE POUR LA DATE
    local date_evt

    # ON DECLARE UNE VARIABLE POUR L HEURE
    local heure_evt

    # ON RECUPERE LA DATE DU JOUR AU FORMAT ANNEE MOIS JOUR
    date_evt=$(date "+%Y%m%d")

    # ON RECUPERE L HEURE ACTUELLE AU FORMAT HEURE MINUTE SECONDE
    heure_evt=$(date "+%H%M%S")

    # ON ECRIT LA LIGNE DANS LE FICHIER DE LOG
    echo "${date_evt}_${heure_evt}_${utilisateur_local}_${utilisateur_distant}_${nom_machine}_${evenement}" >> "$log_file" 2>/dev/null
}

#FONCTION QUI ENREGISTRE DES INFORMATIONS DANS UN FICHIER
sauvegarder_info() {
    # ON RECUPERE LE CONTENU A ENREGISTRER PASSE EN ARGUMENT
    local contenu="$1"

    # ON DECLARE UNE VARIABLE POUR LE CHEMIN DU FICHIER
    local fichier_info

    # ON FABRIQUE LE NOM DU FICHIER AVEC LE NOM DE LA MACHINE ET LA SESSION
    fichier_info="$info_dir/info_${nom_machine}_${utilisateur_distant}_${session_id}.txt"

    # ON REGARDE SI LE DOSSIER INFO EXISTE DEJA
    if [ ! -d "$info_dir" ]; then
        # LE DOSSIER INFO NEXISTE PAS DONC ON LE CREE
        mkdir -p "$info_dir" 2>/dev/null
    fi

    # ON ECRIT LE CONTENU DANS LE FICHIER
    echo "$contenu" >> "$fichier_info" 2>/dev/null
}

####################################################################
#                  MOT DE PASSE ADMINISTRATEUR                     #
####################################################################
#FONCTION QUI DEMANDE LE MOT DE PASSE ADMIN POUR LES ACTIONS SENSIBLES
verifier_mot_de_passe_admin() {
    #ON RECUPERE LE NOM DE LACTION PASSEE EN ARGUMENT
    local action="$1"
    
    echo ""
    #NOM DE LACTION SENSIBLE
    echo "=== ACTION SENSIBLE : $action ==="
    echo ""
    #ON DEMANDE LE MOT DE PASSE SANS L AFFICHER A L ECRAN
    read -s -p "MOT DE PASSE ADMINISTRATEUR: " mdp
    echo ""
    
    #ON VERIFIE LE MOT DE PASSE 
    echo "$mdp" | su -c "true" "$USER" 2>/dev/null
    #ON REGARDE SI LA COMMANDE A MARCHE OU PAS
    if [ $? -eq 0 ]; then
        #LE MOT DE PASSE EST BON DONC ON LE GARDE EN MEMOIRE
        MOT_DE_PASSE_ADMIN="$mdp"
        #CODE SUCCES
        return 0
    else
        #LE MOT DE PASSE EST PASBON  DONC ON AFFICHE UNE ERREUR
        echo ""
        echo -e "${ROUGE}MOT DE PASSE INCORRECT${RESET}"
        echo ""
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        #CODE ECHEC
        return 1
    fi
}

####################################################################
#                          FONCTION ENTETE                         #
####################################################################
#FONCTION QUI AFFICHE LENTETE AVEC NOM MACHINE + IP
afficher_entete() {
    
    clear

    #ON RECUPERE LE NOM DE LA MACHINE
    NomMachine=$(hostname)

    #ON RECUPERE L ADRESSE IP QUI COMMENCE PAR 172.16.20
    AdresseIP=$(hostname -I | tr ' ' '\n' | grep "^172.16.20" | head -n1)

    #ON REGARDE SI ON A TROUVE UNE ADRESSE IP
    if [ -z "$AdresseIP" ]; then
        #ON NA PAS TROUVE DONC ON PREND LA PREMIERE IP DISPONIBLE
        AdresseIP=$(hostname -I | cut -d' ' -f1)
    fi

    #BANNIERE BLEU-BLANC-ROUGE
    echo -e "${BLEU}####################${BLANC}##############${ROUGE}####################${RESET}"
    echo -e "${BLEU}#${RESET}                      ${BLANC}$NomMachine${RESET}                      ${ROUGE}#${RESET}"
    echo -e "${BLEU}#${RESET}                    ${BLANC}$AdresseIP${RESET}                    ${ROUGE}#${RESET}"
    echo -e "${BLEU}####################${BLANC}##############${ROUGE}####################${RESET}"
    echo ""
}

####################################################################
#                 FONCTION AFFICHER UTILISATEURS                   #
####################################################################
#FONCTION QUI AFFICHE LA LISTE DES UTILISATEURS LOCAUX
afficher_utilisateurs_locaux() {
    #TITRE
    echo "  UTILISATEURS LOCAUX"

    echo ""

    #ON LIT LE FICHIER PASSWD ET ON GARDE SEULEMENT LES UTILISATEURS AVEC UN HOME
    cat /etc/passwd | grep "/home"

    echo ""
}

####################################################################
#                        FONCTIONS REPERTOIRES                     #
####################################################################
###############################################################
#FONCTION POUR CREE UN NOUVEAU REPERTOIRE
creer_repertoire() {
    #ENTETE
    afficher_entete
            #TITRE DE LA FONCTION
            echo "  CREATION DE REPERTOIRE"

            echo ""
            #ON DEMANDE LE CHEMIN DU REPERTOIRE A CREER
            read -p "CHEMIN COMPLET DU REPERTOIRE A CREER (Q POUR QUITTER): " Chemin
        
        #ON VERIFIE SI L'UTILISATEUR VEUT QUITTER
        if [ "$Chemin" = "q" ] || [ "$Chemin" = "Q" ]; then
            #LOG
            sauvegarder_log "Navigation_Retour"

            menu_repertoires
        return
    fi
        
        #ON VERIFIE SI LE CHEMIN EST VIDE
        if [ -z "$Chemin" ]; then
            #LE CHEMIN EST VIDE ALORS ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHEMIN NON SPECIFIE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        
        creer_repertoire
        return
    fi
    
        #ON VERIFIE SI LE REPERTOIRE EXISTE DEJA
        if [ -d "$Chemin" ]; then
            #LE REPERTOIRE EXISTE DEJA DONC ON AFFICHE UN MESSAGE
            echo -e "${GRIS}LE REPERTOIRE EXISTE DEJA${RESET}"
        
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

            creer_repertoire
            return
    fi
    
        #ON DEMANDE CONFIRMATION AVANT DE CREER
        read -p "CONFIRMER LA CREATION DE *$Chemin* ? [O/N]: " Confirm
    
        #ON REGARDE SI L'UTILISATEUR A CONFIRME
        if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
            #SI L'UTILISATEUR N'A PAS CONFIRME DONC ON ANNULE
            echo -e "${GRIS}CREATION ANNULEE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
                #ON RETOURNE AU MENU DES REPERTOIRES
                menu_repertoires
                return
    fi
    
        #ON CREE LE REPERTOIRE 
        mkdir -p "$Chemin" 2>/dev/null
            #ON VERIFIE QUE LE REPERTOIRE A ETE CREE
            if [ -d "$Chemin" ]; then
            #SI LE REPERTOIRE A ETE CREE ALORS ON AFFICHE UN MESSAGE DE SUCCES
            echo -e "${VERT}REPERTOIRE CREE AVEC SUCCES${RESET}"
            #LOG
            sauvegarder_log "Action_CreationRepertoire_$Chemin"
    else
            #LE REPERTOIRE N'A PAS ETE CREE ALORS ON AFFICHE UNE ERREUR
            echo -e "${ROUGE}IMPOSSIBLE DE CREER LE REPERTOIRE${RESET}"
    fi
    

        echo ""
        #ON DEMANDE SI L'UTILISATEUR VEUT CREER UN AUTRE REPERTOIRE
        read -p "VOULEZ-VOUS CREER UN AUTRE REPERTOIRE ? [O/N]: " Continuer
        
        #ON REGARDE SI L'UTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

        creer_repertoire
    else
        menu_repertoires
    fi
}

###############################################################
#FONCTION POUR SUPPRIMER UN REPERTOIRE
supprimer_repertoire() {
    #ENTETE
    afficher_entete
    
        #TITRE DE LA FONCTION
        echo "  SUPPRESSION DE REPERTOIRE"

        echo ""
    
            #ON DEMANDE LE CHEMIN DU REPERTOIRE A SUPPRIMER
            read -p "CHEMIN COMPLET DU REPERTOIRE A SUPPRIMER (Q POUR QUITTER): " Chemin
    
    #ON VERIFIE SI L'UTILISATEUR VEUT QUITTER 
    if [ "$Chemin" = "q" ] || [ "$Chemin" = "Q" ]; then
            #ON ENREGISTRE LE RETOUR DANS LE LOG
            sauvegarder_log "Navigation_Retour"
            menu_repertoires
            return
    fi
    
        #ON VERIFIE SI LE CHEMIN EST VIDE
    if [ -z "$Chemin" ]; then
            #LE CHEMIN EST VIDE ALORS ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHEMIN NON SPECIFIE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            supprimer_repertoire
        return
    fi
        
    #ON VERIFIE SI LE REPERTOIRE EXISTE
    if [ ! -d "$Chemin" ]; then
            #SI LE REPERTOIRE NEXISTE PAS ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}LE REPERTOIRE N'EXISTE PAS${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            supprimer_repertoire
        return
    fi
    
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR C'EST UNE ACTION SENSIBLE
    if ! verifier_mot_de_passe_admin "SUPPRIMER REPERTOIRE *$Chemin*"; then
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        supprimer_repertoire
        return
    fi
    
    #ON DEMANDE A L'UTILISATEUR CONFIRMATION AVANT SUPPRESSION
    read -p "CONFIRMER LA SUPPRESSION DE *$Chemin* ? [O/N]: " Confirm
    
    #ON VERIFIE SI L'UTILISATEUR A CONFIRME
        if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
            
            #L'UTILISATEUR N'A PAS CONFIRME DONC ON ANNULE
            echo -e "${GRIS}SUPPRESSION ANNULEE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        
            menu_repertoires
        return
    fi
    
    #ON SUPPRIME LE REPERTOIRE 
        echo "$MOT_DE_PASSE_ADMIN" | sudo -S rm -rf "$Chemin" 2>/dev/null
        
            #ON VERIFIE SI LE REPERTOIRE A ETE SUPPRIME
            if [ ! -d "$Chemin" ]; then
            #LE REPERTOIRE A ETE SUPPRIME ALORS ON AFFICHE UN MESSAGE DE SUCCES
            echo -e "${VERT}REPERTOIRE SUPPRIME AVEC SUCCES${RESET}"
                #LOG
                sauvegarder_log "Action_SuppressionRepertoire_$Chemin"
    else
        
            #LE REPERTOIRE N'A PAS ETE SUPPRIME ALORS ON AFFICHE UNE ERREUR
            echo -e "${ROUGE}IMPOSSIBLE DE SUPPRIMER LE REPERTOIRE${RESET}"
    fi
    

        echo ""
        #ON DEMANDE A L'UTILISATEUR SI IL VEUT SUPPRIMER UN AUTRE REPERTOIRE
        read -p "VOULEZ-VOUS SUPPRIMER UN AUTRE REPERTOIRE ? [O/N]: " Continuer
    
            #ON VERIFIE SI L'UTILISATEUR VEUT CONTINUER
            if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

                supprimer_repertoire
    else
        
                menu_repertoires
    fi
}
####################################################################
#                        FONCTIONS LOGICIELS                       #
####################################################################
###############################################################
#FONCTION QUI AFFICHE LES MISES A JOUR CRITIQUES
afficher_mises_a_jour_manquantes() {
    #TITRE
    afficher_entete
    #TITRE 
    echo "  MISES A JOUR CRITIQUES"
    echo ""
    
    #ENREGISTREMENT DANS LOG
    sauvegarder_log "Consultation_MisesAJourCritiques"
    
    #ON RECUPERE LA LISTE DES MISES A JOUR DE SECURITE
    liste_maj=$(apt-get -s upgrade 2>/dev/null | grep "^Inst" | grep -i "security" | awk '{print $2}')
    
    #SI LA LISTE EST VIDE ON VERIFIE AVEC UNE AUTRE METHODE
    if [ -z "$liste_maj" ]; then
        #ON ESSAIE AVEC LE DEPOT SECURITY
        liste_maj=$(apt list --upgradable 2>/dev/null | grep -E "security|Security" | cut -d'/' -f1)
    fi
    
        #SI TOUJOURS VIDE ON AFFICHE TOUTES LES MISES A JOUR DISPONIBLES
            if [ -z "$liste_maj" ]; then
        #ON RECUPERE LES PAQUETS QUI DOIT ETRE A JOUR
        liste_maj=$(apt list --upgradable 2>/dev/null | grep -v "En train de lister" | grep -v "Listing" | cut -d'/' -f1)
    fi
    
        #ON VERIFIE SI LA LISTE DES MISE A JOUR EST VIDE
        if [ -z "$liste_maj" ]; then
        #AUCUNE MISE A JOUR
        nb_maj=0
    
    else
        #ON COMPTE SEULEMENT LE NOMBRE DE MISES A JOUR
        nb_maj=$(echo "$liste_maj" | grep -v "^$" | wc -l)
    fi
    
        #ON REGARDE SI IL Y A DES MISES A JOUR OU PAS
        if [ "$nb_maj" -eq 0 ]; then
        
            #IL N'Y A PAS DE MISES A JOUR ALORS ON AFFICHE UN MESSAGE
            echo -e "${VERT}AUCUNE MISE A JOUR CRITIQUE DISPONIBLE${RESET}"
        
            #ON ENREGISTRE L'INFORMATION
            sauvegarder_info "=== MISES A JOUR CRITIQUES === $(date '+%Y-%m-%d %H:%M:%S') AUCUNE MISE A JOUR CRITIQUE"
    
    else
        
            #IL Y A DES MISES A JOUR DONC ON LES ENREGISTRE D'ABORD
            sauvegarder_info "=== MISES A JOUR CRITIQUES === $(date '+%Y-%m-%d %H:%M:%S') $liste_maj"
        
            #VERIFICATION DE LA TAILLE DE LA LISTE
            if [ "$nb_maj" -le 10 ]; then
                
                #LA LISTE EST PETITE DONC ON L'AFFICHE
                echo "$nb_maj MISE(S) A JOUR CRITIQUE(S) DISPONIBLE(S):"
                echo ""
                
                #ON AFFICHE LA LISTE
                echo "$liste_maj"
                echo ""
                
                #ON AFFICHE LE NOMBRE DE MISES A JOUR
                echo -e "${GRIS}$nb_maj MISES A JOUR ENREGISTREES${RESET}"
            else
                
                #LA LISTE EST GRANDE DONC ON AFFICHE JUSTE LE NOMBRE DE MISE A JOUR CRITIQUES
                echo -e "${GRIS}LISTE DES MISES A JOUR ENREGISTREE ($nb_maj MISES A JOUR CRITIQUES)${RESET}"
            fi
        fi

        
        echo ""
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        menu_logiciels
}

###############################################################
#FONCTION QUI AFFICHE LES APPLICATIONS INSTALLEES
afficher_applications_installees(){
        #ENTETE
        afficher_entete
        # LE TITRE
        echo "  APPLICATIONS INSTALLEES"
        echo ""
    
            #ON ENREGISTRE DANS "LOG"
            sauvegarder_log "Consultation_ApplicationsInstallees"
    
            #ON RECUPERE LA LISTE DES APPLICATIONS
            liste_apps=$(dpkg -l | grep "^ii" | awk '{print $2}' 2>/dev/null)
        
        #ON COMPTE LE NOMBRE D'APPLICATIONS
        nb_apps=$(echo "$liste_apps" | wc -l)
    
    #ON ENREGISTRE LA LISTE DANS LE FICHIER INFO
    sauvegarder_info "=== APPLICATIONS INSTALLEES === $(date '+%Y-%m-%d %H:%M:%S')
    $liste_apps"

            #VERIFICATION DE LA TAILLE DE LA LISTE
            if [ "$nb_apps" -le 10 ]; then
            
            #LA LISTE EST PETITE ALORS ON AFFICHE LA LISTE
            echo "$liste_apps"
            #MONTRER LE NOMBRE D'APPLICATIONS
            echo ""
            echo -e "${GRIS}($nb_apps APPLICATIONS ENREGISTREES)${RESET}"
    else
    
                #LA LISTE EST GRANDE DONC ON AFFICHE JUSTE LE NOMBRE
                echo -e "${GRIS}LISTE DES APPLICATIONS ENREGISTREE ($nb_apps APPLICATIONS)${RESET}"
    fi
            echo ""
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        menu_logiciels
}

####################################################################
#                   FONCTIONS SERVICES                             #
####################################################################
###############################################################
#FONCTION QUI AFFICHE LES SERVICES EN COURS
afficher_services_en_cours() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  SERVICES EN COURS D'EXECUTION"
    echo ""
    
    #LOG
    sauvegarder_log "Consultation_ServicesEnCours"
    
    #ON RECUPERE LA LISTE DES SERVICES EN COURS
    liste_services=$(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep ".service")
    
    #ON COMPTE LE NOMBRE DE LIGNES
    nb_lignes=$(echo "$liste_services" | wc -l)
    
    #FICHIER INFO
    sauvegarder_info "=== SERVICES EN COURS === $(date '+%Y-%m-%d %H:%M:%S')$liste_services"
    
    #VERIFIER SI LA LISTE EST PETITE OU GRANDE
    if [ "$nb_lignes" -le 10 ]; then
        
        #LA LISTE PETITE ALORS AFFICHER
        echo "$liste_services"
    else
        
        #SINON LISTE GRANDE ALORS ON AFFICHE SEULEMENT LE NOMBRE
        echo -e "${GRIS}LISTE DES SERVICES ENREGISTREE ($nb_lignes SERVICES)${RESET}"
    fi
        
    echo ""
    read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
    menu_services
}
####################################################################
#                        FONCTIONS RESEAU                          #
####################################################################
###############################################################
#FONCTION POUR  AFFICHER LES PORTS OUVERTS
afficher_ports_ouverts() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  PORTS OUVERTS"

    echo ""
    
    #LOG
    sauvegarder_log "Consultation_PortsOuverts"
    
    #ON RECUPERE LA LISTE DES PORTS OUVERTS 
    liste_ports=$(ss -tulnp 2>/dev/null | grep LISTEN)
    #NOMBRE DE LIGNES
    nb_lignes=$(echo "$liste_ports" | wc -l)
    
    #FICHIER INFO
    sauvegarder_info "=== PORTS OUVERTS === $(date '+%Y-%m-%d %H:%M:%S') $liste_ports"
    
    #ON REGARDE SI LA LISTE EST PETITE OU GRANDE
    if [ "$nb_lignes" -le 10 ]; then
        #PETIT ELISTE DONC ON LAFFICHE
        echo "$liste_ports"
    else
        #LA LISTE EST GRANDE DONC ON AFFICHE JUSTE LE NOMBRE
        echo -e "${GRIS}LISTE DES PORTS ENREGISTREE ($nb_lignes PORTS)${RESET}"
    fi
    
    echo ""
    read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

    menu_reseau
}

###############################################################
#FONCTION POUR AFFICHE LA CONFIGURATION IP
afficher_config_ip() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  CONFIGURATION IP"

    echo ""
    
    #LOG
    sauvegarder_log "Consultation_ConfigurationIP"
    
    #ON DECLARE UNE VARIABLE POUR STOCKER LA CONFIGURATION
    config_ip=""
    #ON PARCOURT CHAQUE INTERFACE RESEAU
    for iface in $(ls /sys/class/net/); do
        #ON RECUPERE LADRESSE IP DE LINTERFACE
        IP=$(ip -4 addr show $iface 2>/dev/null | grep "inet " | tr -s ' ' | cut -d' ' -f3)
        #ON REGARDE SI LINTERFACE A UNE ADRESSE IP
        if [ -n "$IP" ]; then
            #ON AJOUTE LINTERFACE ET L'IP A LA CONFIGURATION
            config_ip+="INTERFACE: $iface - IP: $IP"
        fi
    done
    
    #ON RECUPERE LADRESSE DE LA PASSERELLE
    Passerelle=$(ip route | grep default | tr -s ' ' | cut -d' ' -f3)
    #ON AJOUTE LA PASSERELLE A LA CONFIGURATION
    config_ip+="PASSERELLE: $Passerelle"
    
    #NOMBRE DE LIGNES
    nb_lignes=$(echo "$config_ip" | wc -l)
    
    #FICHIER INFO
    sauvegarder_info "=== CONFIGURATION IP === $(date '+%Y-%m-%d %H:%M:%S') $config_ip"
    
    #ON REGARDE SI LA CONFIGURATION EST PETITE OU GRANDE
    if [ "$nb_lignes" -le 10 ]; then
        # PETITE DONC ON LAFFICHE
        echo "$config_ip"
    else
        #GRANDE DONC ON AFFICHE JUSTE UN MESSAGE
        echo -e "${GRIS}CONFIGURATION IP ENREGISTREE${RESET}"
    fi
    
    echo ""
    read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

    menu_reseau
}

###############################################################
#FONCTION POUR ACTIVER LE PARE-FEU
activer_pare_feu() {
    #ENTETE
    afficher_entete
    #LOG
    sauvegarder_log "Navigation_MenuPareFeu"
    #TITRE 
    echo "  GESTION DU PARE-FEU"
    echo ""
    
    #ON AFFICHE LE STATUT ACTUEL DU PARE-FEU 
    echo "STATUT DU PARE-FEU :"
    #ON VERIFIE SI LE SERVICE UFW EST ACTIF
    if systemctl is-active --quiet ufw 2>/dev/null; then
        echo -e "${VERT}ACTIF${RESET}"
    else
        echo -e "${ROUGE}INACTIF${RESET}"
    fi
    echo ""
    
    #MENU
    echo "1. ACTIVER LE PARE-FEU"
    echo "Q. QUITTER"
    echo ""
    read -p "TAPEZ [1 OU Q]: " choix
    
    #ON CHECK LE CHOIX DE LUTILISATEUR
    case "$choix" in
        1)
            #ON DEMANDE LE MOT DE PASSE ADMIN POUR ACTIVER
            if ! verifier_mot_de_passe_admin "ACTIVER LE PARE-FEU"; then
                #SI LE MOT DE PASSE EST MAUVAIS ON RESTE DANS LE MENU PARE-FEU
                activer_pare_feu
                return
            fi
            
            #ON ACTIVE LE PARE-FEU 
            echo ""
            echo "$MOT_DE_PASSE_ADMIN" | sudo -S ufw --force enable 2>/dev/null
            #ON REGARDE SI LA COMMANDE FONCTION 
            if [ $? -eq 0 ]; then
                #LA COMMANDE A MARCHE DONC ON AFFICHE UN MESSAGE DE SUCCES
                echo -e "${VERT}PARE-FEU ACTIVE${RESET}"
                #LOG
                sauvegarder_log "Action_ActivationPareFeu"
            else
                #LA COMMANDE NA PAS MARCHE DONC ON AFFICHE UNE ERREUR
                echo -e "${ROUGE}IMPOSSIBLE D'ACTIVER LE PARE-FEU${RESET}"
            fi
            echo ""
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            #ON RESTE DANS LE MENU PARE-FEU
            activer_pare_feu
            ;;
        Q|q)
            #SI LUTILISATEUR VEUT QUITTER ON RETOURNE AU MENU RESEAU
            menu_reseau
            ;;
        *)
            #SI CHOIX INVALIDE ON RESTE DANS LE MENU PARE-FEU
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            sleep 1
            activer_pare_feu
            ;;
    esac
}
####################################################################
#                        FONCTIONS SYSTEME                         #
####################################################################
####################################################################
#FONCTION QUI AFFICHE LES INFORMATIONS SYSTEME
afficher_info_systeme() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  INFORMATIONS SYSTEME"
    echo ""
    
        #ENREGISTRER -> LOG
        sauvegarder_log "Consultation_InfoSysteme"
    
            #RECUPERE LE NOM DU SYSTEME 
            OsName=$(lsb_release -d 2>/dev/null | cut -f2)
            
            #RECUPERE LA VERSION DU SYSTEME
            OsVersion=$(lsb_release -r 2>/dev/null | cut -f2)
            
            #RECUPERE L'ARCHITECTURE DU SYSTEME
            OsArch=$(uname -m)
            
            #RECUPERE LA VERSION DU KERNEL
            Kernel=$(uname -r)
    
        #ON INITIALISE LES VARIABLES POUR LA MARQUE ET LE MODELE
        Fabricant="NON DISPONIBLE"
        Modele="NON DISPONIBLE"
        NumeroSerie="NON DISPONIBLE"
    
    #ON REGARDE SI LE FICHIER DU FABRICANT EXISTE
        if [ -f /sys/class/dmi/id/sys_vendor ]; then
        
        #ON RECUPERE LE NOM DU FABRICANT
        Fabricant=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
    fi
        
        #ON REGARDE SI LE FICHIER DU MODELE EXISTE
        if [ -f /sys/class/dmi/id/product_name ]; then
        #ON RECUPERE LE NOM DU MODELE
        Modele=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    fi
        
        #VERIFICATION SI LE FICHIER DU NUMERO DE SERIE EXISTE
        if [ -f /sys/class/dmi/id/product_serial ]; then
        #ON RECUPERE LE NUMERO DE SERIE
        NumeroSerie=$(cat /sys/class/dmi/id/product_serial 2>/dev/null)
    fi
    
    #ON FAIT LE TEXTE DES INFORMATIONS SYSTEME
    info_systeme="NOM: $OsName
                VERSION: $OsVersion
                ARCHITECTURE: $OsArch
                KERNEL: $Kernel
                FABRICANT: $Fabricant
                MODELE: $Modele
                NUMERO SERIE: $NumeroSerie"
    
    #FICHIER INFO
    sauvegarder_info "=== INFORMATIONS SYSTEME === $(date '+%Y-%m-%d %H:%M:%S') $info_systeme"
    
            #ON AFFICHE LES INFORMATIONS SYSTEME
            echo "NOM: $OsName"
            echo "VERSION: $OsVersion"
            echo "ARCHITECTURE: $OsArch"
            echo "KERNEL: $Kernel"
    
        #ON AFFICHE LE FABRICANT AVEC COULEUR SI ELLES NE SONT PAS DISPONIBLE
        if [ "$Fabricant" = "NON DISPONIBLE" ]; then
        
            echo -e "FABRICANT: ${GRIS}$Fabricant${RESET}"
        else
        
        echo "FABRICANT: $Fabricant"
        fi
    
        #ON AFFICHE LE MODELE  SI ELLES NE SONT PAS DISPONIBLE
        if [ "$Modele" = "NON DISPONIBLE" ]; then
        echo -e "MODELE: ${GRIS}$Modele${RESET}"
    else
        echo "MODELE: $Modele"
        fi
    
        #ON AFFICHE LE NUMERO DE SERIE AVEC COULEUR SI ELLES NE SONT PAS DISPONIBLE
            if [ "$NumeroSerie" = "NON DISPONIBLE" ]; then
            echo -e "NUMERO SERIE: ${GRIS}$NumeroSerie${RESET}"
        else
            
            echo "NUMERO SERIE: $NumeroSerie"
            fi
    
                echo ""
                read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
                menu_systeme
}

###############################################################
#FONCTION QUI AFFICHE L'UTILISATION DE LA RAM
afficher_utilisation_ram() {
    
    #ENTETE
    afficher_entete
    #TITRE DE LA FONCTION
    echo "  UTILISATION DE LA MEMOIRE RAM"
    echo ""
    
        #ON ENREGISTRE LA CONSULTATION DANS LE LOG
        sauvegarder_log "Consultation_UtilisationRAM"
    
    #ON PREND LES INFORMATIONS DE LA RAM
    ram_info=$(free -h)
    
        #ON COMPTE LE NOMBRE DE LIGNES
        nb_lignes=$(echo "$ram_info" | wc -l)
            
            #ENREGISTREMENT DANS INFO
            sauvegarder_info "=== UTILISATION RAM === $(date '+%Y-%m-%d %H:%M:%S') $ram_info"
    
            #ON VERIFIE LA TAILLE DES INFORMATIONS
            if [ "$nb_lignes" -le 10 ]; then
            
            #LES INFORMATIONS SONT PETITES ALORS ON LES AFFICHE
            echo "$ram_info"
    else
            
            #SINON LES INFORMATIONS SONT GRANDES ALORS ON AFFICHE JUSTE UN MESSAGE
            echo -e "${GRIS}UTILISATION RAM ENREGISTREE${RESET}"
    fi
    
            echo ""
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_systeme
}


####################################################################
#                         FONCTIONS CONTROLES                      #
####################################################################
###############################################################
redemarrer_machine() {
    # AFFICHAGE DE L'ENTETE
    afficher_entete
    echo "  REDEMARRAGE DE LA MACHINE"
    echo ""
    # DEMANDE DE CONFIRMATION AVANT REDEMARRAGE
    read -p "REDEMARRER LA MACHINE ? [O/N]: " Confirm1
    
    if [ "$Confirm1" != "O" ] && [ "$Confirm1" != "o" ]; then
        # L'UTILISATEUR NE CONFIRME PAS DONC ANNULATION DU REDEMARRAGE
        echo -e "${GRIS}REDEMARRAGE ANNULE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        # RETOUR AU MENU CONTROLES
        menu_controles
        return
    fi
    # DEMANDE DU MOT DE PASSE ADMINISTRATEUR
    read -p "CONFIRMER LE REDEMARRAGE ? [O/N]: " Confirm2
    
    if [ "$Confirm2" != "O" ] && [ "$Confirm2" != "o" ]; then
        # L'UTILISATEUR NE CONFIRME PAS DONC ANNULATION DU REDEMARRAGE
        echo -e "${GRIS}REDEMARRAGE ANNULE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        # RETOUR AU MENU CONTROLES
        menu_controles
        return
    fi
    echo ""
    echo -e "${GRIS}REDEMARRAGE EN COURS...${RESET}"
    # ENREGISTREMENT DU REDEMARRAGE DANS LES LOGS
    sauvegarder_log "Action_RedemarrageMachine"
    sleep 2
    sudo reboot
}

###############################################################
#FONCTION POUR EXECUTER UN SCRIPT
executer_script_distant() {
    afficher_entete
    echo "  EXECUTION D'UN SCRIPT"
    echo ""
    # DEMANDE DU CHEMIN DU SCRIPT A EXECUTER
    read -p "CHEMIN COMPLET DU SCRIPT A EXECUTER (Q POUR QUITTER): " CheminScript
    if [ "$CheminScript" = "q" ] || [ "$CheminScript" = "Q" ]; then
	    # SAUVEGARDE DE LA NAVIGATION DANS LES LOGS
        sauvegarder_log "Navigation_Retour"
        # RETOUR AU MENU CONTROLES
        menu_controles
        return
    fi
    # ON VERIFIE QUE LE CHEMIN N'EST PAS VIDE
    if [ -z "$CheminScript" ]; then
        echo -e "${ROUGE}CHEMIN NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        # SI LE CHEMIN EST VIDE, ON RELANCE LA FONCTION
        executer_script_distant
        return
    fi
    # ON VERIFIE QUE LE FICHIER EXISTE
    if [ ! -f "$CheminScript" ]; then
        # SI LE FICHIER N'EXISTE PAS, ON AFFICHE UN MESSAGE D'ERREUR
        echo -e "${ROUGE}LE FICHIER N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        executer_script_distant
        return
    fi
    
    # ACQUISITION DU MOT DE PASSE ADMINISTRATEUR
    if ! verifier_mot_de_passe_admin "EXECUTER SCRIPT *$CheminScript*"; then
        # MOT DE PASSE INCORRECT, ON RELANCE LA FONCTION
        executer_script_distant
        return
    fi
    
    # DEMANDE DE CONFIRMATION AVANT EXECUTION DU SCRIPT
    read -p "EXECUTER LE SCRIPT *$CheminScript* ? [O/N]: " Confirm
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        # ON NE CONFIRME PAS, ANNULATION DE L'EXECUTION
        echo -e "${GRIS}EXECUTION ANNULEE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
        # RETOUR AU MENU CONTROLES
        menu_controles
        return
    fi
    
    echo ""
    echo -e "${GRIS}EXECUTION DU SCRIPT EN COURS...${RESET}"
    echo ""
    # ENTRETIEN DE L'ACTION DANS LES LOGS
    sauvegarder_log "Action_ExecutionScript_$CheminScript"
    # EXECUTION DU SCRIPT AVEC ELEVATION DE PRIVILEGES
    echo "$MOT_DE_PASSE_ADMIN" | sudo -S bash "$CheminScript" 2>/dev/null

    echo ""
    echo -e "${VERT}SCRIPT EXECUTE${RESET}"
    echo ""
    # ON DEMANDE SI L'UTILISATEUR VEUT EXECUTER UN AUTRE SCRIPT
    read -p "VOULEZ-VOUS EXECUTER UN AUTRE SCRIPT ? [O/N]: " Continuer
    # SI OUI, RELANCE DE LA FONCTION
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then
        executer_script_distant
    else
        # RETOUR AU MENU CONTROLES
        menu_controles
    fi
}

###############################################################
#FONCTION POUR PRISE EN MAIN A DISTANCE
ouvrir_console_distante() {
    afficher_entete
    echo "  PRISE DE MAIN A DISTANCE (CLI)"
    echo ""
    echo -e "${GRIS}TAPEZ *EXIT* POUR REVENIR AU MENU${RESET}"
    echo ""
    # ON SAUVEGARDE L'ACTION D'OUVERTURE DANS LES LOGS
    sauvegarder_log "Action_OuvertureConsole"
    # ON LANCE UN NOUVEAU SHELL
    bash
    # ON SAUVEGARDE L'ACTION DE FERMETURE DANS LES LOGS
    sauvegarder_log "Action_FermetureConsole"
        # RETOUR AU MENU CONTROLES
    menu_controles
}
####################################################################
#                         FONCTIONS UTILISATEURS                   #
####################################################################
###############################################################
#FONCTION QUI AFFICHE LES PERMISSIONS DUN FICHIER OU DOSSIER
afficher_permissions_utilisateur() {
    #ENTETE
    afficher_entete
    #TITRE 
    echo "  DROITS ET PERMISSIONS SUR FICHIER"

    echo ""
    #ON DEMANDE LE CHEMIN DU FICHIER OU DOSSIER
    read -p "CHEMIN DU FICHIER OU DOSSIER (Q POUR QUITTER): " Chemin
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$Chemin" = "q" ] || [ "$Chemin" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"

        menu_utilisateurs
        return
    fi
    #ON REGARDE SI LE CHEMIN EST VIDE
    if [ -z "$Chemin" ]; then
        #LE CHEMIN EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}CHEMIN NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        afficher_permissions_utilisateur
        return
    fi
    #ON REGARDE SI LE CHEMIN EXISTE
    if [ ! -e "$Chemin" ]; then
        #LE CHEMIN NEXISTE PAS DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}LE CHEMIN *$Chemin* N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        afficher_permissions_utilisateur
        return
    fi
    
    #ON ENREGISTRE LA CONSULTATION DANS LE LOG
    sauvegarder_log "Consultation_Permissions_$Chemin"
    
    echo ""
    #TITRE
    echo "PERMISSIONS:"
    
    #ON REGARDE SI LE CHEMIN EST UN DOSSIER
    if [ -d "$Chemin" ]; then
        #CEST UN DOSSIER DONC ON LISTE SON CONTENU
        permissions=$(ls -lA "$Chemin")
    else
        #SI CEST UN FICHIER DONC ON AFFICHE SES PERMISSIONS
        permissions=$(ls -lA "$Chemin")
    fi
    
    #FICHIER INFO
    sauvegarder_info "=== PERMISSIONS === $(date '+%Y-%m-%d %H:%M:%S')CHEMIN: $Chemin $permissions"
    
    #ON AFFICHE LES PERMISSIONS
    echo "$permissions"
    
    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT CONSULTER UN AUTRE CHEMIN
    read -p "VOULEZ-VOUS CONSULTER UN AUTRE CHEMIN ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then
        afficher_permissions_utilisateur
    else
        menu_utilisateurs
    fi
}

###############################################################
#FONCTION POUR  AJOUTER UN UTILISATEUR A UN GROUPE
ajouter_utilisateur_groupe() {
    #ENTETE
    afficher_entete
    #TITRE 
    echo "  AJOUT A UN GROUPE"

    echo ""

    #ON LISTE LES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux

    #ON DEMANDE LE NOM DE LUTILISATEUR
    read -p "NOM D'UTILISATEUR (Q POUR QUITTER): " NomUtilisateur

    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"


        menu_utilisateurs
        return
    fi

    #ON REGARDE SI LE NOM EST VIDE
    if [ -z "$NomUtilisateur" ]; then
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"

        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        ajouter_utilisateur_groupe
        return
    fi

    #ON VERIFIE QUE  LUTILISATEUR EXISTE
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}L'UTILISATEUR \"$NomUtilisateur\" N'EXISTE PAS${RESET}"

        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        ajouter_utilisateur_groupe
        return
    fi

    echo ""

    #ON RECUPERE LES GROUPES CLASSIQUES
    groupes_classiques=$(cat /etc/group | grep -E "^(sudo|users|adm|cdrom|plugdev|netdev|audio|video|staff|games|docker|www-data):" | cut -d: -f1)

    #ON RECUPERE LES GROUPES UTILISATEURS AVEC UN GID > 1000
    groupes_utilisateurs=$(awk -F: '$3 >= 1000 {print $1}' /etc/group)

    #ON FAIT LA LISTE DES GROUPES DISPONIBLES
    groupes_dispo=$(echo -e "$groupes_classiques\n$groupes_utilisateurs" | sort -u | tr '\n' '|' | sed 's/|$//; s/|/ | /g')

    #ON AFFICHE LES GROUPES DISPONIBLES
    echo "GROUPES DISPONIBLES: $groupes_dispo"

    echo ""

    #ON DEMANDE LE NOM DU GROUPE
    read -p "NOM DU GROUPE (Q POUR QUITTER): " NomGroupe

    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomGroupe" = "q" ] || [ "$NomGroupe" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"

        menu_utilisateurs
        return
    fi

    #ON REGARDE SI LE NOM DU GROUPE EST VIDE
    if [ -z "$NomGroupe" ]; then
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM DU GROUPE NON SPECIFIE${RESET}"

        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        ajouter_utilisateur_groupe
        return
    fi

    #ON VERIFIE QUE LE GROUPE EXISTE
    if ! cat /etc/group | grep "^$NomGroupe:" > /dev/null; then
        #SI LE GROUPE NEXISTE PAS ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}LE GROUPE *$NomGroupe* N'EXISTE PAS${RESET}"

        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        ajouter_utilisateur_groupe
        return
    fi

    #ON DEMANDE CONFIRMATION AVANT DAJOUTER
    read -p "AJOUTER \"$NomUtilisateur\" AU GROUPE *$NomGroupe* ? [O/N]: " Confirm

    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        echo -e "${GRIS}AJOUT ANNULE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        menu_utilisateurs
        return
    fi

    #ON AJOUTE LUTILISATEUR AU GROUPE
    sudo usermod -aG "$NomGroupe" "$NomUtilisateur" 2>/dev/null

    #ON VERIFIE QUE LUTILISATEUR EST BIEN DANS LE GROUPE
    if id -nG "$NomUtilisateur" | grep -qw "$NomGroupe"; then
        #LUTILISATEUR EST DANS LE GROUPE DONC ON AFFICHE UN MESSAGE DE SUCCES
        echo ""
        echo -e "${VERT}UTILISATEUR \"$NomUtilisateur\" AJOUTE AU GROUPE *$NomGroupe*${RESET}"

        #LOG
        sauvegarder_log "Action_AjoutGroupe_${NomUtilisateur}_${NomGroupe}"
    else
        #LUTILISATEUR NEST PAS DANS LE GROUPE DONC ON AFFICHE UNE ERREUR
        echo -e "${ROUGE}IMPOSSIBLE D'AJOUTER L'UTILISATEUR AU GROUPE${RESET}"
    fi

    echo ""

    #ON DEMANDE SI LUTILISATEUR VEUT AJOUTER UN AUTRE COMPTE
    read -p "VOULEZ-VOUS AJOUTER UN AUTRE UTILISATEUR ? [O/N]: " Continuer

    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

        ajouter_utilisateur_groupe
    else
        menu_utilisateurs
    fi
}

###############################################################
#FONCTION POUR AJOUTE UN UTILISATEUR AU GROUPE SUDO
ajouter_utilisateur_groupe_admin() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  AJOUT AUX ADMINISTRATEURS *SUDO*"

    echo ""
    #ON LISTE LES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    read -p "NOM D'UTILISATEUR (Q POUR QUITTER): " NomUtilisateur
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"
        
        menu_utilisateurs
        return
    fi
    #ON REGARDE SI LE NOM EST VIDE
    if [ -z "$NomUtilisateur" ]; then
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        ajouter_utilisateur_groupe_admin
        return
    fi
    #ON VERIFIE QUE UTILISATEUR EXISTE
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #LUTILISATEUR NEXISTE PAS DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}L'UTILISATEUR \"$NomUtilisateur\" N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        ajouter_utilisateur_groupe_admin
        return
    fi
    
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if ! verifier_mot_de_passe_admin "AJOUTER \"$NomUtilisateur\" AU GROUPE *SUDO*"; then
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        ajouter_utilisateur_groupe_admin
        return
    fi
    
    #ON DEMANDE CONFIRMATION AVANT DAJOUTER
    read -p "AJOUTER \"$NomUtilisateur\" AU GROUPE *SUDO* ? [O/N]: " Confirm
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        echo -e "${GRIS}AJOUT ANNULE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        menu_utilisateurs
        return
    fi
    #ON AJOUTE LUTILISATEUR AU GROUPE SUDO 
    echo "$MOT_DE_PASSE_ADMIN" | sudo -S usermod -aG sudo "$NomUtilisateur" 2>/dev/null
    #ON REGARDE SI LUTILISATEUR EST BIEN DANS LE GROUPE SUDO
    if id -nG "$NomUtilisateur" | grep -qw "sudo"; then
        #LUTILISATEUR EST DANS LE GROUPE DONC ON AFFICHE UN MESSAGE DE SUCCES
        echo ""
        echo -e "${VERT}UTILISATEUR \"$NomUtilisateur\" AJOUTE AU GROUPE *SUDO*${RESET}"
        #LOG
        sauvegarder_log "Action_AjoutGroupeSudo_$NomUtilisateur"
    else
        #LUTILISATEUR NEST PAS DANS LE GROUPE DONC ON AFFICHE UNE ERREUR
        echo -e "${ROUGE}IMPOSSIBLE D'AJOUTER L'UTILISATEUR AU GROUPE${RESET}"
    fi

    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT AJOUTER UN AUTRE COMPTE
    read -p "VOULEZ-VOUS AJOUTER UN AUTRE UTILISATEUR ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then
        ajouter_utilisateur_groupe_admin
    else
        menu_utilisateurs
    fi
}

###############################################################
#FONCTION POUR CHANGER LE MOT DE PASSE DUN USER
modifier_mot_de_passe_utilisateur() {
    #ENTETE
    afficher_entete
    #TITRE 
    echo "  CHANGEMENT DE MOT DE PASSE"

    echo ""
    #ON LISTE DES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    read -p "NOM D'UTILISATEUR (Q POUR QUITTER): " NomUtilisateur
    #ON VERIFIE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"

        menu_utilisateurs
        return
    fi
    #ON REGARDE SI LE NOM EST VIDE
    if [ -z "$NomUtilisateur" ]; then
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE DERREUR
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        modifier_mot_de_passe_utilisateur
        return
    fi
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #LUTILISATEUR NEXISTE PAS DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}L'UTILISATEUR \"$NomUtilisateur\" N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        modifier_mot_de_passe_utilisateur
        return
    fi
    #ON DEMANDE CONFIRMATION AVANT DE MODIFIER
    read -p "CONFIRMER LE CHANGEMENT DE MOT DE PASSE POUR \"$NomUtilisateur\" ? [O/N]: " Confirm
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        echo -e "${GRIS}MODIFICATION ANNULEE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        menu_utilisateurs
        return
    fi

    echo ""
    #ON DEMANDE LE NOUVEAU MOT DE PASSE
    read -s -p "NOUVEAU MOT DE PASSE : " mot_de_passe
    echo ""
    read -s -p "CONFIRMEZ LE MOT DE PASSE : " mot_de_passe_confirm
    echo ""
    
    #ON VERIFIE QUE LES DEUX MOTS DE PASSE CORRESPONDENT
    if [ "$mot_de_passe" = "$mot_de_passe_confirm" ]; then
        #ON APPLIQUE LE MOT DE PASSE 
        echo "$NomUtilisateur:$mot_de_passe" | sudo chpasswd 2>/dev/null
        if [ $? -eq 0 ]; then
            #ON AFFICHE UN MESSAGE DE SUCCES
            echo ""
            echo -e "${VERT}MOT DE PASSE MODIFIE POUR \"$NomUtilisateur\"${RESET}"
            #LOG
            sauvegarder_log "Action_ModificationMotDePasse_$NomUtilisateur"
        else
            echo -e "${ROUGE}IMPOSSIBLE DE MODIFIER LE MOT DE PASSE${RESET}"
        fi
    else
        echo -e "${ROUGE}LES MOTS DE PASSE NE CORRESPONDENT PAS${RESET}"
    fi

    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT MODIFIER UN AUTRE MOT DE PASSE
    read -p "VOULEZ-VOUS MODIFIER UN AUTRE MOT DE PASSE ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then
        modifier_mot_de_passe_utilisateur
    else
        menu_utilisateurs
    fi
}

###############################################################
#FONCTION POUR  CREE UN NOUVEL UTILISATEUR
creer_utilisateur_local() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  CREATION D'UN COMPTE UTILISATEUR"

    echo ""
    #ON LISTE LES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux
    #ON DEMANDE LE NOM DU NOUVEL UTILISATEUR ?
    read -p "NOM DU NOUVEL UTILISATEUR (Q POUR QUITTER): " NomUtilisateur
    #SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"
        
        menu_utilisateurs
        return
    fi

    if [ -z "$NomUtilisateur" ]; then
        #SI LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        creer_utilisateur_local
        return
    fi
    #ON VERIFIE SI UTILISATEUR EXISTE DEJA
    if cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #LUTILISATEUR EXISTE DEJA DONC ON AFFICHE UN MESSAGE DERREUR
        echo -e "${GRIS}L'UTILISATEUR \"$NomUtilisateur\" EXISTE DEJA${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        creer_utilisateur_local
        return
    fi
    #ON DEMANDE CONFIRMATION AVANT DE CREER
    read -p "CONFIRMER LA CREATION DE \"$NomUtilisateur\" ? [O/N]: " Confirm
    #ON VERIFIE  SI LUTILISATEUR A CONFIRME
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        echo -e "${GRIS}CREATION ANNULEE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        menu_utilisateurs
        return
    fi
    
    #ON CREE LUTILISATEUR
    sudo useradd -m -s /bin/bash "$NomUtilisateur" 2>/dev/null
    
    #ON VERIFIE QUE  LUTILISATEUR A ETE CREE
    if cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #LUTILISATEUR A ETE CREE DONC ON AFFICHE UN MESSAGE DE SUCCES
        echo ""
        echo -e "${VERT}UTILISATEUR \"$NomUtilisateur\" CREE AVEC SUCCES${RESET}"
        echo ""
        #ON DEMANDE DE DEFINIR LE MOT DE PASSE
        read -s -p "DEFINISSEZ LE MOT DE PASSE : " mot_de_passe
        echo ""
        read -s -p "CONFIRMEZ LE MOT DE PASSE : " mot_de_passe_confirm
        echo ""
        
        #ON VERIFIE QUE LES DEUX MOTS DE PASSE CORRESPONDENT
        if [ "$mot_de_passe" = "$mot_de_passe_confirm" ]; then
            #ON APPLIQUE LE MOT DE PASSE
            echo "$NomUtilisateur:$mot_de_passe" | sudo chpasswd 2>/dev/null
            if [ $? -eq 0 ]; then
                #LOG
                sauvegarder_log "Action_CreationUtilisateur_$NomUtilisateur"
                #ON AFFICHE UN MESSAGE DE CONFIRMATION
                echo ""
                echo -e "${VERT}UTILISATEUR \"$NomUtilisateur\" PRET A SE CONNECTER${RESET}"
            else
                echo -e "${ROUGE}IMPOSSIBLE DE DEFINIR LE MOT DE PASSE${RESET}"
            fi
        else
            echo -e "${ROUGE}LES MOTS DE PASSE NE CORRESPONDENT PAS${RESET}"
        fi
    else
        #LUTILISATEUR NA PAS ETE CREE DONC ON AFFICHE UNE ERREUR
        echo -e "${ROUGE}IMPOSSIBLE DE CREER L'UTILISATEUR${RESET}"
    fi

    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT CREER UN AUTRE COMPTE
    read -p "VOULEZ-VOUS CREER UN AUTRE UTILISATEUR ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

        creer_utilisateur_local
    else

        menu_utilisateurs
    fi
}

###############################################################
#FONCTION POUR SUPPRIME UN COMPTE UTILISATEUR
supprimer_utilisateur_local() {
    #ENTETE
    afficher_entete
    #TITRE 
    echo "  SUPPRESSION DE COMPTE UTILISATEUR"

    echo ""
    #ON LISTE LES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    read -p "NOM D'UTILISATEUR (Q POUR QUITTER): " NomUtilisateur
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"

        menu_utilisateurs
        return
    fi
    #ON REGARDE SI LE NOM EST VIDE
    if [ -z "$NomUtilisateur" ]; then
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        supprimer_utilisateur_local
        return
    fi
    #ON VERIFIE LUTILISATEUR EXISTE
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}L'UTILISATEUR \"$NomUtilisateur\" N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        supprimer_utilisateur_local
        return
    fi
    
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if ! verifier_mot_de_passe_admin "SUPPRIMER UTILISATEUR \"$NomUtilisateur\""; then
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        supprimer_utilisateur_local
        return
    fi
    
    #ON DEMANDE CONFIRMATION AVANT DE SUPPRIMER
    read -p "SUPPRIMER DEFINITIVEMENT \"$NomUtilisateur\" ? [O/N]: " Confirm
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        echo -e "${GRIS}SUPPRESSION ANNULEE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        menu_utilisateurs
        return
    fi
    #ON SUPPRIME LUTILISATEUR 
    echo "$MOT_DE_PASSE_ADMIN" | sudo -S userdel "$NomUtilisateur" 2>/dev/null
    #ON VERIFIE QUE  LUTILISATEUR A ETE SUPPRIME
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #LUTILISATEUR A ETE SUPPRIME DONC ON AFFICHE UN MESSAGE DE SUCCES
        echo ""
        echo -e "${VERT}UTILISATEUR \"$NomUtilisateur\" SUPPRIME${RESET}"
        #LOG
        sauvegarder_log "Action_SuppressionUtilisateur_$NomUtilisateur"
    else
        #LUTILISATEUR NA PAS ETE SUPPRIME DONC ON AFFICHE UNE ERREUR
        echo -e "${ROUGE}IMPOSSIBLE DE SUPPRIMER L'UTILISATEUR${RESET}"
    fi

    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT SUPPRIMER UN AUTRE COMPTE
    read -p "VOULEZ-VOUS SUPPRIMER UN AUTRE UTILISATEUR ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

        supprimer_utilisateur_local
    else
        menu_utilisateurs
    fi
}

###############################################################
#FONCTION POUR DESACTIVEE UN COMPTE UTILISATEUR
desactiver_utilisateur_local() {
    #ENTETE
    afficher_entete
    #TITRE
    echo "  DESACTIVATION DE COMPTE UTILISATEUR"

    echo ""
    #ON LISTE LES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    read -p "NOM D'UTILISATEUR (Q POUR QUITTER): " NomUtilisateur
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"

        menu_utilisateurs
        return
    fi
    #ON REGARDE SI LE NOM EST VIDE
    if [ -z "$NomUtilisateur" ]; then
        #SI LE NOM EST VIDE ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        desactiver_utilisateur_local
        return
    fi
    #ON VERIFIE QUE LUTILISATEUR EXISTE
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #LUTILISATEUR NEXISTE PAS DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}L'UTILISATEUR \"$NomUtilisateur\" N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        desactiver_utilisateur_local
        return
    fi
    
    #ON DEMANDE LE MOT DE PASSE ADMIN CAR CEST UNE ACTION SENSIBLE
    if ! verifier_mot_de_passe_admin "DESACTIVER UTILISATEUR \"$NomUtilisateur\""; then
        #LE MOT DE PASSE EST MAUVAIS DONC ON RECOMMENCE
        desactiver_utilisateur_local
        return
    fi
    
    #ON DEMANDE CONFIRMATION AVANT DE DESACTIVER
    read -p "DESACTIVER \"$NomUtilisateur\" ? [O/N]: " Confirm
    #ON REGARDE SI LUTILISATEUR A CONFIRME
    if [ "$Confirm" != "O" ] && [ "$Confirm" != "o" ]; then
        #LUTILISATEUR NA PAS CONFIRME DONC ON ANNULE
        echo -e "${GRIS}DESACTIVATION ANNULEE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        menu_utilisateurs
        return
    fi
    #ON DESACTIVE LUTILISATEUR
    echo "$MOT_DE_PASSE_ADMIN" | sudo -S usermod -L "$NomUtilisateur" 2>/dev/null
    #ON REGARDE SI LA COMMANDE A MARCHE
    if [ $? -eq 0 ]; then
        #ON AFFICHE UN MESSAGE DE SUCCES
        echo ""
        echo -e "${VERT}UTILISATEUR \"$NomUtilisateur\" DESACTIVE${RESET}"
        #LOG
        sauvegarder_log "Action_DesactivationUtilisateur_$NomUtilisateur"
    else
        #ON AFFICHE UNE ERREUR
        echo -e "${ROUGE}IMPOSSIBLE DE DESACTIVER L'UTILISATEUR${RESET}"
    fi

    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT DESACTIVER UN AUTRE COMPTE
    read -p "VOULEZ-VOUS DESACTIVER UN AUTRE UTILISATEUR ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

        desactiver_utilisateur_local
    else

        menu_utilisateurs
    fi
}

###############################################################
#FONCTION QUI AFFICHE LES GROUPES DUN UTILISATEUR
afficher_groupes_utilisateur() {
    #ENTETE
    afficher_entete
    #TITRE 
    echo "  GROUPES D'APPARTENANCE D'UN UTILISATEUR"
    
    echo ""
    #ON LISTE LES UTILISATEURS ACTUELS
    afficher_utilisateurs_locaux
    #ON DEMANDE LE NOM DE LUTILISATEUR
    read -p "NOM D'UTILISATEUR (Q POUR QUITTER): " NomUtilisateur
    #ON REGARDE SI LUTILISATEUR VEUT QUITTER
    if [ "$NomUtilisateur" = "q" ] || [ "$NomUtilisateur" = "Q" ]; then
        #LOG
        sauvegarder_log "Navigation_Retour"
        menu_utilisateurs
        return
    fi
    #ON REGARDE SI LE NOM EST VIDE
    if [ -z "$NomUtilisateur" ]; then
        #LE NOM EST VIDE DONC ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}NOM D'UTILISATEUR NON SPECIFIE${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        afficher_groupes_utilisateur
        return
    fi
    #ON VERIFIE QUE  LUTILISATEUR EXISTE
    if ! cat /etc/passwd | grep "^$NomUtilisateur:" > /dev/null; then
        #SI LUTILISATEUR NEXISTE PAS ON AFFICHE UN MESSAGE
        echo -e "${ROUGE}L'UTILISATEUR \"$NomUtilisateur\" N'EXISTE PAS${RESET}"
        read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"

        afficher_groupes_utilisateur
        return
    fi
    
    #LOG
    sauvegarder_log "Consultation_GroupesUtilisateur_$NomUtilisateur"
    
    #ON RECUPERE LES GROUPES DE LUTILISATEUR
    groupes=$(id -Gn "$NomUtilisateur" | sed 's/ / | /g')
    
    #FICHIER INFO
    sauvegarder_info "=== GROUPES UTILISATEUR === $(date '+%Y-%m-%d %H:%M:%S')UTILISATEUR: $NomUtilisateur GROUPES: $groupes"
    
    echo ""
    #ON AFFICHE LES GROUPES DE LUTILISATEUR
    echo "GROUPES DE \"$NomUtilisateur\": $groupes"
    
    echo ""
    #ON DEMANDE SI LUTILISATEUR VEUT CONSULTER UN AUTRE COMPTE
    read -p "VOULEZ-VOUS CONSULTER UN AUTRE UTILISATEUR ? [O/N]: " Continuer
    #ON REGARDE SI LUTILISATEUR VEUT CONTINUER
    if [ "$Continuer" = "O" ] || [ "$Continuer" = "o" ]; then

        afficher_groupes_utilisateur
    else

        menu_utilisateurs
    fi
}

####################################################################
#                         FONCTIONS MENUS                          #
####################################################################
###############################################################
#FONCTION QUI AFFICHE LE MENU DES REPERTOIRES
menu_repertoires() {
    #ENTETE
    afficher_entete
    #LOG
    sauvegarder_log "Navigation_MenuRepertoires"
    #TITRE 
    echo "  REPERTOIRES"

    echo ""
    #OPTIONS DU MENU
    echo "  1.CREER UN REPERTOIRE"
    echo "  2.SUPPRIMER UN REPERTOIRE"
    echo "  3.RETOUR"

    echo ""
    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-3]: " Choix
    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) creer_repertoire ;;
        2) supprimer_repertoire ;;
        3) sauvegarder_log "Navigation_Retour"; menu_gestion_machine ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_repertoires
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU DES LOGICIELS
menu_logiciels() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuLogiciels"

    #TITRE
    echo "  LOGICIELS"

    echo ""

    #ON AFFICHE LES OPTIONS DU MENU
    echo "  1.APPLICATIONS INSTALLEES"
    echo "  2.MISES A JOUR CRITIQUES"
    echo "  3.RETOUR"

    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-3]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) afficher_applications_installees ;;
        2) afficher_mises_a_jour_manquantes ;;
        3) sauvegarder_log "Navigation_Retour"; menu_gestion_machine ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_logiciels
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU DES SERVICES
menu_services() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuServices"

    #TITRE
    echo "  GESTION DES SERVICES"

    echo ""

    #OPTIONS DU MENU
    echo "  1.LISTER LES SERVICES EN COURS"
    echo "  2.RETOUR"

    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-2]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) afficher_services_en_cours ;;
        2) sauvegarder_log "Navigation_Retour"; menu_gestion_machine ;;
        *)
            #si LE CHOIX NEST PAS VALIDE ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_services
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU RESEAU
menu_reseau() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuReseau"

    #TITRE 
    echo "  RESEAU"


    echo ""

    #OPTIONS DU MENU
    echo "  1.PORTS OUVERTS"
    echo "  2.INFORMATION RESEAU"
    echo "  3.ACTIVATION DU PARE-FEU"
    echo "  4.RETOUR"


    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-4]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) afficher_ports_ouverts ;;
        2) afficher_config_ip ;;
        3) activer_pare_feu ;;
        4) sauvegarder_log "Navigation_Retour"; menu_gestion_machine ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_reseau
            ;;
    esac
}
###############################################################
#FONCTION QUI AFFICHE LE MENU SYSTEME
menu_systeme() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuSysteme"

    #TITRE DU MENU
    echo "  SYSTEME"

    echo ""

    #ON AFFICHE LES OPTIONS DU MENU
    echo "  1.INFORMATIONS SYSTEME"
    echo "  2.INFORMATION SUR LA RAM"
    echo "  3.RETOUR"

    echo ""

    #ON DEMANDE A L4UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-3]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) afficher_info_systeme ;;
        2) afficher_utilisation_ram ;;
        3) sauvegarder_log "Navigation_Retour"; menu_gestion_machine ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_systeme
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU DES CONTROLES
menu_controles() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuControles"

    #TITRE
    echo "  CONTROLES"

    echo ""

    #ON AFFICHE LES OPTIONS DU MENU
    echo "  1.REDEMARRAGE"
    echo "  2.EXECUTER UN SCRIPT"
    echo "  3.PRISE DE MAIN A DISTANCE (CLI)"
    echo "  4.RETOUR"

    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-4]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) redemarrer_machine ;;
        2) executer_script_distant ;;
        3) ouvrir_console_distante ;;
        4) sauvegarder_log "Navigation_Retour"; menu_gestion_machine ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_controles
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU DES UTILISATEURS
menu_utilisateurs() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuUtilisateurs"

    #TITRE 
    echo "  GESTION DES UTILISATEURS"

    echo ""

    #OPTIONS DU MENU
    echo "  1.CREER UN COMPTE UTILISATEUR LOCAL"
    echo "  2.CHANGER UN MOT DE PASSE"
    echo "  3.DESACTIVER UN COMPTE"
    echo "  4.SUPPRIMER UN COMPTE"
    echo "  5.VERIFIER L'APPARTENANCE A UN GROUPE"
    echo "  6.AJOUTER AUX ADMINISTRATEURS"
    echo "  7.AJOUTER A UN GROUPE"
    echo "  8.DROITS ET PERMISSIONS SUR FICHIER"
    echo "  9.RETOUR"

    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-9]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) creer_utilisateur_local ;;
        2) modifier_mot_de_passe_utilisateur ;;
        3) desactiver_utilisateur_local ;;
        4) supprimer_utilisateur_local ;;
        5) afficher_groupes_utilisateur ;;
        6) ajouter_utilisateur_groupe_admin ;;
        7) ajouter_utilisateur_groupe ;;
        8) afficher_permissions_utilisateur ;;
        9) sauvegarder_log "Navigation_Retour"; menu_principal ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_utilisateurs
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU DE GESTION DE LA MACHINE
menu_gestion_machine() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuGestionMachine"

    #TITRE 
    echo "  GESTION DE LA MACHINE"

    echo ""

    #ON AFFICHE LES OPTIONS DU MENU
    echo "  1.REPERTOIRES"
    echo "  2.LOGICIELS"
    echo "  3.SERVICES"
    echo "  4.RESEAU"
    echo "  5.SYSTEME"
    echo "  6.CONTROLES"
    echo "  7.RETOUR"

    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-7]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) menu_repertoires ;;
        2) menu_logiciels ;;
        3) menu_services ;;
        4) menu_reseau ;;
        5) menu_systeme ;;
        6) menu_controles ;;
        7) sauvegarder_log "Navigation_Retour"; menu_principal ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_gestion_machine
            ;;
    esac
}

###############################################################
#FONCTION QUI AFFICHE LE MENU PRINCIPAL
menu_principal() {
    #ENTETE
    afficher_entete

    #LOG
    sauvegarder_log "Navigation_MenuPrincipal"

    #TITRE DU MENU
    echo "  MENU PRINCIPAL"

    echo ""

    #ON AFFICHE LES OPTIONS DU MENU
    echo "  1.GESTION DE LA MACHINE"
    echo "  2.GESTION DES UTILISATEURS"
    echo "  Q.QUITTER"

    echo ""

    #ON DEMANDE A L'UTILISATEUR DE CHOISIR UNE OPTION
    read -p "TAPEZ [1-2 OU Q]: " Choix

    #ON REGARDE QUEL CHOIX L'UTILISATEUR A FAIT
    case $Choix in
        1) menu_gestion_machine ;;
        2) menu_utilisateurs ;;
        Q|q)
            clear

            #ON ENREGISTRE LA DECONNEXION DANS LE LOG
            sauvegarder_log "DeconnexionMachine"

            #ON QUITTE LE SCRIPT
            exit 0
            ;;
        *)
            #LE CHOIX NEST PAS VALIDE DONC ON AFFICHE UN MESSAGE
            echo -e "${ROUGE}CHOIX INVALIDE${RESET}"
            read -p "APPUYEZ SUR [ENTREE] POUR CONTINUER"
            menu_principal
            ;;
    esac
}

####################################################################
#                       DEMARRAGE DU SCRIPT                        #
####################################################################

#ON PREPARE LE FICHIER DE LOG ET LE DOSSIER INFO
initialiser_journal

#LOG
sauvegarder_log "ConnexionMachine"

#LANCEMENT DU MENU PRINCIPAL
menu_principal
