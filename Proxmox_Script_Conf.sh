#!/bin/bash

# ============================================================
# Script de configuración de cliente RDP ligero para Proxmox
# - Desactiva entorno gráfico (gdm3/lightdm)
# - Instala Xorg mínimo + Openbox
# - Instala FreeRDP
# - Solicita IP de destino por teclado
# - Verifica conectividad con ping
# - Crea ~/.xinitrc para conexión automática por RDP
# - Configura usuario en sudo y entorno correcto
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

# -------------------------------
# VERIFICAR USUARIO
# -------------------------------

echo ""
echo ">>> Usuario actual: $LOCAL_USER"

echo ""
read -p "¿Es este el usuario que ejecutará el RDP? (s/n): " OKUSER

if [[ "$OKUSER" != "s" && "$OKUSER" != "S" ]]; then
    read -p "Introduce el usuario correcto del sistema: " LOCAL_USER
fi

echo "Usuario seleccionado: $LOCAL_USER"

# -------------------------------
# PASO ADICIONAL - IP RDP
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

    read -p "¿Deseas continuar igualmente? (s/n): " CONTINUAR

    case "$CONTINUAR" in
        s|S|si|SI|sí|SÍ)
            echo "Continuando..."
            ;;
        *)
            echo "Cancelado."
            exit 1
            ;;
    esac
fi

# -------------------------------
# FASE 1 - SUDO (IMPORTANTE)
# -------------------------------

echo ""
echo ">>> FASE 1 - Configurando usuario sudo..."

if getent group sudo > /dev/null; then
    sudo usermod -aG sudo "$LOCAL_USER"
else
    sudo groupadd sudo
    sudo usermod -aG sudo "$LOCAL_USER"
fi

echo "Usuario añadido a sudo (puede requerir reinicio de sesión)."

# -------------------------------
# FASE 2 - DESACTIVAR ENTORNO GRÁFICO
# -------------------------------

echo ""
echo ">>> FASE 2 - Desactivando gestor gráfico..."

sudo systemctl disable gdm3 2>/dev/null || true
sudo systemctl stop gdm3 2>/dev/null || true

sudo systemctl disable lightdm 2>/dev/null || true
sudo systemctl stop lightdm 2>/dev/null || true

echo "Gestor gráfico desactivado."

# -------------------------------
# FASE 3 - INSTALAR PAQUETES
# -------------------------------

echo ""
echo ">>> FASE 3 - Instalando paquetes base..."

sudo apt update

sudo apt install -y --no-install-recommends \
    xserver-xorg \
    xinit \
    openbox \
    freerdp3-x11

echo "Paquetes instalados."

# -------------------------------
# FASE 4 - CREAR .xinitrc (CORRECTO EN USUARIO REAL)
# -------------------------------

echo ""
echo ">>> FASE 4 - Creando ~/.xinitrc para $LOCAL_USER..."

sudo -u "$LOCAL_USER" bash -c "cat > /home/$LOCAL_USER/.xinitrc << EOF
#!/bin/bash

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
EOF"

sudo chmod +x /home/$LOCAL_USER/.xinitrc
sudo chown "$LOCAL_USER:$LOCAL_USER" /home/$LOCAL_USER/.xinitrc

echo ".xinitrc creado correctamente."

# -------------------------------
# FINAL
# -------------------------------

echo ""
echo "=============================================="
echo " CONFIGURACIÓN FINALIZADA"
echo "=============================================="
echo ""
echo "IMPORTANTE:"
echo "- Cierra sesión COMPLETA (o reinicia)"
echo "- Vuelve a entrar con el usuario: $LOCAL_USER"
echo "- Asegúrate de que pertenece a sudo: groups"
echo ""
echo "Para iniciar RDP:"
echo "    startx"
echo ""
echo "Se ejecutará automáticamente xfreerdp3"
echo "=============================================="