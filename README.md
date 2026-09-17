# Winmarchy VFIO

Omarchy overlay for **Windows 11**. UI: **Português (Brasil)** and **English (US)**.

## Ideal setup

This is the layout the plugin is built around. One Windows 11 disk, two ways to look at it.

```
Linux (Omarchy / Hyprland on Intel)
        │
        ├─ RTX 5080 on the host          Windows 11 (win11-shared)
        │  Ollama, games, CUDA           virtio-vga 1920×1080
        │         ▲                      SPICE / virt-viewer
        │         │                      no GPU passthrough
        │         └──────────────────►   Viewer: virt-viewer
        │
        └─ RTX released for VFIO         Windows 11 (win11)
           Host keeps Intel              RTX passthrough + IVSHMEM
                                         Looking Glass Host → kvmfr
                                         Client: looking-glass-client
```

| Key | Domain | RTX | Display | Use when |
|-----|--------|-----|---------|----------|
| **Enter** | `win11` | Exclusive to Windows | Looking Glass | Games, NVENC, CUDA in the guest |
| **S** | `win11-shared` | Stays on Linux | SPICE at **1920×1080** | Desktop in Windows while Linux still uses the 5080 |

Looking Glass needs a DXGI capture adapter inside Windows. In **S** the 5080 stays on Linux, so the guest only has VirtIO DOD + a virtual display — the Host starts and exits (`Failed to locate a valid output device`). **S** therefore uses `virt-viewer` at a fixed 1920×1080 (no client-driven resize to 3440). **Enter** is the Looking Glass path.

The 5080 cannot be in both OSes at once. Daily use:

1. Leave Hyprland on the Intel iGPU.
2. Use **S** for Windows with the RTX still on Linux (1920×1080).
3. Use **Enter** when the guest must own the 5080 (Looking Glass).

The plugin still registers `WinmarchyLgHost` for VFIO logon. It disables the Looking Glass **service** (session 0 cannot capture DXGI).

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
3. **Enter** frees the GPU and starts VFIO + Looking Glass; **S** opens 1920×1080 with the RTX on Linux; **Esc** cancels.

**F12** toggles input capture. In VFIO that is Looking Glass; in **S** it releases the `virt-viewer` cursor.

Default resolutions: **1920×1080** on VirtIO (`win11-shared`) and **3440×1440** on VFIO (`win11`, Looking Glass / NVIDIA).

CLI: `win11-vfio start` (VFIO) or the plugin `bin/start shared` (1920×1080, RTX on Linux).

Does not edit `/usr/share/omarchy`.

## Requirements

- Omarchy / Hyprland on the iGPU
- libvirt VM `win11`, generated `win11-shared` (same disk, virtio-vga 1920×1080, IVSHMEM for VFIO)
- Looking Glass Host inside Windows for **Enter** / VFIO; `virt-viewer` for **S**
- NVIDIA passthrough only for the VFIO profile

---

## Português (Brasil)

Esta é a configuração que o plugin trata como **ideal**: um único disco do Windows 11 e dois visores.

- **Enter** — a RTX vai para o Windows (VFIO). Linux fica na Intel. Looking Glass com DXGI da NVIDIA.
- **S** — a RTX **permanece no Linux**. Windows em **1920×1080** no VirtIO, visor SPICE (`virt-viewer`). Sem GPU no guest o Host do Looking Glass não tem o que capturar.

Não dá para a 5080 estar nos dois sistemas ao mesmo tempo.

### Instalar

```sh
omarchy plugin add https://github.com/alcure/winmarchy-vfio.git --enable
~/.config/omarchy/plugins/psycrow.winmarchy/bin/setup
```

```sh
~/.config/omarchy/plugins/psycrow.winmarchy/bin/setup --locale pt-BR
```

Aponte o atalho do Windows 11 para `bin/start`. Idioma em `~/.config/omarchy/winmarchy-vfio.json`.

### Uso

1. Abra **Windows 11 (VFIO)**.
2. Confira o que está na RTX.
3. **Enter** = VFIO + Looking Glass; **S** = 1920×1080 com a RTX no Linux; **Esc** cancela.

**F12** no VFIO trava e destrava a captura do Looking Glass. No modo S, F12 solta o rato do `virt-viewer`. Com a captura solta, Super e atalhos do Omarchy voltam ao Linux.

Resoluções padrão: **1920×1080** no VirtIO (`win11-shared`) e **3440×1440** no VFIO (`win11`, Looking Glass / NVIDIA).
