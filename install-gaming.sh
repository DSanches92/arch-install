#!/usr/bin/env bash
#
# Stack de Jogos (Steam, Proton GE, Gamemode, MangoHud)
# Customizado para: Danilo (Arch Linux + Zen Kernel + RTX 2060)
#
# O wine (com wine-mono e wine-gecko) vem do post-install.sh.
#

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
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

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║        STACK DE JOGOS — Steam / Proton GE / MangoHud     ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#------------------------------------------------------------------------------#
# 1. STEAM, PROTON GE, OTIMIZAÇÕES
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [1/3] Instalando Steam, Gamemode, MangoHud, Gamescope, Proton GE...${NC}"

# proton-ge-custom-bin: Proton GE no sistema, atualizado junto com o paru -Syu.
# python-vdf: usado para editar o config.vdf do Steam com segurança (passo 2).
paru -S --needed --noconfirm \
    steam \
    gamemode lib32-gamemode \
    mangohud lib32-mangohud \
    gamescope \
    lutris \
    winetricks \
    python-vdf \
    proton-ge-custom-bin

echo -e "${YELLOW}:: Adicionando $USER ao grupo gamemode...${NC}"
sudo usermod -aG gamemode "$USER"

#------------------------------------------------------------------------------#
# 2. MANGOHUD E PROTON GE COMO PADRÃO NO STEAM
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [2/3] Configurando MangoHud e Proton GE...${NC}"

mkdir -p ~/.config/MangoHud
cat > ~/.config/MangoHud/MangoHud.conf << 'EOF'
# MangoHud — overlay de FPS e hardware (Shift_R+F12 liga/desliga)
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

# Script auxiliar: define o Proton GE como padrão para todos os jogos
# (o mesmo que Steam → Configurações → Compatibilidade). Fica em ~/.local/bin
# para poder ser rodado de novo depois do primeiro login no Steam.
mkdir -p ~/.local/bin
cat > ~/.local/bin/steam-proton-default << 'SCRIPTEOF'
#!/usr/bin/env bash
#
# Define o Proton GE (pacote proton-ge-custom-bin) como ferramenta de
# compatibilidade padrão do Steam, editando só o CompatToolMapping do
# config.vdf. Faz backup do arquivo antes e não roda com o Steam aberto
# (o Steam reescreve o config.vdf ao fechar e desfaria a mudança).
#
set -euo pipefail

TOOL_VDF="/usr/share/steam/compatibilitytools.d/proton-ge-custom/compatibilitytool.vdf"
STEAM_CFG="$HOME/.local/share/Steam/config/config.vdf"

if [[ ! -f "$TOOL_VDF" ]]; then
    echo "Proton GE não encontrado ($TOOL_VDF)."
    echo "Instale com: paru -S proton-ge-custom-bin"
    exit 1
fi
if [[ ! -f "$STEAM_CFG" ]]; then
    echo "Config do Steam não encontrada ($STEAM_CFG)."
    echo "Abra o Steam uma vez, faça login, feche e rode este script de novo."
    exit 1
fi
if pgrep -x steam &>/dev/null; then
    echo "O Steam está aberto. Feche o Steam (Steam → Sair) e rode de novo."
    exit 1
fi

BACKUP="$STEAM_CFG.bak-$(date +%Y%m%d-%H%M%S)"
cp -p "$STEAM_CFG" "$BACKUP"

# Sai com 0 quando alterou, 3 quando já estava certo, outro código em erro.
rc=0
python3 - "$TOOL_VDF" "$STEAM_CFG" << 'PY' || rc=$?
import os, sys, tempfile
import vdf

tool_vdf, steam_cfg = sys.argv[1], sys.argv[2]

# Nome interno do Proton GE (o pacote -bin usa "Proton-GE").
with open(tool_vdf, encoding="utf-8") as f:
    tools = vdf.load(f, mapper=vdf.VDFDict)
names = list(tools["compatibilitytools"]["compat_tools"].keys())
if len(names) != 1:
    sys.exit(f"Esperava 1 ferramenta em {tool_vdf}, achei: {names}")
ge_name = names[0]

# VDFDict preserva a ordem e as chaves duplicadas do arquivo original.
with open(steam_cfg, encoding="utf-8") as f:
    cfg = vdf.load(f, mapper=vdf.VDFDict)

def child(d, key):
    """Busca (ou cria) a subchave, sem diferenciar maiúsculas de minúsculas."""
    for k in d.keys():
        if k.lower() == key.lower():
            return d[k]
    d[key] = vdf.VDFDict()
    return d[key]

node = cfg
for key in ("InstallConfigStore", "Software", "Valve", "Steam", "CompatToolMapping"):
    node = child(node, key)

current = node.get("0")
if current is not None and current.get("name") == ge_name:
    print(f"Proton GE ({ge_name}) já é o padrão. Nada a fazer.")
    sys.exit(3)

# "0" é o mapeamento padrão para todos os jogos. Os mapeamentos por jogo
# (chaves com o App ID) não são tocados.
node.remove_all_for("0")
entry = vdf.VDFDict()
entry["name"] = ge_name
entry["config"] = ""
entry["priority"] = "75"
node["0"] = entry

# Grava num arquivo temporário e troca no final: se algo falhar no meio,
# o config.vdf original continua intacto.
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(steam_cfg), prefix=".config.vdf.")
with os.fdopen(fd, "w", encoding="utf-8") as f:
    vdf.dump(cfg, f, pretty=True)
os.chmod(tmp, os.stat(steam_cfg).st_mode & 0o777)
os.replace(tmp, steam_cfg)
print(f"Proton GE ({ge_name}) definido como padrão no Steam.")
PY

case "$rc" in
    0) echo "Backup do config anterior: $BACKUP" ;;
    3) rm -f "$BACKUP" ;;
    *) rm -f "$BACKUP"; echo "Falha ao editar o config.vdf; nada foi alterado."; exit "$rc" ;;
esac
SCRIPTEOF
chmod +x ~/.local/bin/steam-proton-default

echo -e "${YELLOW}:: Definindo o Proton GE como padrão no Steam...${NC}"
if ! ~/.local/bin/steam-proton-default; then
    echo -e "${YELLOW}:: Não deu para aplicar agora. Depois do primeiro login no Steam, feche-o e rode:${NC}"
    echo -e "     ${GREEN}steam-proton-default${NC}"
    echo -e "${YELLOW}   Ou manualmente: Steam → Configurações → Compatibilidade → Proton-GE.${NC}"
fi

#------------------------------------------------------------------------------#
# 3. LIMPEZA DO ~/ark.sh ANTIGO
#------------------------------------------------------------------------------#
# O ~/ark.sh só aplicava as variáveis se o Steam ainda estivesse fechado. As
# opções de inicialização do jogo no Steam (ver o final) funcionam sempre.
echo -e "${CYAN}:: [3/3] Verificando o ~/ark.sh antigo...${NC}"
if [[ -f ~/ark.sh ]]; then
    ARK_BACKUP=~/ark.sh.bak-"$(date +%Y%m%d-%H%M%S)"
    mv ~/ark.sh "$ARK_BACKUP"
    echo -e "${YELLOW}:: ~/ark.sh renomeado para $ARK_BACKUP. Use as opções de inicialização abaixo.${NC}"
else
    echo -e "    Nada a fazer."
fi

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Stack de jogos instalado com sucesso!                  ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}🎮 Recursos instalados:${NC}"
echo -e "     ✓ Steam + Proton GE (proton-ge-custom-bin, atualiza com o paru -Syu)"
echo -e "     ✓ Gamemode + MangoHud + Gamescope + Lutris + Winetricks"
echo -e "     ✓ Overlay MangoHud em ~/.config/MangoHud/MangoHud.conf"
echo -e "     ✓ Script auxiliar: ${GREEN}steam-proton-default${NC} (Proton GE como padrão)"
echo ""
echo -e "  ${YELLOW}⚙️  Ark: Survival Ascended (App ID 2399830):${NC}"
echo -e "     Steam → Biblioteca → botão direito no jogo → Propriedades → Opções de inicialização:"
echo -e "        ${GREEN}PROTON_HEAP_DELAY_FREEING=1 gamemoderun mangohud %command%${NC}"
echo -e "     As variáveis vêm antes dos comandos; depois do %command% elas virariam argumento do jogo."
echo ""
echo -e "  ${YELLOW}🖥️  Gamescope (força resolução/tela cheia no Hyprland), opcional:${NC}"
echo -e "        ${GREEN}gamescope -W 2560 -H 1080 -r 75 -f -- %command%${NC}"
echo ""
echo -e "  ${YELLOW}Nota:${NC} faça logout/login para o grupo gamemode valer. Este script não reinicia o sistema."
