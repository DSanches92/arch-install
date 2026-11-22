# arch-install

Scripts que instalam e configuram o meu desktop **Arch Linux** do zero: do pendrive bootável até o Hyprland pronto, com drivers, áudio, otimizações, snapshots e o ambiente de jogos.

Os dotfiles do Hyprland ficam em outro repositório: [my-hyprland](https://github.com/DSanches92/my-hyprland).

## Hardware alvo

| Componente | Modelo |
|---|---|
| CPU | AMD Ryzen 5 3600 |
| GPU | NVIDIA RTX 2060 |
| Armazenamento | NVMe 1 TB (BTRFS) |
| Memória | 16 GB |
| Kernel | `linux-zen` |
| Boot | UEFI + GRUB |

> ⚠️ Os scripts **apagam discos**, gravam com `dd` e editam GRUB/mkinitcpio. Leia cada um antes de rodar e ajuste o bloco de configurações no topo (usuário, hostname, locale etc.).

## Scripts

| Script | Onde roda | O que faz |
|---|---|---|
| `make-bootable.sh` | Numa máquina já instalada | Grava a ISO no pendrive e copia os scripts para a partição FAT dele |
| `install-arch-linux.sh` | Live USB, como root | Particiona, cria os subvolumes BTRFS, instala a base e configura o sistema no chroot |
| `post-install.sh` | 1º boot, como usuário | NVIDIA, PipeWire, otimizações, zsh + Oh My Zsh, nvm, bun e snapper |
| `install-hyprland.sh` | Como usuário | Hyprland, apps, SDDM e os dotfiles do `my-hyprland` |
| `install-gaming.sh` | Como usuário (opcional) | Steam, Proton GE, gamemode, MangoHud, gamescope e Lutris |
| `install-i3wm.sh` | (legado) | Alternativa antiga com i3wm, sem manutenção |

## Passo a passo

### 1. Criar o pendrive

```bash
./make-bootable.sh /dev/sdX ~/Downloads/archlinux-AAAA.MM.DD-x86_64.iso
```

- Mostra o disco e pede confirmação antes de apagar.
- Recusa o disco do sistema: se alguma partição estiver montada em `/`, `/boot` ou `/home`, ele para.
- Use `--no-scripts` para gravar só a ISO.

### 2. Instalar a base (live USB)

```bash
mount /dev/sdX2 /mnt          # partição FAT do pendrive
cp /mnt/install-arch-linux.sh ./
./install-arch-linux.sh
```

- **Particionamento (GPT):** 8 GB de swap, 600 MB de EFI e o resto em BTRFS.
- **Subvolumes:** `@`, `@home`, `@cache`, `@log` e `@.snapshots`.
- O script pergunta o disco e as senhas, instala a base com o `pacstrap` e entra sozinho no chroot.
- No chroot, configura:
  - locale `pt_BR.UTF-8` e teclado `br-abnt2`;
  - o usuário (com `sudo`);
  - GRUB, NetworkManager, ufw e sincronização de hora;
  - o `paru`, compilado do AUR.

### 3. Pós-instalação (1º boot)

```bash
./post-install.sh
```

- **NVIDIA:** `nvidia-open-dkms`, DRM KMS, módulos no initramfs e o nouveau bloqueado.
- **Áudio:** PipeWire + WirePlumber e codecs.
- **Desempenho:**
  - `amd_pstate=active`;
  - cpupower com `powersave` + EPP `balance_performance`;
  - swappiness 10;
  - scheduler `none` no NVMe;
  - irqbalance e fstrim.
- **Shell:**
  - zsh + Oh My Zsh, com os plugins autosuggestions, syntax-highlighting e histdb;
  - nvm e bun pelos instaladores oficiais.
- **Snapshots:** snapper + grub-btrfs, reaproveitando o subvolume `@.snapshots`.
- **Extras:** samba, podman e wine.

### 4. Hyprland

```bash
./install-hyprland.sh
```

- Instala o Hyprland e as ferramentas dele:
  - barra e notificações: waybar, dunst;
  - launcher, terminal e arquivos: rofi, alacritty, yazi, thunar;
  - wallpaper, idle e bloqueio: hyprpaper, hypridle, hyprlock;
  - área de transferência e captura de tela: cliphist, hyprshot.
- Instala o Firefox em pt-BR com o corretor ortográfico (`hunspell-pt-br`), além de Bluetooth, keyring e os temas GTK/Qt.
- Instala o SDDM.
- No final, clona o `my-hyprland` e roda o `install.sh` dele, que:
  - copia as configs para `~/.config`;
  - aplica o zsh;
  - instala o tema do SDDM.
- Reinicia ao terminar.

### 5. Jogos (opcional)

```bash
./install-gaming.sh
```

- Instala Steam, `proton-ge-custom-bin`, gamemode, MangoHud, gamescope e Lutris.
- Define o Proton GE como padrão no Steam. Se o Steam ainda não foi aberto, faça o primeiro login, feche o Steam e rode `steam-proton-default`.
- Opções de inicialização sugeridas para um jogo no Steam:

  ```
  PROTON_HEAP_DELAY_FREEING=1 gamemoderun mangohud %command%
  ```

## Validação

Não há suíte de testes. Para checar a sintaxe:

```bash
bash -n <script>
shellcheck <script>   # opcional
```

Para testar de verdade, use uma máquina virtual (QEMU/virt-manager com UEFI). Nunca rode os scripts na máquina em uso só para testar.

---

<p align="center">
  Criado com ❤️ por <a href="https://github.com/DSanches92">Danilo Sanches</a>
</p>
