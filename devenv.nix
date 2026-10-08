{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  # CUDA build of llama-cpp. The explicit override is what enables CUDA;
  # the top-level pkgs already has allowUnfree set by devenv (devenv.yaml).
  llamaCppPackage = pkgs.llama-cpp.override { cudaSupport = true; };

  # Native local GPU inference wrapper
  runServer = pkgs.writeShellScriptBin "hack" ''
    echo "🤖 Launching local GPU inference engine (Coding Optimization)..."
    export CUDA_DEVICE_ORDER=PCI_BUS_ID

    if command -v nvidia-smi > /dev/null 2>&1; then
      GPU0=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader -i 0 | head -1)
      case "$GPU0" in
        *"5060 Ti"*) ;;
        *) echo "❌ CUDA index 0 is '$GPU0', expected RTX 5060 Ti (16GB)." >&2
           echo "   Check mapping: nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader" >&2
           exit 1 ;;
      esac

      GPU_FREE=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader -i 0 | awk '{print $1}')
      if [ "$GPU_FREE" -lt 12000 ]; then
        echo "❌ Only $GPU_FREE MiB free on CUDA index 0; need >= 12000 MiB for the model." >&2
        echo "   Another server is likely holding VRAM: nvidia-smi --query-gpu=index,memory.used,memory.free --format=csv,noheader" >&2
        exit 1
      fi
    fi

    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"

    echo Llama.cpp version number:
    echo ${llamaCppPackage}/bin/llama-server

    LOG=/tmp/llama-server.log
    [ -n "$LLAMA_SERVER_LOG" ] && LOG=$LLAMA_SERVER_LOG
    { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] hack: session log -> $LOG"; \
      ${llamaCppPackage}/bin/llama-server \
        --log-timestamps \
        --log-prefix \
        -hf ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S \
        -ngl 99 \
        -ctk q4_0 \
        -ctv q4_0 \
        -c 90000 \
        --image-min-tokens 1024 \
        --flash-attn on \
        -ts 2,1 \
        -sm tensor \
        --agent \
        --spec-type draft-mtp \
        --spec-draft-n-max 2 \
        --temperature 0.1 \
        --top-p 0.95 \
        --min-p 0.05 \
        --repeat-penalty 1.05 \
        --metrics \
        --chat-template-kwargs '{"reasoning_effort":"xhigh"}' "$@" 2>&1; } | tee "$LOG"
  '';

  # Pre-flight smoke validation runner
  smokeTest = pkgs.writeShellScriptBin "smoke-test" ''
    PORT=$SMOKE_TEST_PORT
    [ -z "$PORT" ] && PORT=8080
    TIMEOUT=$SMOKE_TEST_TIMEOUT
    [ -z "$TIMEOUT" ] && TIMEOUT=300
    LOG=/tmp/llama-smoke-test.log

    hack --port "$PORT" > "$LOG" 2>&1 &
    PID=$!

    cleanup() {
      pkill -P $PID 2>/dev/null
      kill $PID 2>/dev/null
    }
    trap 'cleanup' EXIT

    echo "Waiting up to $TIMEOUT seconds for http://127.0.0.1:$PORT/health ..."
    for i in $(seq 1 "$TIMEOUT"); do
      if curl -sf "http://127.0.0.1:$PORT/health"; then
        echo
        echo "✅ Server healthy after $i seconds"
        exit 0
      fi
      if ! kill -0 $PID 2>/dev/null; then
        echo "❌ Server process died early. Last log lines:"
        tail -20 "$LOG"
        exit 1
      fi
      sleep 1
    done
    echo "❌ Timed out after $TIMEOUT seconds. Last log lines:"
    tail -20 "$LOG"
    exit 1
  '';
in
{
  # Node JS
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
  };
  
  # Python
  languages.python = {
    enable = true;
    package = pkgs.python3;
    venv = {
      enable = true;
      quiet = true;
    };
  };

  # Go
  languages.go = {
    enable = true;
    package = pkgs.go;
  };

  # 2. System Packages & Git Tooling
  packages = [
    runServer
    smokeTest

    pkgs.fastfetch
    pkgs.curl
    pkgs.git
    pkgs.git-lfs
    pkgs.gh

    # CUDA needed for some build processes.
    pkgs.cudaPackages.cuda_nvcc
    pkgs.cudaPackages.cudatoolkit
    pkgs.cudaPackages.backendStdenv

    # Pi harness (pi coding agent CLI, v1.0 in nixos-unstable)
    pkgs.pi-coding-agent
    pkgs.linuxPackages.nvidia_x11.open

    # Wayland clipboard copy and paste at the command line.
    pkgs.wl-clipboard
  ];

  # Environment Variables (Add the Wayland passthrough here)
  env = {
    TMPDIR = "/tmp";

    # Pass through Wayland & Noctalia / Niri environment contexts/
    WAYLAND_DISPLAY = "wayland-1";
    
    # Fallback for XWayland bridges inside the shell
    DISPLAY = ":0";

    # These are required to build Strata.
    # CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    # CUDA_CACHE_PATH = "$HOME/.nv/ComputeCache";
    # LD_LIBRARY_PATH = "${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib64";
    
    # Optimized compilation for the RTX 5060 Ti
    # CMAKE_ARGS = "-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120";
  };

  # Enable the native delta integration for improved Git diff views.
  delta.enable = true;

  enterShell = ''
    # Automatically localise Git LFS constraints
    git lfs install --local 2>/dev/null || true

    # Deterministic Hugging Face model cache isolation
    export HF_HOME="$PWD/.hf-cache"

    echo "⚡ Pi Configuration Workspace Loaded!"
    echo "👉 Agent harness skills are preinstalled (.pi/npm); just start 'pi'."
    echo "⚡ Llama.cpp NixOS environment loaded!"
    echo "💡 Type 'hack' to instantly start your engine via native CUDA acceleration."
    echo "🚀 Devenv active: Node.js 24, Python 3, Go, and Git tools are ready."
  '';
}
