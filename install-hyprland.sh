#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico Hyprland
# Customizado para: Danilo (Arch Linux + Zen Kernel + RTX 2060)
#
# Terminal: Alacritty | FM: Yazi | Barra: Waybar | Launcher: Rofi (Wayland)
#

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║       INSTALAÇÃO DE AMBIENTE GRÁFICO (Hyprland)          ║"
echo "  ║        Foco em Performance, Estética e Fluidez           ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#------------------------------------------------------------------------------#
# -- VERIFICAÇÕES INICIAIS
#------------------------------------------------------------------------------#
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[ERRO] Não execute este script como root/sudo diretamente.${NC}"
    echo "O script precisa rodar com seu usuário comum para que o 'paru' funcione."
    exit 1
fi

if ! command -v paru &> /dev/null; then
    echo -e "${RED}[ERRO] O assistente AUR 'paru' não foi encontrado.${NC}"
    echo "Por favor, garanta que a fase de pós-instalação base foi concluída com sucesso."
    exit 1
fi

#------------------------------------------------------------------------------#
# 1. INSTALAÇÃO DO HYPRLAND + FERRAMENTAS WAYLAND
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [1/7] Instalando Hyprland + ferramentas Wayland...${NC}"
paru -S --needed --noconfirm \
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker \
    waybar alacritty rofi-wayland qt5-wayland qt6-wayland dunst \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent \
    cliphist hyprshot wlogout swappy \
    ttf-jetbrains-mono-nerd ttf-font-awesome noto-fonts \
    pavucontrol egl-wayland

#------------------------------------------------------------------------------#
# 2. NAVEGADOR, GERENCIADOR DE ARQUIVOS (YAZI) E UTILITÁRIOS
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [2/7] Instalando Firefox, Yazi e utilitários...${NC}"
paru -S --needed --noconfirm \
    firefox firefox-i18n-pt-br \
    yazi 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick pamixer \
    pass rofi-pass thunar dex

#------------------------------------------------------------------------------#
# 3. BLUETOOTH, KEYRING E APPLET DE REDE
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [3/7] Instalando Bluetooth, keyring e applet de rede...${NC}"
paru -S --needed --noconfirm \
    bluez bluez-utils blueman \
    gnome-keyring libsecret network-manager-applet

#------------------------------------------------------------------------------#
# 4. TEMA ESCURO (GTK + QT)
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [4/7] Instalando e configurando tema escuro (GTK + Qt)...${NC}"
paru -S --needed --noconfirm \
    catppuccin-gtk-theme-macchiato papirus-icon-theme nwg-look qt5ct qt6ct

mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0
for gtk_ini in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini; do
  cat > "$gtk_ini" <<'GTKEOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Catppuccin-Macchiato-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
GTKEOF
done

# Ajuste fino de tema/acento pode ser feito depois com `nwg-look`.
if ! grep -q '^export QT_QPA_PLATFORMTHEME=qt6ct$' ~/.zshrc 2>/dev/null; then
  echo "export QT_QPA_PLATFORMTHEME=qt6ct" >> ~/.zshrc
fi

#------------------------------------------------------------------------------#
# 5. SERVIÇOS DE SISTEMA (SDDM, BLUETOOTH E FIREWALL)
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [5/7] Instalando e habilitando SDDM (display manager)...${NC}"
paru -S --needed --noconfirm sddm
sudo systemctl enable sddm.service

echo -e "${CYAN}:: Configurando auto-unlock do keyring (gnome-keyring) via PAM...${NC}"
SDDM_PAM="/etc/pam.d/sddm"
if [[ -f "$SDDM_PAM" ]] && ! grep -q pam_gnome_keyring.so "$SDDM_PAM"; then
  sudo cp "$SDDM_PAM" "$SDDM_PAM.bak-$(date +%Y%m%d-%H%M%S)"
  sudo sed -i '/^auth.*include.*system-login/a auth       optional     pam_gnome_keyring.so' "$SDDM_PAM"
  sudo sed -i '/^session.*include.*system-login/a session    optional     pam_gnome_keyring.so auto_start' "$SDDM_PAM"
  echo -e "${GREEN}:: PAM do SDDM atualizado para desbloquear o keyring no login.${NC}"
else
  echo -e "${YELLOW}:: PAM do SDDM já configurado ou arquivo ausente. Pulando.${NC}"
fi

sudo systemctl set-default graphical.target
sudo systemctl enable --now bluetooth.service

echo -e "${CYAN}:: Ativando firewall...${NC}"
sudo ufw enable
sudo systemctl enable ufw

#------------------------------------------------------------------------------#
# 6. DOTFILES
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [6/7] Clonando configuração Hyprland para ~/.config...${NC}"
DOTFILES_TMP="$(mktemp -d)"
git clone https://github.com/DSanches92/my-hyprland.git "$DOTFILES_TMP"
rm -rf "$DOTFILES_TMP/.git"
mkdir -p ~/.config
cp -rT "$DOTFILES_TMP" ~/.config
rm -rf "$DOTFILES_TMP"

# Nota: diferente do X11 (localectl set-x11-keymap), o layout de teclado no
# Hyprland/Wayland é definido dentro do hyprland.conf (bloco "input { kb_layout = br }"),
# que vem do repositório de dotfiles acima — não faz sentido setar via localectl aqui.
#
# Nota (tecla de volume do teclado): o Hyprland lê os keycodes XF86AudioRaiseVolume/
# LowerVolume/Mute direto do evdev, sem a camada de xmodmap que dava problema no i3wm.
# Ainda precisa de um bind no hyprland.conf dos dotfiles, ex:
#   bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
#   bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
#   bind = , XF86AudioMute,        exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ toggle-mute

#------------------------------------------------------------------------------#
# 7. CONFIGURAÇÃO DO ALACRITTY COMO TERMINAL PADRÃO DO SISTEMA
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [7/7] Definindo o Alacritty como terminal padrão...${NC}"
export TERMINAL=alacritty
if ! grep -q '^export TERMINAL=alacritty$' ~/.zshrc 2>/dev/null; then
  echo "export TERMINAL=alacritty" >> ~/.zshrc
fi

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Instalação gráfica concluída!                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}Próximos Passos:${NC}"
echo -e "  1. ${GREEN}sudo reboot${NC}"
echo -e "  2. Login via SDDM → sessão Hyprland"
echo -e "  3. Opcional jogos: ${GREEN}./install-gaming.sh${NC}"
echo ""
echo -e "${CYAN}:: REINICIANDO EM 10 SEGUNDOS... ${NC}"
echo ""
sleep 10
reboot
