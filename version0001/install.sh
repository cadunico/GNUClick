#!/usr/bin/env bash
set -e

# install.sh - Instalador completo para PhotoBooth (Debian / Ubuntu / Raspberry Pi OS)
# - Requisitos: sudo (para apt), python3
# - Cria venv em ./venv_photobooth (se não existir)
# - Instala pacotes apt (python3-tk, inkscape) e bibliotecas auxiliares
# - Ativa venv e instala pacotes pip (opencv-python, pillow, cairosvg, playsound)
# - Cria pastas molduras/, fotos/, sons/ com permissão 777
# - Gera um arquivo sons/click.wav simples via python
# - No final, executa photobooth.py dentro do venv

if [[ $EUID -ne 0 ]]; then
  echo "Este instalador precisa de sudo para instalar pacotes do sistema."
  echo "Rerun como: sudo $0"
  exit 1
fi

echo "=== PhotoBooth Installer (Debian/Ubuntu / Raspberry Pi OS) ==="

# update apt lists (ask)
read -p "Atualizar lista apt? [Y/n] " upd
upd=${upd:-Y}
if [[ "$upd" =~ ^[Yy] ]]; then
  apt update
fi

echo
echo "Instalando pacotes do sistema necessários (python3-tk, inkscape, libs)..."
apt install -y python3 python3-pip python3-venv python3-tk inkscape >/dev/null

# libs que ajudam o opencv em algumas distribuições
apt install -y libglib2.0-0 libsm6 libxrender1 libxext6 >/dev/null || true

# Create virtualenv
VENV_DIR="$(pwd)/venv_photobooth"
if [[ -d "$VENV_DIR" ]]; then
  echo "Virtualenv já existe em: $VENV_DIR"
else
  echo "Criando virtualenv em: $VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

# Activate venv
echo "Ativando virtualenv..."
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Upgrade pip
pip install --upgrade pip setuptools wheel >/dev/null

# Install pip packages (try in order; cairosvg optional)
PIP_PACKAGES=(
  "opencv-python"
  "Pillow"
  "cairosvg"
  "playsound"
)

echo "Instalando pacotes Python dentro do venv (isso pode demorar)..."
for p in "${PIP_PACKAGES[@]}"; do
  echo " - instalando $p ..."
  # try install; don't exit on failure for cairosvg (some archs)
  if ! pip install "$p"; then
    echo "Aviso: falha ao instalar $p via pip (continuando)."
  fi
done

# Deactivate venv for filesystem ops, but we'll re-activate later for run
deactivate || true

# Create required folders with full permissions
for d in molduras fotos sons; do
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d"
    echo "Criada pasta: $d"
  fi
  chmod 777 "$d"
done

# Generate a short click sound (WAV) using Python (no extra deps)
# This writes sons/click.wav (short 0.18s sine + small attack)
CLICK_WAV="$(pwd)/sons/click.wav"
if [[ ! -f "$CLICK_WAV" ]]; then
  echo "Gerando sons/click.wav (efeito de shutter)..."
  python3 - <<'PY'
import math, wave, struct
fname = "sons/click.wav"
framerate = 44100
duration = 0.18
freq = 1000.0
amplitude = 16000
nframes = int(framerate * duration)
wav = wave.open(fname, 'w')
wav.setnchannels(1)
wav.setsampwidth(2)
wav.setframerate(framerate)
for i in range(nframes):
    # short exponential decay to simulate click
    t = i / framerate
    env = math.exp(-12 * t)
    sample = int(amplitude * env * math.sin(2 * math.pi * freq * t))
    wav.writeframes(struct.pack('<h', sample))
wav.close()
print("WAV criado:", fname)
PY
  chmod 666 "$CLICK_WAV" || true
else
  echo "Arquivo sons/click.wav já existe — pulando geração."
fi

# Ensure photobooth.py exists
if [[ ! -f "photobooth.py" ]]; then
  echo "ERRO: photobooth.py não encontrado no diretório atual!"
  echo "Coloque photobooth.py no mesmo diretório e rode novamente."
  exit 1
fi

# Final: run photobooth.py inside the venv
echo ""
echo "=== Execução final: iniciando photobooth dentro do venv ==="
# Activate and run
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python3 photobooth.py

# End

