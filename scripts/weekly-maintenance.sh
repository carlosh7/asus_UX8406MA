#!/bin/bash
# Weekly Maintenance Script - ASUS Zenbook Duo UX8406MA
# Runs every Sunday at 3:00 AM via cron
# Logs to /var/log/weekly-maintenance.log

set -euo pipefail
LOG="/var/log/weekly-maintenance.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$DATE] $1" >> "$LOG"; }

log "=== Weekly Maintenance Start ==="

# 1. Snap cleanup (remove disabled revisions)
log "--- Snap Cleanup ---"
snap list --all | awk '/desactivado/{print $1, $3}' | while read snapname revision; do
    snap remove "$snapname" --revision="$revision" >> "$LOG" 2>&1 && \
        log "Removed snap: $snapname $revision"
done

# 2. Journal cleanup
log "--- Journal Cleanup ---"
journalctl --vacuum-size=100M >> "$LOG" 2>&1

# 3. Temp files cleanup
log "--- Temp Cleanup ---"
find /tmp -type f -atime +7 -delete 2>/dev/null || true
find /var/tmp -type f -atime +7 -delete 2>/dev/null || true

# 4. APT cache cleanup
log "--- APT Cleanup ---"
apt-get autoremove -y >> "$LOG" 2>&1
apt-get clean >> "$LOG" 2>&1

# 5. Report disk usage
log "--- Disk Usage ---"
df -h / /home 2>/dev/null >> "$LOG"

# 6. Check disk space and alert if > 85%
USAGE=$(df / --output=pcent | tail -1 | tr -d '% ')
if [ "$USAGE" -gt 85 ]; then
    log "⚠️ ALERT: Root partition at ${USAGE}% - cleanup needed!"
fi

log "=== Weekly Maintenance Complete ==="
log ""
