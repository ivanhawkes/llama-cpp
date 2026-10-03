{
  description = "Llama.cpp development environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
      };

      # llama.cpp with CUDA support explicitly enabled via override
      # (redundant with the pkgs config above, but keeps run-server self-documenting)
      llamaCppPackage = pkgs.llama-cpp.override { cudaSupport = true; };

      runServer = pkgs.writeShellScriptBin "run-server" ''
        echo "🤖 Launching local GPU inference engine (Coding Optimization)..."

        # Preflight: verify physical GPU index 0 is actually the RTX 5060 Ti before
        # pinning it. The model (~15GB) does not fit on the RTX 4060 (8GB), and a
        # stale positional pin would otherwise fail obscurely at model-load time.
        if command -v nvidia-smi > /dev/null 2>&1; then
          GPU0=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader -i 0 | head -1)
          case "$GPU0" in
            *"5060 Ti"*) ;;
            *) echo "❌ CUDA index 0 is '$GPU0', expected RTX 5060 Ti (16GB)." >&2
               echo "   Check mapping: nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader" >&2
               exit 1 ;;
          esac
        fi

        # NOTE: The model we are running 'ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S' is an MTP model
        # and the version of llama.cpp we are using can split MTP across multiple GPU devices.

        # NixOS system driver first; nvidia_x11.open (in buildInputs) is the
        # fallback for non-NixOS use where /run/opengl-driver does not exist.
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
        
        # Log the whole session to $LOG (fresh per start) while echoing to the
        # terminal, so output stays viewable and can be monitored after the fact.
        LOG=/tmp/llama-server.log
        [ -n "$LLAMA_SERVER_LOG" ] && LOG=$LLAMA_SERVER_LOG
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] run-server: session log -> $LOG"

        ${llamaCppPackage}/bin/llama-server \
          --host 0.0.0.0 -hf ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S \
          -ngl 99 \
          -ctk q4_0 \
          -ctv q4_0 \
          -c 48000 \
          --parallel 1 \
          --image-min-tokens 1024 \
          --flash-attn on \
          --agent \
          --spec-type draft-mtp \
          --spec-draft-n-max 2 \
          --temperature 0.1 \
          --top-p 0.95 \
          --min-p 0.05 \
          --repeat-penalty 1.05 \
          --metrics \
          --chat-template-kwargs '{"reasoning_effort":"xhigh"}' "$@" 2>&1 | tee "$LOG"
      '';

      # Smoke test: start run-server, poll /health until healthy (or timeout),
      # then kill the server. Fails fast with the last log lines on early death.
      # NOTE: bash ${var} brace-expansion is not usable inside Nix '' strings
      # (it triggers Nix interpolation), so the script avoids braces entirely.
      smokeTest = pkgs.writeShellScriptBin "smoke-test" ''
        PORT=$SMOKE_TEST_PORT
        [ -z "$PORT" ] && PORT=8080
        TIMEOUT=$SMOKE_TEST_TIMEOUT
        [ -z "$TIMEOUT" ] && TIMEOUT=300
        LOG=/tmp/llama-smoke-test.log

        run-server > "$LOG" 2>&1 &
        PID=$!
        trap 'kill $PID 2>/dev/null' EXIT

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

    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          git-lfs
          nodejs_latest
          pi-coding-agent
          go
          python3
          fastfetch
          curl
          runServer
          smokeTest
          # Open NVIDIA driver libs (libcuda & co) so the shell also works
          # outside NixOS, where /run/opengl-driver does not exist. On NixOS
          # the system driver still takes precedence: run-server lists the
          # /run/opengl-driver paths first in LD_LIBRARY_PATH.
          linuxPackages.nvidia_x11.open
        ];
        
        env = {
          TMPDIR = "/tmp";
          # Deterministic Hugging Face model cache for this workspace
          # (run-server inherits it; ~15GB model lands here on first start).
          HF_HOME = "$PWD/.hf-cache";
        };

        shellHook = ''
          # Isolate npm paths to prevent NixOS global write permission issues
          export NPM_CONFIG_PREFIX="$PWD/.pi/npm"
          export PATH="$PWD/.pi/npm/bin:$PATH"
          
          echo "⚡ Pi Configuration Workspace Loaded!"
          echo "👉 Agent harness skills are preinstalled (.pi/npm); just start 'pi'."
          echo "⚡ Llama.cpp NixOS environment loaded!"
          echo "💡 Type 'run-server' to instantly start your engine via native CUDA acceleration."
        '';
      };
    };
}