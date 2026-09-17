# Winmarchy VFIO

Omarchy overlay for **Windows 11**. UI: **Português (Brasil)** and **English (US)**.

## Ideal setup

This is the layout the plugin is built around. One Windows 11 disk, two ways to look at it, **Looking Glass in both**.

```
Linux (Omarchy / Hyprland on Intel)
        │
        ├─ RTX 5080 on the host          Windows 11 (win11-shared)
        │  Ollama, games, CUDA           virtio-vga + IVSHMEM (kvmfr)
        │         ▲                      Looking Glass Host → kvmfr
        │         │                      no GPU passthrough
        │         └──────────────────►   Client: looking-glass-client
        │
        └─ RTX released for VFIO         Windows 11 (win11)
           Host keeps Intel              RTX passthrough + IVSHMEM
                                         Looking Glass Host → kvmfr
                                         Client: looking-glass-client
```

| Key | Domain | RTX | Display | Use when |
|-----|--------|-----|---------|----------|
| **Enter** | `win11` | Exclusive to Windows | Looking Glass | Games, NVENC, CUDA in the guest |
| **S** | `win11-shared` | Stays on Linux | Looking Glass (shared memory, no passthrough) | Desktop in Windows while Linux still uses the 5080 |

SPICE / `virt-viewer` is only a fallback (install console, rescue). It is **not** the recommended viewer: it tops out around tens of FPS. Looking Glass copies frames through `kvmfr`, so the host compositor stays up and the guest can still feel close to native refresh for desktop use.

The 5080 cannot be in both OSes at once. Ideal daily use:

1. Leave Hyprland on the Intel iGPU.
2. Keep the Looking Glass Host running inside Windows (same install as VFIO).
3. Prefer **S** whenever Windows does not need the NVIDIA card.
4. Use **Enter** only when the guest must own the 5080.

Hyprland on NVIDIA is not killed. VFIO stays blocked in that case; the shared Looking Glass profile still starts.

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
3. **Enter** frees the GPU and starts VFIO; **S** starts Looking Glass without passthrough; **Esc** cancels.

**F12** toggles Looking Glass input capture (same in both profiles). Captured: mouse and keyboard stay in Windows. Released: Super/Omarchy shortcuts work on Linux.

Default resolutions: **1920×1080** on VirtIO (`win11-shared`) and **3440×1440** on VFIO (`win11`, Looking Glass / NVIDIA).

CLI: `win11-vfio start` (VFIO) or the plugin `bin/start shared` (Looking Glass, RTX on Linux).

Does not edit `/usr/share/omarchy`.

## Requirements

- Omarchy / Hyprland on the iGPU
- libvirt VM `win11`, generated `win11-shared` (same disk, IVSHMEM/`kvmfr`, virtio-vga)
- Looking Glass Host inside Windows and `looking-glass-client` on the host
- NVIDIA passthrough only for the VFIO profile

---

## Português (Brasil)

Esta é a configuração que o plugin trata como **ideal**: um único disco do Windows 11 e **Looking Glass nos dois perfis**.

- **Enter** — a RTX vai para o Windows (VFIO). Linux fica na Intel. Melhor FPS e CUDA/NVENC no guest.
- **S** — a RTX **permanece no Linux**. O Windows desenha num adaptador virtual; o Host do Looking Glass copia o ecrã para o `kvmfr`. Hyprland, Ollama e o resto seguem no ar.

Não dá para a 5080 estar nos dois sistemas ao mesmo tempo. O SPICE existe só como consola de recurso: não é o visor recomendado.

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
3. **Enter** = VFIO; **S** = Looking Glass com a RTX no Linux; **Esc** cancela.

**F12** trava e destrava a captura (rato e teclado no Windows). Com a captura solta, Super e atalhos do Omarchy voltam ao Linux.

Resoluções padrão: **1920×1080** no VirtIO (`win11-shared`) e **3440×1440** no VFIO (`win11`, Looking Glass / NVIDIA).
