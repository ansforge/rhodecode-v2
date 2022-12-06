#!/bin/bash

#############################################################################
# Nom du script     : rhodecode-backup.sh
# Auteur            : E.RIEGEL (QM HENIX)
# Date de Création  : 15/02/2022
# Version           : 0.0.1
# Descritpion       : Script permettant la sauvegarde de la BDD de RhodeCode et de sauvegarder les repos de l'ANS
#
# Historique des mises à jour :
#-----------+--------+-------------+------------------------------------------------------
#  Version  |   Date   |   Auteur     |  Description
#-----------+--------+-------------+------------------------------------------------------
#  0.0.1    | 15/02/22 | E.RIEGEL  | Initialisation du script
#-----------+--------+-------------+------------------------------------------------------
###############################################################################################


# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/BACKUP/RHODECODE"

# Commande NOMAD
NOMAD=/usr/local/bin/nomad

#Repo PATH To BACKUP in the container
REPO_PATH=/root/
#Archive Name of the backup repo directory
BACKUP_REPO_FILENAME="BACKUP_REPOS_RHODECODE_${DATE}.tar.gz"
#Name of the dump file (Bdd Rhodecode)
DUMP_FILENAME="BACKUP_RHODECODE_BDD_${DATE}.dump"

# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=5

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE

# Backup repos
echo "Starting backup repos..."

$NOMAD exec -job rhodecode tar -cOzv -C $REPO_PATH my_dev_repos > $BACKUP_DIR/$DATE/$BACKUP_REPO_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "Repo backup failed with error code : ${BACKUP_RESULT}"
        exit 1
else
        echo "Repo backup done"
fi

# Dump rhodecode bdd
echo "starting rhodecode dump..."
$NOMAD exec -job rhodecode pg_dump -F c --dbname=postgresql://postgres:postgres@localhost/rhodecode > $BACKUP_DIR/$DATE/$DUMP_FILENAME

DUMP_RESULT=$?
if [ $DUMP_RESULT -gt 0 ]
then
        echo "Rhodecode dump failed with error code : ${DUMP_RESULT}"
        exit 1
else
        echo "Rhodecode dump done"
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -delete

echo "Backup Rhodecode finished"
