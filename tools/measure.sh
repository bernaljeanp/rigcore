#!/bin/sh
# Mide el uso de CPU de Vórtice y la temperatura del paquete durante N segundos.
# Uso: tools/measure.sh [segundos]
cd "$(dirname "$0")/.." || exit 1
DUR=${1:-20}
T=$(grep -l "^coretemp$\|^k10temp$" /sys/class/hwmon/hwmon*/name | head -1 | xargs dirname)/temp1_input
echo "Temp antes: $(( $(cat "$T") / 1000 )) °C"
.venv/bin/python -m vortice.app --ventana >/dev/null 2>&1 &
PID=$!
sleep 3
T0=$(awk '{print $14+$15}' /proc/$PID/stat); S0=$(date +%s.%N)
sleep "$DUR"
T1=$(awk '{print $14+$15}' /proc/$PID/stat); S1=$(date +%s.%N)
HZ=$(getconf CLK_TCK)
echo "CPU de la app: $(echo "($T1-$T0)/$HZ/($S1-$S0)*100" | bc -l | xargs printf '%.1f') % de un núcleo"
echo "Temp después: $(( $(cat "$T") / 1000 )) °C"
kill "$PID"
