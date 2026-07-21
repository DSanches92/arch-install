#!/usr/bin/env bash
#
# Cria um pendrive bootável com dd e copia os scripts de instalação
# Uso: ./make-bootable.sh <dispositivo> <arquivo.iso>
# Ex.: ./make-bootable.sh /dev/sdb ~/Downloads/archlinux-2026.iso
#

set -euo pipefail

# Cores para saída do terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Scripts que serão copiados para o pendrive
SCRIPTS=(
    "install-arch-linux.sh"
    "post-install.sh"
    "install-i3wm.sh"
)

echo -e "${BLUE}"
echo "  ╔═══════════════════════════════════════════════════════════"
echo "    > CRIAÇÃO DE PENDRIVE BOOTÁVEL"
echo "  ╚═══════════════════════════════════════════════════════════"
echo -e "${NC}"

#------------------------------------------------------------------------------#
#                         VALIDAÇÃO DOS ARGUMENTOS                              #
#------------------------------------------------------------------------------#
if [[ $# -ne 2 ]]; then
    echo -e "${RED}[ERRO] Número de argumentos inválido.${NC}"
    echo -e "${YELLOW}Uso:${NC} $0 ${GREEN}<dispositivo> <arquivo.iso>${NC}"
    echo ""
    echo "  Exemplos:"
    echo "    $0 /dev/sdb ~/Downloads/archlinux.iso"
    echo "    $0 /dev/sdc ~/Downloads/ubuntu.iso"
    exit 1
fi

DISK="$1"
ISO="$2"

# Valida se o dispositivo existe
if [[ ! -b "$DISK" ]]; then
    echo -e "${RED}[ERRO] '$DISK' não existe ou não é um dispositivo de bloco.${NC}"
    echo -e "${YELLOW}:: Discos disponíveis:${NC}"
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v '^NAME' | grep disk
    exit 1
fi

# Valida se é um disco inteiro (não partição)
if ! lsblk -no TYPE "$DISK" 2>/dev/null | grep -q '^disk$'; then
    echo -e "${RED}[ERRO] '$DISK' não parece ser um disco inteiro (é partição?).${NC}"
    echo -e "${YELLOW}:: Use o disco inteiro, ex: /dev/sdb, não /dev/sdb1${NC}"
    exit 1
fi

# Valida se o arquivo ISO existe
if [[ ! -f "$ISO" ]]; then
    echo -e "${RED}[ERRO] '$ISO' não encontrado.${NC}"
    exit 1
fi

#------------------------------------------------------------------------------#
#                        CONFIRMAÇÃO DO USUÁRIO                                #
#------------------------------------------------------------------------------#
echo -e "${YELLOW}:: Dispositivo alvo:${NC} $DISK"
echo -e "${YELLOW}:: Arquivo ISO:${NC}     $ISO"
echo ""

ISO_SIZE=$(stat -c %s "$ISO" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "desconhecido")
echo -e "  Tamanho da ISO: ${GREEN}$ISO_SIZE${NC}"
echo ""

lsblk -f "$DISK"
echo ""

echo -e "${RED}"
echo "  ╔═══════════════════════════════════════════════════════════"
echo "    > ATENÇÃO: TODOS OS DADOS EM $DISK SERÃO APAGADOS!"
echo "  ╚═══════════════════════════════════════════════════════════"
echo -e "${NC}"

read -r -p "  CONFIRMA? [S/N]: " confirma

confirma=$(echo "$confirma" | tr '[:upper:]' '[:lower:]')
if [[ "$confirma" != "s" && "$confirma" != "sim" ]]; then
    echo -e "${YELLOW}:: Operação cancelada.${NC}"
    exit 0
fi

#------------------------------------------------------------------------------#
#                        LIMPA O PENDRIVE                                      #
#------------------------------------------------------------------------------#
echo ""
echo -e "${BLUE}:: [1/3] Formatação do pendrive...${NC}"
echo -e "${YELLOW}  Desmontando partições existentes...${NC}"
sudo umount {$DISK}* 2>/dev/null || true && echo -e "${GREEN}Partições desmontadas!${NC}"

echo ""
echo -e "${YELLOW}  Limpando assinaturas do disco...${NC}"
sudo wipefs --all --force "$DISK" && echo -e "${GREEN}Assinaturas limpas!${NC}"

echo ""
echo -e "${YELLOW}  Zerando o início do dispositivo...${NC}"
sudo dd if=/dev/zero of="$DISK" bs=1M count=10 status=progress conv=fsync && echo -e "${GREEN}Finalizado!${NC}"

#------------------------------------------------------------------------------#
#                        GRAVAÇÃO COM DD                                       #
#------------------------------------------------------------------------------#
echo ""
echo -e "${BLUE}:: [2/3] Gravando ISO no pendrive...${NC}"
echo -e "${YELLOW}  dd if=$ISO of=$DISK bs=4M oflag=sync status=progress conv=fsync${NC}"
echo ""

sudo dd if="$ISO" of="$DISK" bs=4M oflag=sync status=progress conv=fsync

echo ""
echo -e "${GREEN}:: [OK] ISO gravada.${NC}"

#------------------------------------------------------------------------------#
#                     CÓPIA DOS SCRIPTS PARA O PENDRIVE                        #
#------------------------------------------------------------------------------#
echo ""
echo -e "${BLUE}:: [3/3] Copiando scripts de instalação para o pendrive...${NC}"

# Força o kernel a re-ler a tabela de partições
echo -e "${YELLOW}:: Aguardando o sistema reconhecer as partições...${NC}"
sudo udevadm settle
sudo blockdev --rereadpt "$DISK" 2>/dev/null || sudo partprobe "$DISK" 2>/dev/null || true
sleep 3
sudo udevadm settle

# Diagnóstico: exibe as partições detectadas
echo -e "${YELLOW}:: Partições encontradas:${NC}"
lsblk -lno NAME,SIZE,FSTYPE,TYPE "$DISK" 2>/dev/null | sed 's/^/  /' || echo "  (nenhuma)"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Busca partições que são VFAT/FAT32 (graváveis)
# Arch ISO: sdb1=iso9660(read-only), sdb2=vfat(writable) → usamos a vfat
PARTS_VFAT=$(lsblk -lno NAME,FSTYPE "$DISK" 2>/dev/null | awk '$2 ~ /vfat/ {print $1}')
PART=""

if [[ -n "$PARTS_VFAT" ]]; then
    # Pega a primeira partição vfat encontrada
    PART_VFAT=$(echo "$PARTS_VFAT" | head -1)
    PART="/dev/$PART_VFAT"
    echo -e "${GREEN}:: Partição VFAT encontrada: $PART${NC}"
elif [[ -z "$PART" ]]; then
    # Fallback: pega a última partição (geralmente a maior = dados)
    PART_LAST=$(lsblk -lno NAME "$DISK" | grep -v "^$(basename "$DISK")$" | tail -1)
    if [[ -n "$PART_LAST" ]]; then
        PART="/dev/$PART_LAST"
        echo -e "${YELLOW}:: Nenhuma VFAT encontrada. Tentando última partição: $PART${NC}"
    fi
fi

if [[ -z "$PART" ]]; then
    echo -e "${YELLOW}:: Nenhuma partição encontrada no disco.${NC}"
    echo -e "${YELLOW}:: Os scripts não foram copiados.${NC}"
else
    MOUNT_POINT="/tmp/usb-mount-$$"
    mkdir -p "$MOUNT_POINT"

    echo -e "${YELLOW}:: Montando $PART...${NC}"

    MOUNT_OK=false
    MOUNT_MSG=""

    # Tenta 1: montagem com autodetect + opções de escrita
    if sudo mount -o rw,flush,uid=0,gid=0,fmask=000,dmask=000 "$PART" "$MOUNT_POINT" 2>/dev/null; then
        MOUNT_OK=true
    fi

    # Tenta 2: montagem explicitamente como vfat
    if [[ "$MOUNT_OK" == false ]]; then
        MOUNT_MSG=$(sudo mount -t vfat -o rw,flush,uid=0,gid=0,fmask=000,dmask=000 "$PART" "$MOUNT_POINT" 2>&1)
        if [[ $? -eq 0 ]]; then
            MOUNT_OK=true
        fi
    fi

    # Tenta 3: montagem sem opções extras (último recurso)
    if [[ "$MOUNT_OK" == false ]]; then
        MOUNT_MSG=$(sudo mount "$PART" "$MOUNT_POINT" 2>&1)
        if [[ $? -eq 0 ]]; then
            MOUNT_OK=true
            sudo mount -o remount,rw "$MOUNT_POINT" 2>/dev/null || true
        fi
    fi

    if [[ "$MOUNT_OK" == true ]]; then
        # Garante modo de escrita
        sudo mount -o remount,rw "$MOUNT_POINT" 2>/dev/null || true

        # Verifica se é gravável
        if touch "$MOUNT_POINT/.test-write" 2>/dev/null; then
            rm -f "$MOUNT_POINT/.test-write"
        else
            echo -e "${YELLOW}:: Partição montada mas somente leitura.${NC}"
            echo -e "${YELLOW}:: Tentando forçar escrita com -o remount,rw...${NC}"
            sudo mount -o remount,rw "$MOUNT_POINT" 2>/dev/null || {
                echo -e "${RED}:: Falha ao habilitar escrita. Abortando cópia.${NC}"
                sudo umount "$MOUNT_POINT" 2>/dev/null || true
                MOUNT_OK=false
            }
        fi
    fi

    if [[ "$MOUNT_OK" == true ]]; then
        COPIED=0

        for script in "${SCRIPTS[@]}"; do
            if [[ -f "$SCRIPT_DIR/$script" ]]; then
                sudo cp "$SCRIPT_DIR/$script" "$MOUNT_POINT/"
                sudo chmod +x "$MOUNT_POINT/$script"
                echo -e "  ${GREEN}✓${NC} $script copiado"
                COPIED=$((COPIED + 1))
            else
                echo -e "  ${YELLOW}⚠ $script não encontrado em $SCRIPT_DIR${NC}"
            fi
        done

        sync
        sudo umount "$MOUNT_POINT"
        echo -e "${GREEN}:: [OK] $COPIED script(s) copiado(s) para a raiz do pendrive.${NC}"
    else
        echo -e "${RED}:: Erro ao montar $PART:${NC}"
        echo -e "  ${MOUNT_MSG:-"(sem mensagem de erro)"}"
        echo ""
        echo -e "${YELLOW}:: Os scripts não foram copiados. Copie manualmente:${NC}"
        echo -e "     sudo mount $PART /mnt"
        echo -e "     cp $SCRIPT_DIR/*.sh /mnt/"
    fi

    rm -rf "$MOUNT_POINT"
fi

#------------------------------------------------------------------------------#
#                           EJEÇÃO DO DISPOSITIVO                              #
#------------------------------------------------------------------------------#
echo ""
echo -e "${YELLOW}:: Desmontando e ejetando o dispositivo...${NC}"
# Desmonta qualquer partição que possa ter ficado montada
for p in $(lsblk -lno NAME "$DISK" | grep -v "^$(basename "$DISK")$"); do
    sudo umount "/dev/$p" 2>/dev/null || true
done
sudo eject "$DISK" 2>/dev/null || sudo udisksctl power-off -b "$DISK" 2>/dev/null || \
    echo -e "${YELLOW}:: Não foi possível ejetar. Remova o pendrive manualmente.${NC}"

echo ""
echo -e "${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════"
echo "    > Pendrive bootável criado com sucesso!"
echo "  ╚═══════════════════════════════════════════════════════════"
echo -e "${NC}"
echo -e "  Dispositivo: ${GREEN}$DISK${NC}"
echo -e "  ISO:         ${GREEN}$ISO${NC}"
echo ""
echo -e "  ${YELLOW}Pronto! O pendrive pode ser removido com segurança.${NC}"
echo ""
echo -e "  ${YELLOW}📌 Ao bootar o Arch Live, monte a partição EFI para acessar os scripts:${NC}"
echo -e "     ${GREEN}lsblk${NC}                             # Descubra o dispositivo (ex: sda, sdb)"
echo -e "     ${GREEN}sudo mount /dev/sdX2 /mnt${NC}         # Monte a partição VFAT (troque X pelo letra)"
echo -e "     ${GREEN}ls /mnt/${NC}                          # Scripts estarão aqui"
echo -e "     ${GREEN}cp /mnt/install-arch-linux.sh ./${NC}  # Mova o script para a raiz do Arch Live"
echo -e "     ${GREEN}./install-arch-linux.sh${NC}           # Inicie o script para instalação automatizada"
