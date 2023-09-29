#!/bin/bash
echo "Démarrage du script de sauvegarde de Rhodecode"
#############################################################################
# Nom du script     : rhodecode-backup.sh
# Auteur            : E.RIEGEL (QM HENIX)
# Date de Création  : 15/02/2022
# Version           : 0.0.5
# Descritpion       : Script permettant la sauvegarde de la BDD de RhodeCode et de sauvegarder les repos de l'ANS
#
# Historique des mises à jour :
#-----------+--------+-------------+------------------------------------------------------
#  Version  |   Date   |   Auteur     |  Description
#-----------+--------+-------------+------------------------------------------------------
#  0.0.1    | 15/02/22 | E.RIEGEL     | Initialisation du script
#-----------+--------+-------------+------------------------------------------------------
#  0.0.2    | 07/03/22 | M.JURAVLIOV  | Ajout de la purge de la table user_logs (entrées de plus de 2 mois)
#-----------+--------+-------------+------------------------------------------------------
#  0.0.3    | 11/05/22 | E.RIEGEL     | Adaptation du script pour la version multi-conteneurs de Rhodecode
#-----------+--------+-------------+------------------------------------------------------
#  0.0.4    | 21/09/23 | Y.ETRILLARD  | Ajout -task dans la commande nomad exec de rhodecode-postgres
#-----------+--------+-------------+------------------------------------------------------
#  0.0.5    | 29/09/23 | Y.ETRILLARD  | Rétention à 3 jours
#-----------+--------+-------------+------------------------------------------------------
###############################################################################################

. /root/.bash_profile

# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/backup/RHODECODE"

# Dossier de sauvegarde de la table user_logs
BACKUP_USER_LOGS_DIR="/var/backup/RHODECODE_USER_LOGS"

# Commande NOMAD
#NOMAD=/usr/local/bin/nomad
NOMAD=$(which nomad)

#Repo PATH To BACKUP in the container
REPO_PATH=/var/opt
#Archive Name of the backup repo directory
BACKUP_REPO_FILENAME="BACKUP_REPOS_RHODECODE_${DATE}.tar.gz"
#Name of the dump file (Bdd Rhodecode)
DUMP_FILENAME="BACKUP_RHODECODE_BDD_${DATE}.dump"
#Archive Name of the backup user_logs table
BACKUP_USER_LOGS_FILENAME="BACKUP_USER_LOGS_${DATE}.tar.gz"


# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=3

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE
mkdir -p $BACKUP_USER_LOGS_DIR

# Backup repos
echo "Starting backup repos..."

$NOMAD exec -job -task rhodecode rhodecode-community tar -cOzv -C $REPO_PATH rhodecode_repo_store > $BACKUP_DIR/$DATE/$BACKUP_REPO_FILENAME
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
$NOMAD exec -task rhodecode-postgres -job rhodecode-postgres pg_dump -F c --dbname=postgresql://postgres@localhost/rhodecode > $BACKUP_DIR/$DATE/$DUMP_FILENAME

DUMP_RESULT=$?
if [ $DUMP_RESULT -gt 0 ]
then
        echo "Rhodecode dump failed with error code : ${DUMP_RESULT}"
        exit 1
else
        echo "Rhodecode dump done"
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -exec rm -rf {} \;

echo "Backup Rhodecode finished"

echo "Purging data from user_logs"
$NOMAD exec -task rhodecode-postgres -job rhodecode-postgres su -c "psql -d rhodecode -c \"copy (select * from user_logs where DATE(action_date) < NOW() - INTERVAL '15 DAY') to '/tmp/rhodecode_user_logs.csv' delimiter ',' CSV HEADER;\"" - postgres
$NOMAD exec -task rhodecode-postgres -job rhodecode-postgres tar -cOzv /tmp/rhodecode_user_logs.csv > $BACKUP_USER_LOGS_DIR/$BACKUP_USER_LOGS_FILENAME
$NOMAD exec -task rhodecode-postgres -job rhodecode-postgres rm -f /tmp/rhodecode_user_logs.csv
$NOMAD exec -task rhodecode-postgres -job rhodecode-postgres su -c "psql -d rhodecode -c \"delete from user_logs where DATE(action_date) < NOW() - INTERVAL '15 DAY';\"" - postgres
$NOMAD exec -task rhodecode-postgres -job rhodecode-postgres su -c "psql -d rhodecode -c \"VACUUM (VERBOSE, ANALYZE) user_logs;\"" - postgres

echo "Data purging finished"
