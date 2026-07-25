#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico i3wm
# Customizado para: Danilo (Arch Linux + Zen Kernel)
#
# Terminal: Alacritty | Gerenciador de Arquivos: Thunar & Yazi
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║         INSTALAÇÃO DE AMBIENTE GRÁFICO (i3wm)            ║"
echo "  ║        Foco em Performance, Estética e Fluidez           ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#------------------------------------------------------------------------------#
# 1. VERIFICAÇÕES INICIAIS
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
# 2. INSTALAÇÃO DOS PACOTES DA INTERFACE GRÁFICA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [1/4] Instalando i3wm e pacotes gráficos essenciais...${NC}"
paru -S --needed --noconfirm \
    xorg-server xorg-xinit xorg-xauth xorg-xrandr \
    xorg-xset xorg-xprop xorg-xev xclip \
    xf86-input-libinput \
    i3-wm i3status i3lock-color \
    ly \
    dmenu \
    picom \
    dunst \
    feh \
    xss-lock \
    xclip \
    mate-polkit \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    zed-git

#------------------------------------------------------------------------------#
# 3. INSTALAÇÃO DO TERMINAL, GERENCIADORES DE ARQUIVO E YAZI
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [2/4] Instalando Alacritty, Thunar (e utilitários) e Yazi...${NC}"
paru -S --needed --noconfirm \
    alacritty \
    firefox \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    thunar-media-tags-plugin \
    gvfs \
    tumbler \
    ffmpegthumbnailer \
    yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick ueberzugpp \
    file-roller \
    polybar \
    networkmanager-dmenu-git \
    catppuccin-gtk-theme-macchiato papirus-icon-theme lxappearance \
    btop sxhkd \
    pavucontrol \
    pass xdotool keychain

#------------------------------------------------------------------------------#
# 4. SERVIÇOS DE SISTEMA E DOTFILES
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [3/4] Habilitando serviços do sistema (Ly e Bluetooth)...${NC}"

sudo systemctl enable ly.service
sudo systemctl set-default graphical.target

sudo systemctl enable --now bluetooth.service

echo -e "${BLUE}:: Clonando configuração i3wm para ~/.config...${NC}"
DOTFILES_TMP="$(mktemp -d)"
git clone https://github.com/DSanches92/my-i3wm.git "$DOTFILES_TMP"
rm -rf "$DOTFILES_TMP/.git"
mkdir -p ~/.config
cp -rT "$DOTFILES_TMP" ~/.config
rm -rf "$DOTFILES_TMP"

sudo cp ~/.config/ly/config.ini /etc/ly/config.ini

chmod +x ~/.config/dmenu/dmenu-run.sh
chmod +x ~/.config/dmenu/passmenu-run.sh
chmod +x ~/.config/i3/anti-sleep.sh

#------------------------------------------------------------------------------#
# 5. CONFIGURAÇÃO DO ALACRITTY COMO TERMINAL PADRÃO DO SISTEMA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [4/4] Definindo o Alacritty como terminal padrão...${NC}"
export TERMINAL=alacritty
if ! grep -q '^export TERMINAL=alacritty$' ~/.zshrc 2>/dev/null; then
  echo "export TERMINAL=alacritty" >> ~/.zshrc
fi

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Instalação concluída com sucesso!                      ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}Próximos Passos:${NC}"
echo -e "  1. Reinicie o sistema para subir a tela de login (Ly):"
echo -e "     ${GREEN}sudo reboot${NC}"
echo ""
echo -e "  2. Quando fizer login na interface i3wm:"
echo -e "     - Pressione ${BLUE}Super + Enter${NC} para abrir o seu novíssimo terminal ${GREEN}Alacritty${NC}."
echo -e "     - Pressione ${BLUE}Super + d${NC} para abrir o inicializador ${GREEN}DMenu${NC}."
echo -e "     - No terminal, digite ${GREEN}thunar${NC} para o gerenciador gráfico ou ${GREEN}yazi${NC} para o terminal."
echo ""
echo -e "  ${YELLOW}Opcional — Jogos:${NC}"
echo -e "     Steam, Proton GE, Gamemode, MangoHud e o launcher do Ark foram"
echo -e "     movidos para um script separado. Se quiser esse stack, rode:"
echo -e "     ${GREEN}./install-gaming.sh${NC}"
echo ""
echo -e "${BLUE}:: REINICIANDO EM 10 SEGUNDOS... ${NC}"
echo ""
sleep 10
reboot
