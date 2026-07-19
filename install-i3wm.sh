#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico i3wm
# Customizado para: Danilo (Arch Linux + Zen Kernel)
#
# Terminal: Alacritty | Gerenciador de Arquivos: Thunar & Yazi
#

set -euo pipefail

# Cores para saída do terminal
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
# Garantir que o script NÃO está rodando como Root diretamente
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[ERRO] Não execute este script como root/sudo diretamente.${NC}"
    echo "O script precisa rodar com seu usuário comum para que o 'paru' funcione."
    exit 1
fi

# Verificar se o Paru está disponível
if ! command -v paru &> /dev/null; then
    echo -e "${RED}[ERRO] O assistente AUR 'paru' não foi encontrado.${NC}"
    echo "Por favor, garanta que a fase de pós-instalação base foi concluída com sucesso."
    exit 1
fi

#------------------------------------------------------------------------------#
# 2. INSTALAÇÃO DOS PACOTES DA INTERFACE GRÁFICA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [1/6] Instalando i3wm e pacotes gráficos essenciais...${NC}"

paru -S --needed --noconfirm \
    xorg-server xorg-xinit xorg-xauth xorg-xrandr \
    xf86-input-libinput xf86-video-amdgpu \
    i3-wm i3status \
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
    blueman

#------------------------------------------------------------------------------#
# 3. INSTALAÇÃO DO TERMINAL, GERENCIADORES DE ARQUIVO E YAZI
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [2/6] Instalando Alacritty, Thunar (e utilitários) e Yazi...${NC}"

# Thunar + Integrações de mídia, compactação e volume
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
    yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick ueberzugpp\
    file-roller \
    polybar \
    i3lock-color \
    networkmanager-dmenu-git \
    catppuccin-gtk-theme-macchiato papirus-icon-theme lxappearance \
    btop \
    pavucontrol \
    pass xdotool keychain

#------------------------------------------------------------------------------#
# 5. AJUSTES DE CONFIGURAÇÃO E SERVIÇOS
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [4/6] Habilitando serviços do sistema (Ly e Bluetooth)...${NC}"

# Habilitar o gerenciador de login
sudo systemctl enable ly.service

# Habilitar serviço do Bluetooth
sudo systemctl enable --now bluetooth.service

# Criar os diretórios padrões de configuração para evitar erros de inicialização
echo -e "${BLUE}:: Criando diretórios padrão em ~/.config...${NC}"
mkdir -p ~/.config/{i3,dmenu,polybar,dunst,alacritty,yazi}

# Configuração do dmenu
if [ ! -f ~/.config/dmenu/dmenu-run.sh ]; then
  cat > ~/.config/dmenu/dmenu-run.sh << 'SCRIPTEOF'
#!/bin/bash

# Configuração da Fonte
FONTE="Geist Nerd Font-11"

# Paleta Catppuccin Macchiato
BACKGROUND="#24273a"  # Base
TEXTO_NORMAL="#cad3f5" # Text
SELECIONADO="#c6a0f6"  # Mauve
TEXTO_SEL="#24273a"    # Base

# Executa o dmenu original passando as configurações
dmenu_run -fn "$FONTE" -nb "$BACKGROUND" -nf "$TEXTO_NORMAL" -sb "$SELECIONADO" -sf "$TEXTO_SEL" -i
SCRIPTEOF
fi

# Configuração para Passmenu
if [ ! -f ~/.config/dmenu/passmenu-run.sh ]; then
  cat > ~/.config/dmenu/passmenu-run.sh << 'SCRIPTEOF'
#!/bin/bash

# Configuração da Fonte
FONTE="Geist Nerd Font-12"

# Paleta Catppuccin Macchiato
BACKGROUND="#24273a"   # Base
TEXTO_NORMAL="#cad3f5" # Text
SELECIONADO="#c6a0f6"  # Mauve
TEXTO_SEL="#24273a"    # Base

# Argumentos visuais do dmenu encapsulados
DMENU_ARGS="-fn $FONTE -nb $BACKGROUND -nf $TEXTO_NORMAL -sb $SELECIONADO -sf $TEXTO_SEL -i"

# Executa o passmenu original injetando os nossos parâmetros visuais do dmenu
passmenu --type $DMENU_ARGS
SCRIPTEOF
fi

# Configuração controle de ociosidade
if [ ! -f ~/.config/i3/anti-sleep.sh ]; then
  cat > ~/.config/i3/anti-sleep.sh << 'SCRIPTEOF'
#!/bin/bash

# Script para impedir suspensão se houver áudio tocando (Pipewire/PulseAudio)
while true; do
  if pactl list sinks | grep -q "State: RUNNING"; then
    xset s reset
  fi

  sleep 60
done
SCRIPTEOF
fi

# Permissão deexecução para os scripts
chmod +x ~/.config/dmenu/dmenu-run.sh
chmod +x ~/.config/dmenu/passmenu-run.sh
chmod +x ~/.config/i3/anti-sleep.sh

# Se não houver uma configuração padrão do i3, cria uma inicial para não dar tela preta
if [ ! -f ~/.config/i3/config ]; then
  cat > ~/.config/i3/config << 'EOF'
exec --no-startup-id gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
exec --no-startup-id ~/.config/i3/anti-sleep.sh

exec_always --no-startup-id picom -b
exec_always --no-startup-id nm-applet
exec_always --no-startup-id setxkbmap -layout br -model abnt2
exec_always --no-startup-id /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
exec_always --no-startup-id dbus-update-activation-environment --systemd DISPLAY XAUTHORITY

bindsym Mod4+q kill

bindsym Mod4+Return exec alacritty
bindsym Mod4+Shift+e exec --no-startup-id alacritty -e yazi
bindsym Mod4+d exec --no-startup-id ~/.config/dmenu/dmenu-run.sh
bindsym Mod4+p exec --no-startup-id ~/.config/dmenu/passmenu-run.sh
bindsym Mod4+b exec firefox
EOF
fi

#------------------------------------------------------------------------------#
# 6. CONFIGURAÇÃO DO ALACRITTY COMO TERMINAL PADRÃO DO SISTEMA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [5/6] Definindo o Alacritty como terminal padrão...${NC}"
export TERMINAL=alacritty
echo "export TERMINAL=alacritty" >> ~/.bashrc

#------------------------------------------------------------------------------#
# 7. INSTALAÇÃO DE PACOTES PARA JOGOS (STEAM, PROTON, OTIMIZAÇÕES)
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [6/6] Instalando pacotes para jogos e otimizações de desempenho...${NC}"

# Steam + Gamemode + MangoHud + Gamescope
echo -e "${YELLOW}:: Instalando Steam, Gamemode, MangoHud, Gamescope, Proton GE e ProtonUp-Qt...${NC}"
paru -S --needed --noconfirm \
    steam \
    gamemode lib32-gamemode \
    mangohud lib32-mangohud \
    gamescope \
    lutris \
    winetricks \
    proton-ge-custom \
    protonup-qt

# Adiciona o usuário ao grupo gamemode para permissões de desempenho
echo -e "${YELLOW}:: Adicionando $USER ao grupo gamemode...${NC}"
sudo usermod -aG gamemode "$USER"

#------------------------------------------------------------------------------#
# 7b. CONFIGURAÇÕES DE OTIMIZAÇÃO PARA JOGOS
#------------------------------------------------------------------------------#
# --- MangoHud (overlay de desempenho) ---
echo -e "${YELLOW}:: Configurando MangoHud (overlay de FPS, CPU/GPU)...${NC}"
mkdir -p ~/.config/MangoHud
cat > ~/.config/MangoHud/MangoHud.conf << 'EOF'
# MangoHud — Configuração para jogos (Ark: Survival Ascended)
fps
frame_timing=0
cpu_stats
cpu_temp
cpu_mhz
gpu_stats
gpu_temp
gpu_mhz
gpu_fan
vram
ram
resolution
gamepad
toggle_hud=Shift_R+F12
position=top-left
font_size=20
background_alpha=0.5
EOF

# --- Proton GE como padrão no Steam ---
echo -e "${YELLOW}:: Configurando Proton GE como camada de compatibilidade padrão no Steam...${NC}"
PROTON_GE_DIR=$(ls -d /usr/share/steam/compatibilitytools.d/GE-Proton* 2>/dev/null | head -1)
if [[ -n "$PROTON_GE_DIR" ]]; then
    PROTON_GE_NAME=$(basename "$PROTON_GE_DIR")
    echo -e "${GREEN}:: Proton GE detectado: $PROTON_GE_NAME${NC}"

    STEAM_CONFIG="$HOME/.local/share/Steam/config/config.vdf"
    if [[ -f "$STEAM_CONFIG" ]]; then
        if grep -q "\"$PROTON_GE_NAME\"" "$STEAM_CONFIG" 2>/dev/null; then
            echo -e "${GREEN}:: Proton GE já configurado no Steam.${NC}"
        else
            python3 -c "
import os, sys
config = os.path.expanduser('$STEAM_CONFIG')
ge_name = '$PROTON_GE_NAME'
with open(config, 'r') as f:
    content = f.read()
# Check if CompatToolMapping exists
if '\"CompatToolMapping\"' in content:
    # Add entry inside existing section
    import re
    match = list(re.finditer(r'\"CompatToolMapping\"\s*\{', content))
    if match:
        start = match[-1].end()
        # Find closing brace of this section
        depth = 1
        pos = start
        while depth > 0 and pos < len(content):
            if content[pos] == '{': depth += 1
            elif content[pos] == '}': depth -= 1
            pos += 1
        entry = '\n\t\t\"0\"\n\t\t{\n\t\t\t\"name\" \"' + ge_name + '\"\n\t\t\t\"config\" \"\"\n\t\t\t\"Priority\" \"0\"\n\t\t}'
        content = content[:pos-1] + entry + content[pos-1:]
else:
    # Add section before last closing brace
    pos = content.rstrip().rfind('}')
    if pos > 0:
        section = '\n\t\"CompatToolMapping\"\n\t{\n\t\t\"0\"\n\t\t{\n\t\t\t\"name\" \"' + ge_name + '\"\n\t\t\t\"config\" \"\"\n\t\t\t\"Priority\" \"0\"\n\t\t}\n\t}'
        content = content[:pos] + section + content[pos:]
with open(config, 'w') as f:
    f.write(content)
print('OK')
" 2>/dev/null && echo -e "${GREEN}:: Proton GE configurado como padrão no Steam.${NC}" \
    || echo -e "${YELLOW}:: Não foi possível editar a config do Steam. Faça manualmente: Steam > Configurações > Steam Play > Avançado.${NC}"
        fi
    else
        echo -e "${YELLOW}:: Steam ainda não foi iniciado. Após o primeiro login, execute:${NC}"
        echo -e "     ${GREEN}$HOME/.local/bin/steam-proton-default${NC}"
    fi
else
    echo -e "${RED}:: Proton GE não encontrado. O AUR pode ter falhado.${NC}"
    echo -e "${RED}:: Execute novamente ou use 'protonup-qt' para instalar.${NC}"
fi

# Gera script auxiliar para configurar Proton GE manualmente depois
mkdir -p ~/.local/bin
cat > ~/.local/bin/steam-proton-default << 'SCRIPTEOF'
#!/usr/bin/env bash
# Define Proton GE como camada de compatibilidade padrão no Steam
set -euo pipefail
STEAM_CFG="$HOME/.local/share/Steam/config/config.vdf"
COMPAT_DIR="/usr/share/steam/compatibilitytools.d"
GE_DIR=$(ls -d "$COMPAT_DIR"/GE-Proton* 2>/dev/null | head -1)
if [[ -z "$GE_DIR" ]]; then
    echo "Proton GE não encontrado em $COMPAT_DIR"
    exit 1
fi
GE_NAME=$(basename "$GE_DIR")
if [[ ! -f "$STEAM_CFG" ]]; then
    echo "Arquivo de configuração do Steam não encontrado."
    echo "Inicie o Steam ao menos uma vez antes de rodar este script."
    exit 1
fi
if grep -q "\"$GE_NAME\"" "$STEAM_CFG" 2>/dev/null; then
    echo "Proton GE ($GE_NAME) já está configurado."
    exit 0
fi
python3 -c "
import os, sys
cfg = os.path.expanduser('$STEAM_CFG')
ge = '$GE_NAME'
with open(cfg, 'r') as f:
    c = f.read()
import re
m = list(re.finditer(r'\"CompatToolMapping\"\s*\{', c))
if m:
    s = m[-1].end()
    d = 1; p = s
    while d > 0 and p < len(c):
        if c[p] == '{': d += 1
        elif c[p] == '}': d -= 1
        p += 1
    e = '\n\t\t\"0\"\n\t\t{\n\t\t\t\"name\" \"' + ge + '\"\n\t\t\t\"config\" \"\"\n\t\t\t\"Priority\" \"0\"\n\t\t}'
    c = c[:p-1] + e + c[p-1:]
else:
    p = c.rstrip().rfind('}')
    if p > 0:
        s = '\n\t\"CompatToolMapping\"\n\t{\n\t\t\"0\"\n\t\t{\n\t\t\t\"name\" \"' + ge + '\"\n\t\t\t\"config\" \"\"\n\t\t\t\"Priority\" \"0\"\n\t\t}\n\t}'
        c = c[:p] + s + c[p:]
with open(cfg, 'w') as f:
    f.write(c)
print('Proton GE (' + ge + ') configurado como padrão. Reinicie o Steam.')
" || echo "Erro: Python3 não encontrado ou falha na configuração."
SCRIPTEOF
chmod +x ~/.local/bin/steam-proton-default

# --- Script de lançamento otimizado para Ark: Survival Ascended ---
echo -e "${YELLOW}:: Criando ~/ark.sh (lançamento otimizado para Ark: Survival Ascended)...${NC}"
cat > ~/ark.sh << 'SCRIPTEOF'
#!/usr/bin/env bash
# Ark: Survival Ascended — Lançamento otimizado
# Uso: ./ark.sh
#
# Opções de lançamento equivalentes para configurar no Steam:
#   gamemoderun mangohud PROTON_HEAP_DELAY_FREEING=1 %command%
#
# Steam App ID: 2399830 (Ark: Survival Ascended)

set -euo pipefail

ARK_APPID="2399830"

echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║    Ark: Survival Ascended — Modo Otimizado              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Otimizações ativas:"
echo "    • PROTON_HEAP_DELAY_FREEING=1 (reduz stuttering no UE5)"
echo "    • gamemoderun (CPU/GPU em modo desempenho)"
echo "    • MangoHud (overlay de FPS e hardware)"
echo ""

export PROTON_HEAP_DELAY_FREEING=1
export MANGOHUD=1

if ! command -v steam &>/dev/null; then
    echo "[ERRO] Steam não encontrado. Instale o steam primeiro."
    exit 1
fi

echo "  Iniciando Steam e Ark: Survival Ascended..."
echo ""
gamemoderun steam steam://rungameid/"$ARK_APPID"
SCRIPTEOF
chmod +x ~/ark.sh

echo -e "${GREEN}:: [OK] Pacotes de jogos instalados e configurados.${NC}"
echo ""

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
echo -e "     - Pressione ${BLUE}Super + D${NC} para abrir o inicializador ${GREEN}Rofi${NC}."
echo -e "     - No terminal, digite ${GREEN}thunar${NC} para o gerenciador gráfico ou ${GREEN}yazi${NC} para o terminal."
echo ""
echo -e "  3. Agora você está pronto para clonar e aplicar os arquivos de configuração"
echo -e "     (dotfiles) do Keyitdev em ~/.config/i3 e ~/.config/polybar !"
echo ""
echo -e "  ${YELLOW}🎮 Jogos — Recursos Instalados:${NC}"
echo -e "     ✓ Steam + Proton GE (padrão configurado via script)"
echo -e "     ✓ Gamemode + MangoHud + Gamescope + Wine + Lutris"
echo -e "     ✓ Overlay MangoHud configurado em ~/.config/MangoHud/MangoHud.conf"
echo -e "     ✓ Atalho otimizado: ${GREEN}~/ark.sh${NC}"
echo -e "     ✓ Script auxiliar: ${GREEN}~/.local/bin/steam-proton-default${NC} (se falhou acima)"
echo ""
echo -e "  ${YELLOW}⚙️  Para o Ark: Survival Ascended:${NC}"
echo -e "     1. Instale o jogo no Steam"
echo -e "     2. Execute: ${GREEN}~/ark.sh${NC}"
echo -e "     3. Ou configure manualmente nas propriedades do jogo:"
echo -e "        ${GREEN}gamemoderun mangohud PROTON_HEAP_DELAY_FREEING=1 %command%${NC}"
echo -e "     4. Proton GE já configurado como padrão. Se não funcionar:"
echo -e "        ${GREEN}~/.local/bin/steam-proton-default${NC}"
echo -e "     5. Atualize o Proton GE quando quiser pelo ${GREEN}ProtonUp-Qt${NC}"
echo -e "     6. Para eliminar tearing no i3wm com NVIDIA + Vulkan:"
echo -e "        ${GREEN}gamescope -w 2560 -h 1440 -r <REFRESH> -- %command%${NC}"
