# Winmarchy VFIO

Overlay do [Omarchy](https://omarchy.org/) para o atalho **Windows 11 (VFIO)**.

Antes de subir a VM, o plugin mostra o que está segurando a RTX, pede confirmação, encerra esses processos e inicia o Windows + Looking Glass. Depois tenta reabrir os apps uma vez.

Hyprland na NVIDIA não é encerrado: nesse caso o overlay pede para sair da sessão.

## Instalar

```sh
omarchy plugin add https://github.com/alcure/winmarchy-vfio.git --enable
```

Aponte o atalho do Windows 11 para `bin/start` do plugin (ele chama o overlay e, se o shell não responder, cai no `win11-vfio start`).

## Uso

1. Abra **Windows 11 (VFIO)** (ou `omarchy-shell shell summon psycrow.winmarchy '{}'`).
2. Confira a lista de processos na RTX.
3. **Enter** encerra e inicia a VM; **Esc** cancela.

Não edita `/usr/share/omarchy`.

## Requisitos

- Omarchy / Hyprland
- VM libvirt `win11` e o helper `win11-vfio` no PATH
- GPU NVIDIA em passthrough VFIO
