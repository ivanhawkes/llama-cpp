{ pkgs, lib, config, inputs, ... }:

let
  # 🚀 FIX: Forcibly re-import Nixpkgs with CUDA and unfree support enabled globally 
  # This ensures both llama-cpp and nvidia_x11 see the active hardware state.
  cudaPkgs = import inputs.nixpkgs {
    inherit (pkgs) system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
    };
  };

  # Explicitly override llama-cpp using our hardware-accelerated package tree
  llamaCppPackage = cudaPkgs.llama-cpp.override { cudaSupport = true; };

  # Native local GPU inference wrapper
  runServer = cudaPkgs.writeShellScriptBin "run-server" ''
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
    { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] run-server: session log -> $LOG"; \
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

  # Headless browser MCP server for the pi harness (see .pi/mcp.json).
  # Pinned by Nix so the harness's web tooling is reproducible. The wrapper
  # bridges the store paths because mcp.json does not expand ${VAR} in args.
  playwrightMcp = cudaPkgs.writeShellScriptBin "playwright-mcp" ''
    exec ${cudaPkgs.playwright-mcp}/bin/playwright-mcp \
      --headless \
      --executable-path ${cudaPkgs.chromium}/bin/chromium "$@"
  '';

  # Pre-flight smoke validation runner
  smokeTest = cudaPkgs.writeShellScriptBin "smoke-test" ''
    PORT=$SMOKE_TEST_PORT
    [ -z "$PORT" ] && PORT=8080
    TIMEOUT=$SMOKE_TEST_TIMEOUT
    [ -z "$TIMEOUT" ] && TIMEOUT=300
    LOG=/tmp/llama-smoke-test.log

    run-server --port "$PORT" > "$LOG" 2>&1 &
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
  # 1. Automated Runtimes & Languages (Pulled from our custom CUDA package set)
  languages.javascript = {
    enable = true;
    package = cudaPkgs.nodejs_24;
  };
  languages.python = {
    enable = true;
    package = cudaPkgs.python3;
  };
  languages.go = {
    enable = true;
    package = cudaPkgs.go;
  };

  # 2. System Packages & Git Tooling
  packages = [
    cudaPkgs.fastfetch
    cudaPkgs.curl
    cudaPkgs.git
    cudaPkgs.git-lfs
    cudaPkgs.gh
    runServer
    smokeTest
    playwrightMcp
    # Pi harness (pi coding agent CLI, v1.0 in nixos-unstable)
    cudaPkgs.pi-coding-agent
    cudaPkgs.linuxPackages.nvidia_x11.open
  ];

  # 3. Environment Variables
  env.TMPDIR = "/tmp";

  # 4. Interactive Shell Initialisation & Hooks
  enterShell = ''
    # Automatically localise Git LFS constraints
    git lfs install --local 2>/dev/null || true

    # Deterministic Hugging Face model cache isolation
    export HF_HOME="$PWD/.hf-cache"

    echo "⚡ Pi Configuration Workspace Loaded!"
    echo "👉 Agent harness skills are preinstalled (.pi/npm); just start 'pi'."
    echo "⚡ Llama.cpp NixOS environment loaded!"
    echo "💡 Type 'run-server' to instantly start your engine via native CUDA acceleration."
    echo "🚀 Devenv active: Node.js 24, Python 3, Go, and Git tools are ready."
  '';
}
