#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico i3wm
# Customizado para: Danilo (Arch Linux + Zen Kernel)
#
# Terminal: Kitty | Gerenciador de Arquivos: Thunar & Yazi
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
# 2. INSTALAÇÃO DOS PACOTES DA INTERFACE GRÁFICA (PACMAN)
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [1/6] Instalando i3wm e pacotes gráficos essenciais do Pacman...${NC}"

sudo pacman -S --needed --noconfirm \
    i3-wm \
    xorg-server \
    xorg-xinit \
    lightdm \
    lightdm-gtk-greeter \
    picom \
    rofi \
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
echo -e "${BLUE}:: [2/6] Instalando Kitty, Thunar (e utilitários) e Yazi...${NC}"

# Thunar + Integrações de mídia, compactação e volume
sudo pacman -S --needed --noconfirm \
    kitty \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    thunar-media-tags-plugin \
    gvfs \
    tumbler \
    ffmpegthumbnailer \
    yazi \
    file-roller

#------------------------------------------------------------------------------#
# 4. FONTES E TEMAS (ESSENCIAIS PARA O VISUAL DO KEYITDEV)
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [3/6] Instalando Fontes de Ícones (Nerd Fonts) e Temas...${NC}"

# Fontes e utilitários estéticos via Pacman
sudo pacman -S --needed --noconfirm \
    ttf-roboto-mono \
    ttf-opensans \
    papirus-icon-theme \
    lxappearance \
    btop \
    fastfetch

# Componentes estéticos da comunidade (AUR via Paru)
# polybar (barra de status), i3lock-color (tela de bloqueio linda com blur) e ttf-iosevka-nerd
echo -e "${YELLOW}:: Compilando/Instalando pacotes do AUR (Polybar, i3lock-color, Fontes)...${NC}"
paru -S --needed --noconfirm \
    polybar \
    i3lock-color \
    ttf-iosevka-nerd \
    networkmanager-dmenu-git

#------------------------------------------------------------------------------#
# 5. AJUSTES DE CONFIGURAÇÃO E SERVIÇOS
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [4/6] Habilitando serviços do sistema (LightDM e Bluetooth)...${NC}"

# Habilitar o gerenciador de login LightDM
sudo systemctl enable lightdm.service

# Habilitar serviço do Bluetooth
sudo systemctl enable --now bluetooth.service

# Criar os diretórios padrões de configuração para evitar erros de inicialização
echo -e "${BLUE}:: Criando diretórios padrão em ~/.config...${NC}"
mkdir -p ~/.config/{i3,polybar,rofi,dunst,kitty,yazi}

# Se não houver uma configuração padrão do i3, cria uma inicial para não dar tela preta
if [ ! -f ~/.config/i3/config ]; then
    echo ":: Gerando arquivo de configuração inicial básico para o i3..."
    echo "exec_always --no-startup-id picom -b" > ~/.config/i3/config
    echo "exec_always --no-startup-id nm-applet" >> ~/.config/i3/config
    echo "exec_always --no-startup-id /usr/lib/mate-polkit/polkit-mate-authentication-agent-1" >> ~/.config/i3/config
    echo "bindsym Mod4+Return exec kitty" >> ~/.config/i3/config
    echo "bindsym Mod4+d exec rofi -show drun" >> ~/.config/i3/config
fi

#------------------------------------------------------------------------------#
# 6. CONFIGURAÇÃO DO KITTY COMO TERMINAL PADRÃO DO SISTEMA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [5/6] Definindo o Kitty como terminal padrão...${NC}"
export TERMINAL=kitty
echo "export TERMINAL=kitty" >> ~/.bashrc

#------------------------------------------------------------------------------#
# 7. INSTALAÇÃO DE PACOTES PARA JOGOS (STEAM, PROTON, OTIMIZAÇÕES)
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [6/6] Instalando pacotes para jogos e otimizações de desempenho...${NC}"

# Steam + Gamemode + MangoHud + Gamescope + Wine (repositórios oficiais)
echo -e "${YELLOW}:: Instalando Steam, Gamemode, MangoHud, Gamescope e Wine...${NC}"
sudo pacman -S --needed --noconfirm \
    steam \
    gamemode lib32-gamemode \
    mangohud lib32-mangohud \
    gamescope \
    lutris \
    wine winetricks wine-mono wine-gecko \
    dxvk

# Proton GE (AUR) — essencial para Ark: Survival Ascended (Unreal Engine 5)
echo -e "${YELLOW}:: Instalando Proton GE e ProtonUp-Qt do AUR...${NC}"
paru -S --needed --noconfirm \
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
cat > ~/.config/MangoHud/MangoHud.conf <<-'EOF'
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
echo -e "  1. Reinicie o sistema para subir a tela de login (LightDM):"
echo -e "     ${GREEN}sudo reboot${NC}"
echo ""
echo -e "  2. Quando fizer login na interface i3wm:"
echo -e "     - Pressione ${BLUE}Super + Enter${NC} para abrir o seu novíssimo terminal ${GREEN}Kitty${NC}."
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
