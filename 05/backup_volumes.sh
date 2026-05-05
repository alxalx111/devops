# backup_volumes.sh
#!/bin/bash

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
VOLUMES=("postgres-data" "redis-data")

mkdir -p $BACKUP_DIR

for VOLUME in "${VOLUMES[@]}"; do
    echo "Backing up volume: $VOLUME"
    
    docker run --rm \
        -v ${VOLUME}:/source:ro \
        -v ${BACKUP_DIR}:/backup \
        alpine tar czf /backup/${VOLUME}_${DATE}.tar.gz -C /source .
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully backed up $VOLUME"
        ls -lh $BACKUP_DIR/${VOLUME}_${DATE}.tar.gz
    else
        echo "✗ Failed to backup $VOLUME"
    fi
done

# Удаление бэкапов старше 7 дней
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed at $(date)"
