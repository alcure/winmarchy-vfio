# Winmarchy VFIO

Omarchy overlay for **Windows 11 (VFIO)**. UI languages: **Português (Brasil)** and **English (US)**.

The overlay lists what is holding the RTX, then you pick a profile:

- **Enter** — stop those processes, start Windows 11 with GPU passthrough + Looking Glass, then try to reopen the apps once.
- **S** — the same Windows 11 disk, no RTX: shared SPICE video (`virt-viewer`). The GPU stays on Linux.

Hyprland on NVIDIA is not killed: VFIO stays blocked, SPICE still works.

---

## Install

```sh
omarchy plugin add https://github.com/alcure/winmarchy-vfio.git --enable
~/.config/omarchy/plugins/psycrow.winmarchy/bin/setup
```

`setup` asks for the language. Non-interactive:

```sh
~/.config/omarchy/plugins/psycrow.winmarchy/bin/setup --locale en-US
# or: --locale pt-BR
```

Point the Windows 11 launcher at the plugin `bin/start`.

Change language later with the same `bin/setup`. The choice is stored in `~/.config/omarchy/winmarchy-vfio.json`.

## Use

1. Open **Windows 11 (VFIO)** (or `omarchy-shell shell summon psycrow.winmarchy '{}'`).
2. Check the RTX process list.
3. **Enter** frees the GPU and starts VFIO; **S** starts shared video; **Esc** cancels.

CLI: `win11-vfio start` (VFIO) or `win11-vfio shared` (SPICE).

Does not edit `/usr/share/omarchy`.

## Requirements

- Omarchy / Hyprland
- libvirt VM `win11`, generated profile `win11-shared` (same disk), and `win11-vfio` on PATH
- NVIDIA GPU passthrough for the Looking Glass profile

---

## Português (Brasil)

Overlay do [Omarchy](https://omarchy.org/) para o atalho **Windows 11 (VFIO)**.

O plugin mostra o que está na RTX e deixa escolher o perfil:

- **Enter** — encerra o que segura a placa, sobe o Windows 11 com passthrough + Looking Glass e tenta reabrir os apps uma vez.
- **S** — o mesmo disco do Windows 11, sem RTX: vídeo SPICE compartilhado (`virt-viewer`). A GPU fica no Linux.

Hyprland na NVIDIA não é encerrado: o VFIO fica bloqueado, mas o modo SPICE continua disponível.

### Instalar

```sh
omarchy plugin add https://github.com/alcure/winmarchy-vfio.git --enable
~/.config/omarchy/plugins/psycrow.winmarchy/bin/setup
```

O `setup` pergunta o idioma. Fora do terminal:

```sh
~/.config/omarchy/plugins/psycrow.winmarchy/bin/setup --locale pt-BR
```

Aponte o atalho do Windows 11 para `bin/start` do plugin. A escolha fica em `~/.config/omarchy/winmarchy-vfio.json`.

### Uso

1. Abra **Windows 11 (VFIO)** (ou `omarchy-shell shell summon psycrow.winmarchy '{}'`).
2. Confira a lista de processos na RTX.
3. **Enter** libera a GPU e inicia o VFIO; **S** inicia o vídeo compartilhado; **Esc** cancela.

CLI: `win11-vfio start` (VFIO) ou `win11-vfio shared` (SPICE).
