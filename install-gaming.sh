#!/usr/bin/env bash
#
# Stack de Jogos (Steam, Proton GE, Gamemode, MangoHud)
# Customizado para: Danilo (Arch Linux + Zen Kernel + RTX 2060)
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[ERRO] Não execute este script como root/sudo diretamente.${NC}"
    exit 1
fi

if ! command -v paru &> /dev/null; then
    echo -e "${RED}[ERRO] O assistente AUR 'paru' não foi encontrado.${NC}"
    echo "Garanta que install-arch-linux.sh e post-install.sh já rodaram."
    exit 1
fi

echo -e "${BLUE}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║        STACK DE JOGOS — Steam / Proton GE / MangoHud     ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#------------------------------------------------------------------------------#
# 1. STEAM, PROTON, OTIMIZAÇÕES
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [1/3] Instalando Steam, Gamemode, MangoHud, Gamescope, Proton GE...${NC}"

paru -S --needed --noconfirm \
    steam \
    gamemode lib32-gamemode \
    mangohud lib32-mangohud \
    gamescope \
    lutris \
    winetricks \
    proton-ge-custom \
    protonup-qt

echo -e "${YELLOW}:: Adicionando $USER ao grupo gamemode...${NC}"
sudo usermod -aG gamemode "$USER"

#------------------------------------------------------------------------------#
# 2. CONFIGURAÇÕES DE OTIMIZAÇÃO PARA JOGOS
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [2/3] Configurando MangoHud e Proton GE...${NC}"

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

#------------------------------------------------------------------------------#
# 3. SCRIPT DE LANÇAMENTO — ARK: SURVIVAL ASCENDED
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [3/3] Criando ~/ark.sh (lançamento otimizado para Ark: Survival Ascended)...${NC}"
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

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Stack de jogos instalado com sucesso!                  ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}🎮 Recursos instalados:${NC}"
echo -e "     ✓ Steam + Proton GE (padrão configurado via script)"
echo -e "     ✓ Gamemode + MangoHud + Gamescope + Wine + Lutris"
echo -e "     ✓ Overlay MangoHud em ~/.config/MangoHud/MangoHud.conf"
echo -e "     ✓ Atalho otimizado: ${GREEN}~/ark.sh${NC}"
echo -e "     ✓ Script auxiliar: ${GREEN}~/.local/bin/steam-proton-default${NC} (se falhou acima)"
echo ""
echo -e "  ${YELLOW}⚙️  Para o Ark: Survival Ascended:${NC}"
echo -e "     1. Instale o jogo no Steam"
echo -e "     2. Execute: ${GREEN}~/ark.sh${NC}"
echo -e "     3. Ou configure manualmente nas propriedades do jogo:"
echo -e "        ${GREEN}gamemoderun mangohud PROTON_HEAP_DELAY_FREEING=1 %command%${NC}"
echo -e "     4. Para eliminar tearing no i3wm com NVIDIA + Vulkan:"
echo -e "        ${GREEN}gamescope -w 2560 -h 1440 -r <REFRESH> -- %command%${NC}"
echo ""
echo -e "  ${YELLOW}Nota:${NC} este script não reinicia o sistema automaticamente."
