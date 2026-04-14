#!/bin/bash

# ==========================================
# SCRIPT: Configuración Thin Client Debian
# ==========================================

echo "========================================="
echo " CONFIGURACIÓN THIN CLIENT - DEBIAN"
echo "========================================="

# Comprobación de ejecución como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse con sudo o como root."
    exit 1
fi

# Detectar usuario real
USUARIO_REAL=${SUDO_USER:-$(whoami)}

# ------------------------------------------
# 1. Desactivar entorno gráfico (modo consola)
# ------------------------------------------
echo ""
echo "[1/5] Configurando arranque en modo consola..."

systemctl set-default multi-user.target

echo "✔ Sistema configurado en modo texto."
echo ""
echo "ℹ️ Para volver al modo gráfico:"
echo "   sudo systemctl set-default graphical.target"
echo "   reboot"

# ------------------------------------------
# 2. Instalar Xorg mínimo
# ------------------------------------------
echo ""
echo "[2/5] Instalando entorno gráfico mínimo (Xorg)..."

apt update
apt install -y --no-install-recommends \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    xauth \
    xfonts-base

echo "✔ Xorg instalado (sin escritorio)."

# ------------------------------------------
# 3. Verificar e instalar FreeRDP
# ------------------------------------------
echo ""
echo "[3/5] Verificando FreeRDP..."

if command -v xfreerdp3 >/dev/null 2>&1; then
    echo "✔ xfreerdp3 ya instalado."
    FREERDP_CMD="xfreerdp3"
elif command -v xfreerdp >/dev/null 2>&1; then
    echo "✔ xfreerdp (versión anterior) detectado."
    FREERDP_CMD="xfreerdp"
else
    echo "❌ FreeRDP no encontrado. Instalando..."
    apt install -y freerdp2-x11
    FREERDP_CMD="xfreerdp"
fi

# ------------------------------------------
# 4. Solicitar IP
# ------------------------------------------
echo ""
echo "[4/5] Configuración de conexión"

read -p "Introduce la IP del servidor Proxmox/VM: " SERVER_IP

if [[ -z "$SERVER_IP" ]]; then
    echo "❌ No se ha introducido ninguna IP."
    exit 1
fi

echo "✔ IP configurada: $SERVER_IP"

# Crear script RDP
SCRIPT_PATH="/home/$USUARIO_REAL/rdp.sh"

cat <<EOF > $SCRIPT_PATH
#!/bin/bash

SERVER_IP="$SERVER_IP"
USERNAME="usuario"
PASSWORD="password"

while true; do
    $FREERDP_CMD /v:\$SERVER_IP \\
                 /u:\$USERNAME \\
                 /p:\$PASSWORD \\
                 /f \\
                 /cert:ignore \\
                 /dynamic-resolution

    echo "Reconectando en 3 segundos..."
    sleep 3
done
EOF

chmod +x $SCRIPT_PATH
chown $USUARIO_REAL:$USUARIO_REAL $SCRIPT_PATH

echo "✔ Script creado en $SCRIPT_PATH"

# Crear .xinitrc
XINITRC="/home/$USUARIO_REAL/.xinitrc"

echo "exec $SCRIPT_PATH" > $XINITRC

chmod +x $XINITRC
chown $USUARIO_REAL:$USUARIO_REAL $XINITRC

# ------------------------------------------
# 5. Preguntar autoarranque con startx
# ------------------------------------------
echo ""
echo "[5/5] Configuración de inicio automático"

read -p "¿Deseas iniciar automáticamente la conexión (modo kiosco)? (s/n): " AUTO_START

if [[ "$AUTO_START" == "s" || "$AUTO_START" == "S" ]]; then

    echo "✔ Activando inicio automático..."

    # Autologin en tty1
    mkdir -p /etc/systemd/system/getty@tty1.service.d

    cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO_REAL --noclear %I \$TERM
EOF

    # Configurar startx automático
    PROFILE_PATH="/home/$USUARIO_REAL/.profile"

    cat <<EOF >> $PROFILE_PATH

# Autoarranque X para Thin Client
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi
EOF

    chown $USUARIO_REAL:$USUARIO_REAL $PROFILE_PATH

    systemctl daemon-reexec

    echo "✔ Modo kiosco activado."
else
    echo "ℹ️ Inicio automático NO activado."
fi

# ------------------------------------------
# FINAL
# ------------------------------------------
echo ""
echo "========================================="
echo " CONFIGURACIÓN COMPLETADA"
echo "========================================="
echo ""
echo "Para iniciar manualmente:"
echo "   startx"
echo ""
echo "Para editar conexión:"
echo "   nano $SCRIPT_PATH"
echo ""
echo "Reinicia el sistema para aplicar cambios:"
echo "   reboot"
echo ""
