#!/bin/bash
# ============================================================
# Script de configuración de cliente RDP ligero para Proxmox
#
# DESCARGA DEL SCRIPT 
# wget https://raw.githubusercontent.com/smuncap936/Proxmox_Script_Conf/main/Proxmox_Script_Conf.sh
#
# Dar permisos de ejecución
# chmod +x Proxmox_Script_Conf.sh
#
# Ejecutar el script
# sudo ./Proxmox_Script_Conf.sh
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
LOCAL_USER="$(whoami)"

AUTO_USER="usuario"
AUTO_PASS="usuario"

# -------------------------------
# VERIFICAR USUARIO
# -------------------------------

echo ""
echo ">>> Usuario actual: $LOCAL_USER"

read -p "¿Es este el usuario que ejecutará el RDP? (s/n): " OKUSER

if [[ "$OKUSER" != "s" && "$OKUSER" != "S" ]]; then
    read -p "Introduce el usuario correcto del sistema: " LOCAL_USER
fi

echo "Usuario seleccionado: $LOCAL_USER"

# -------------------------------
# CONFIGURACIÓN IP
# -------------------------------

echo ""
read -p "IP RDP [${RDP_IP}]: " INPUT_IP

if [ -n "$INPUT_IP" ]; then
    RDP_IP="$INPUT_IP"
fi

echo "IP configurada: $RDP_IP"

# -------------------------------
# CONECTIVIDAD
# -------------------------------

echo ""
echo "Verificando conectividad..."

if ping -c 4 -W 2 "$RDP_IP" > /dev/null 2>&1; then
    echo "OK: máquina responde"
else
    echo "AVISO: no responde el ping"
    read -p "¿Continuar? (s/n): " CONT
    case "$CONT" in
        s|S|si|SI|sí|SÍ) echo "Continuando..." ;;
        *) echo "Cancelado"; exit 1 ;;
    esac
fi

# -------------------------------
# FASE 1 - SUDO
# -------------------------------

echo ""
echo "Configurando sudo..."

if getent group sudo > /dev/null; then
    sudo usermod -aG sudo "$LOCAL_USER"
else
    sudo groupadd sudo
    sudo usermod -aG sudo "$LOCAL_USER"
fi

# -------------------------------
# FASE 2 - DESACTIVAR GUI
# -------------------------------

echo ""
echo "Desactivando entorno gráfico..."

sudo systemctl disable gdm3 2>/dev/null || true
sudo systemctl stop gdm3 2>/dev/null || true

sudo systemctl disable lightdm 2>/dev/null || true
sudo systemctl stop lightdm 2>/dev/null || true

# -------------------------------
# FASE 3 - INSTALAR PAQUETES
# -------------------------------

echo ""
echo "Instalando paquetes..."

sudo apt update

sudo apt install -y --no-install-recommends \
    xserver-xorg \
    xinit \
    openbox \
    freerdp3-x11

# -------------------------------
# FASE 4 - CREAR .xinitrc (MENÚ INTERACTIVO)
# -------------------------------

echo ""
echo "Creando .xinitrc con menú..."

sudo -u "$LOCAL_USER" bash -c "cat > /home/$LOCAL_USER/.xinitrc << EOF
#!/bin/bash

xset -dpms
xset s off
xset s noblank

openbox-session &

while true; do

    xfreerdp3 \\
    /v:${RDP_IP} \\
    /u:${RDP_USER} \\
    /p:${RDP_PASS} \\
    /f \\
    /cert:ignore \\
    /sound \\
    /clipboard

    clear
    echo \"=======================================\"
    echo \" SESIÓN RDP FINALIZADA\"
    echo \"=======================================\"
    echo \"\"
    echo \"0 - Apagar equipo\"
    echo \"1 - Reconectar RDP\"
    echo \"2 - Ir a consola\"
    echo \"\"
    echo \"Se apagará automáticamente en 120 segundos...\"
    echo \"\"

    read -t 120 -p \"Selecciona una opción: \" opcion

    case \"\$opcion\" in
        0)
            echo \"Apagando equipo...\"
            sleep 2
            sudo poweroff
            ;;
        1)
            echo \"Reconectando...\"
            sleep 2
            continue
            ;;
        2)
            echo \"Saliendo a consola...\"
            sleep 2
            break
            ;;
        *)
            echo \"Sin selección. Apagando...\"
            sleep 2
            sudo poweroff
            ;;
    esac

done

EOF"

sudo chmod +x /home/$LOCAL_USER/.xinitrc
sudo chown "$LOCAL_USER:$LOCAL_USER" /home/$LOCAL_USER/.xinitrc

# -------------------------------
# FASE 5 - AUTOLOGIN
# -------------------------------

echo ""
echo "Configurando autologin..."

AUTOLOGIN_FILE="/etc/systemd/system/getty@tty1.service.d/kiosk-autologin.conf"

if [ ! -f "$AUTOLOGIN_FILE" ]; then
    echo "Creando autologin..."
    
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/

    sudo bash -c "cat > $AUTOLOGIN_FILE << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${AUTO_USER} --noclear %I \$TERM
EOF"

    sudo systemctl daemon-reexec
    echo "Autologin configurado."
else
    echo "Autologin ya existe. No se modifica."
fi

# -------------------------------
# FASE 6 - AUTO STARTX
# -------------------------------

echo ""
echo "Configurando inicio automático de startx..."

sudo -u "$LOCAL_USER" bash -c "cat > /home/$LOCAL_USER/.bash_profile << 'EOF'
if [ -z \"\$DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then
    startx
fi
EOF"

# -------------------------------
# FASE 7 - PERMITIR APAGADO SIN PASSWORD
# -------------------------------

echo ""
echo "Configurando apagado sin contraseña..."

sudo bash -c "echo '$LOCAL_USER ALL=(ALL) NOPASSWD: /sbin/poweroff' > /etc/sudoers.d/kiosk-poweroff"
sudo chmod 440 /etc/sudoers.d/kiosk-poweroff

# -------------------------------
# FINAL
# -------------------------------

echo ""
echo "=============================================="
echo " CONFIGURACIÓN FINALIZADA"
echo "=============================================="
echo ""
echo "IMPORTANTE:"
echo "- Reinicia el equipo"
echo "- El sistema iniciará automáticamente en RDP"
echo "- Al cerrar RDP aparecerá un menú interactivo"
echo ""
echo "=============================================="