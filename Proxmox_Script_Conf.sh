#!/bin/bash

# ============================================================
# Script de configuración de cliente RDP ligero para Proxmox
# - Desactiva entorno gráfico (gdm3/lightdm)
# - Instala Xorg mínimo + Openbox
# - Instala FreeRDP
# - Solicita IP de destino por teclado
# - Verifica conectividad con ping
# - Crea ~/.xinitrc para conexión automática por RDP
# ============================================================

set -e

echo "=============================================="
echo " CONFIGURACIÓN CLIENTE RDP LIGERO PARA PROXMOX"
echo "=============================================="

# -------------------------------
# VARIABLES POR DEFECTO
# -------------------------------

RDP_IP="192.168.12.9"
RDP_USER="usuario"
RDP_PASS="usuario"

# -------------------------------
# PASO ADICIONAL - Solicitar IP por teclado
# -------------------------------

echo ""
echo ">>> CONFIGURACIÓN DE DESTINO RDP"

read -p "Introduce la IP de la máquina RDP [${RDP_IP}]: " INPUT_IP

if [ -n "$INPUT_IP" ]; then
    RDP_IP="$INPUT_IP"
fi

echo "IP configurada: $RDP_IP"

# -------------------------------
# VERIFICACIÓN DE CONECTIVIDAD
# -------------------------------

echo ""
echo ">>> Verificando conectividad con ${RDP_IP}..."

if ping -c 4 -W 2 "$RDP_IP" > /dev/null 2>&1; then
    echo "Conectividad OK: la máquina responde al ping."
else
    echo ""
    echo "AVISO: No se ha podido contactar con ${RDP_IP}"
    echo "La máquina no responde al ping."
    echo ""

    read -p "¿Deseas continuar igualmente? (s/n): " CONTINUAR

    case "$CONTINUAR" in
        s|S|si|SI|sí|SÍ)
            echo "Continuando con la instalación..."
            ;;
        *)
            echo "Instalación cancelada por el usuario."
            exit 1
            ;;
    esac
fi

# -------------------------------
# FASE 1 - Desactivar arranque gráfico
# -------------------------------

echo ""
echo ">>> FASE 1 - Desactivando gestor gráfico..."

if systemctl list-unit-files | grep -q gdm3; then
    echo "Detectado gdm3"
    sudo systemctl disable gdm3 || true
    sudo systemctl stop gdm3 || true
fi

if systemctl list-unit-files | grep -q lightdm; then
    echo "Detectado lightdm"
    sudo systemctl disable lightdm || true
    sudo systemctl stop lightdm || true
fi

echo "Gestor gráfico desactivado."

# -------------------------------
# FASE 2 - Instalar Xorg mínimo
# -------------------------------

echo ""
echo ">>> FASE 2 - Instalando Xorg mínimo..."

sudo apt update
sudo apt install -y --no-install-recommends \
    xserver-xorg \
    xinit \
    openbox

echo "Xorg mínimo instalado."

# -------------------------------
# FASE 3 - Instalar FreeRDP
# -------------------------------

echo ""
echo ">>> FASE 3 - Instalando FreeRDP..."

sudo apt install -y freerdp3-x11

echo ""
echo "Versión instalada de FreeRDP:"
xfreerdp /version || true

# -------------------------------
# FASE 4 - Crear ~/.xinitrc
# -------------------------------

echo ""
echo ">>> FASE 4 - Creando script ~/.xinitrc..."

cat > ~/.xinitrc << EOF
#!/bin/sh

xset -dpms
xset s off
xset s noblank

openbox-session &

exec xfreerdp3 \\
/v:${RDP_IP} \\
/u:${RDP_USER} \\
/p:${RDP_PASS} \\
/f \\
/cert:ignore \\
/sound \\
/clipboard
EOF

chmod +x ~/.xinitrc

echo ".xinitrc creado correctamente."

# -------------------------------
# FINAL
# -------------------------------

echo ""
echo "=============================================="
echo " CONFIGURACIÓN FINALIZADA"
echo "=============================================="
echo ""
echo "Para iniciar la sesión RDP automáticamente:"
echo ""
echo "    startx"
echo ""
echo "Si deseas arranque automático al iniciar sesión,"
echo "puedo ayudarte con el servicio systemd."
echo ""
