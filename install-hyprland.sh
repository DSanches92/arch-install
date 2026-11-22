#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico Hyprland
# Customizado para: Danilo (Arch Linux + Zen Kernel + RTX 2060)
#
# Terminal: Alacritty | FM: Yazi | Barra: Waybar | Launcher: Rofi (Wayland)
#
# Os dotfiles vêm do repositório my-hyprland e são aplicados pelo install.sh
# dele (cópia para ~/.config + zsh + tema do SDDM).
#

set -euo pipefail

DOTFILES_REPO="https://github.com/DSanches92/my-hyprland.git"

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
echo -e "${CYAN}:: [1/6] Instalando Hyprland + ferramentas Wayland...${NC}"
paru -S --needed --noconfirm \
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker \
    waybar alacritty rofi qt5-wayland qt6-wayland dunst \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent \
    cliphist wl-clipboard hyprshot wlogout swappy \
    ttf-jetbrains-mono-nerd woff2-font-awesome noto-fonts \
    pavucontrol egl-wayland

#------------------------------------------------------------------------------#
# 2. NAVEGADOR, GERENCIADOR DE ARQUIVOS (YAZI) E UTILITÁRIOS
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [2/6] Instalando Firefox, Yazi e utilitários...${NC}"
paru -S --needed --noconfirm \
    firefox firefox-i18n-pt-br \
    yazi 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick pamixer \
    thunar dex

# Corretor ortográfico pt-BR (o Firefox lê /usr/share/hunspell). Vem do AUR e
# precisa do qt6-webengine só para compilar; --removemake remove ele depois.
paru -S --needed --noconfirm --removemake hunspell-pt-br

#------------------------------------------------------------------------------#
# 3. BLUETOOTH, KEYRING E APPLET DE REDE
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [3/6] Instalando Bluetooth, keyring e applet de rede...${NC}"
paru -S --needed --noconfirm \
    bluez bluez-utils blueman \
    gnome-keyring libsecret network-manager-applet

#------------------------------------------------------------------------------#
# 4. TEMA ESCURO (GTK + QT)
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [4/6] Instalando e configurando tema escuro (GTK + Qt)...${NC}"
paru -S --needed --noconfirm \
    catppuccin-gtk-theme-macchiato papirus-icon-theme nwg-look qt5ct qt6ct

# Os settings.ini do GTK 3/4 e o qt6ct vêm dos dotfiles (passo 6), e o
# QT_QPA_PLATFORMTHEME é definido no hypr/hyprland.lua.
# Ajuste fino de tema/acento pode ser feito depois com `nwg-look`.

#------------------------------------------------------------------------------#
# 5. SERVIÇOS DE SISTEMA (SDDM E BLUETOOTH)
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [5/6] Instalando e habilitando SDDM (display manager)...${NC}"
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

# O firewall (ufw) já é ativado pelo install-arch-linux.sh.

#------------------------------------------------------------------------------#
# 6. DOTFILES (my-hyprland)
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [6/6] Aplicando os dotfiles do my-hyprland...${NC}"
DOTFILES_TMP="$(mktemp -d)"
trap 'rm -rf "$DOTFILES_TMP"' EXIT
git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_TMP"
# Copia as configs para ~/.config (com backup .bak-<data>), aplica o zsh por
# cima do Oh My Zsh e instala o tema do SDDM (com sudo).
"$DOTFILES_TMP/install.sh"

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
