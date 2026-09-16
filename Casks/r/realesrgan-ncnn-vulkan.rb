cask "realesrgan-ncnn-vulkan" do
  version "0.2.5.0,20220424"
  sha256 "e5aa6eb131234b87c0c51f82b89390f5e3e642b7b70f2b9bbe95b6a285a40c96"

  url "https://github.com/xinntao/Real-ESRGAN/releases/download/v#{version.csv.first}/realesrgan-ncnn-vulkan-#{version.csv.second}-ubuntu.zip"
  name "Real-ESRGAN ncnn Vulkan"
  desc "Image upscaler running Real-ESRGAN models on any Vulkan GPU"
  homepage "https://github.com/xinntao/Real-ESRGAN"

  # Upstream tags newer releases (v0.3.0 and later) without a prebuilt
  # ncnn binary, so only releases that ship the ubuntu zip count. The
  # build date in the asset name is the second half of the version.
  livecheck do
    url :url
    regex(/^realesrgan-ncnn-vulkan-(\d+)-ubuntu\.zip$/i)
    strategy :github_releases do |json, regex|
      json.flat_map do |release|
        next if release["draft"] || release["prerelease"]

        tag = release["tag_name"]&.[](/^v?(\d+(?:\.\d+)+)$/i, 1)
        next if tag.blank?

        release["assets"]&.filter_map do |asset|
          date = asset["name"]&.[](regex, 1)
          "#{tag},#{date}" if date
        end
      end.compact
    end
  end

  depends_on arch: :x86_64

  # The binary resolves the models directory next to its own real path,
  # so a symlink from the brew prefix is enough.
  binary "realesrgan-ncnn-vulkan"
  binary "upscale"

  # upscale wraps the raw CLI with defaults tuned for screenshots and an
  # output name derived from the input, so one word does the common case.
  preflight_steps do
    write_file "upscale", <<~SCRIPT
      #!/bin/sh
      # upscale: Real-ESRGAN front end with screenshot-friendly defaults.
      set -eu

      BIN="{{staged_path}}/realesrgan-ncnn-vulkan"
      SCALE=4
      MODEL=realesrgan-x4plus-anime
      OUTDIR=""

      usage() {
        cat <<USAGE
      usage: upscale [-s SCALE] [-m MODEL] [-o DIR] IMAGE...

      Writes IMAGE-<SCALE>x.png next to each input (or into DIR with -o).
      Directories are expanded to the png/jpg/jpeg/webp files inside them.

        -s SCALE  2, 3 or 4 (default: $SCALE)
        -m MODEL  default: $MODEL
        -o DIR    output directory
        -h        this help

      models:
        realesrgan-x4plus         photos, mixed content
        realesrgan-x4plus-anime   flat UI, text, screenshots (default)
        realesr-animevideov3-x2   fast, 2x only
        realesr-animevideov3-x3   fast, 3x only
        realesr-animevideov3-x4   fast, 4x only
      USAGE
      }

      while getopts "s:m:o:h" opt; do
        case "$opt" in
          s) SCALE=$OPTARG ;;
          m) MODEL=$OPTARG ;;
          o) OUTDIR=$OPTARG ;;
          h) usage; exit 0 ;;
          *) usage >&2; exit 2 ;;
        esac
      done
      shift $((OPTIND - 1))
      [ $# -gt 0 ] || { usage >&2; exit 2; }

      case "$SCALE" in
        2|3|4) ;;
        *) echo "upscale: scale must be 2, 3 or 4" >&2; exit 2 ;;
      esac

      [ -z "$OUTDIR" ] || mkdir -p "$OUTDIR"

      one() {
        in=$1
        base=$(basename "$in")
        stem=${base%.*}
        dir=${OUTDIR:-$(dirname "$in")}
        out="$dir/$stem-${SCALE}x.png"
        "$BIN" -i "$in" -o "$out" -n "$MODEL" -s "$SCALE" >/dev/null 2>&1 || {
          echo "upscale: failed on $in" >&2
          return 1
        }
        echo "$out"
      }

      status=0
      for arg in "$@"; do
        if [ -d "$arg" ]; then
          for f in "$arg"/*.png "$arg"/*.jpg "$arg"/*.jpeg "$arg"/*.webp; do
            [ -f "$f" ] && { one "$f" || status=1; }
          done
        elif [ -f "$arg" ]; then
          one "$arg" || status=1
        else
          echo "upscale: no such file: $arg" >&2
          status=1
        fi
      done
      exit $status
    SCRIPT
    set_permissions "upscale", "0755"
  end

  caveats <<~EOS
    Needs a working Vulkan driver (libvulkan.so.1 plus your GPU's ICD)
    installed by the host distro. Check with: vulkaninfo --summary

    Upscale a screenshot 4x (writes shot-4x.png next to it):
      upscale shot.png
    Run `upscale -h` for scale, model and output options, or call
    realesrgan-ncnn-vulkan directly for the full CLI.
  EOS
end
