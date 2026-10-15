#!/bin/bash
# Minimal TeX setup for cloud sessions: TinyTeX plus the packages needed for
# quantum-physics papers and the draw-circuit skill.
# Use from an environment's setup script with:
#   curl -fsSL https://raw.githubusercontent.com/combes-group/env_files/main/setup_tex.sh | bash
set -euo pipefail

REPO_RAW=https://raw.githubusercontent.com/combes-group/env_files/main

# --- System tools: poppler (pdftoppm/pdftotext/pdfinfo) for draw-circuit,
# ghostscript for matplotlib usetex ---
if ! command -v pdftoppm >/dev/null || ! command -v gs >/dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    poppler-utils ghostscript
fi

# --- TinyTeX ---
curl -fsSL https://raw.githubusercontent.com/rstudio/tinytex/main/tools/install-bin-unix.sh | sh
TT=$(echo "$HOME"/.TinyTeX/bin/*)
TLMGR="$TT/tlmgr"

# Missing package names should not abort the setup; the checks below catch
# anything that matters.
"$TLMGR" install \
  latexmk texdoc \
  revtex textcase url quantumarticle standalone natbib doi cleveref babel-english \
  mathtools physics braket siunitx esint doublestroke bbm bbm-macros jknapltx rsfs \
  pgf circuitikz pgfplots tikz-cd quantikz qcircuit xypic \
  booktabs multirow makecell threeparttable caption float enumitem \
  microtype comment lipsum soul ulem todonotes \
  cm-super lm type1cm dvipng \
  || echo "WARNING: some TeX packages failed to install (see above)"

ln -sf "$TT"/* /usr/local/bin/

# draw-circuit greps the circuitikz manual. TinyTeX's package server has no
# documentation, so fetch the PDF from CTAN and register it with texdoc.
DOC="$(kpsewhich -var-value TEXMFDIST)/doc/latex/circuitikz"
mkdir -p "$DOC"
curl -fsSL https://mirrors.ctan.org/graphics/pgf/contrib/circuitikz/doc/circuitikzmanual.pdf \
  -o "$DOC/circuitikz.pdf" || echo "WARNING: could not download circuitikz manual"
mktexlsr >/dev/null 2>&1

# --- Smoke test: fail the setup now rather than mid-session ---
command -v latexmk pdftoppm pdftotext pdfinfo texdoc >/dev/null
texdoc -l -M circuitikz | grep -q '\.pdf' || echo "WARNING: texdoc cannot find the circuitikz manual"

# Compile a test file; if a .sty/.cls is missing, install the package that
# provides it and retry.
compile() {
  local name=$1 missing pkg
  for _ in $(seq 15); do
    rm -f "$name".{aux,log,fdb_latexmk,fls,pdf}
    latexmk -pdf -interaction=nonstopmode -halt-on-error "$name.tex" >/dev/null 2>&1 && return 0
    missing=$(grep -o "File \`[^']*' not found" "$name.log" | head -1 | sed "s/File \`\(.*\)' not found/\1/")
    [ -n "$missing" ] || return 1
    pkg=$(tlmgr search --global --file "/$missing" | grep -E '^[A-Za-z0-9._-]+:$' | head -1 | tr -d :)
    [ -n "$pkg" ] || return 1
    echo "Installing missing TeX package $pkg (provides $missing)"
    tlmgr install "$pkg" >/dev/null || return 1
  done
  return 1
}

T=$(mktemp -d)
cat > "$T/paper.tex" <<'EOF'
\documentclass[aps,pra,twocolumn]{revtex4-2}
\usepackage{amsmath,physics,siunitx,hyperref,cleveref}
\usepackage{circuitikz}
\usepackage{quantikz}
\begin{document}
\section{Test}\label{sec:t}
$\ket{\psi} = \alpha\ket{0} + \beta\ket{1}$, $\omega = 2\pi\times\SI{5}{\giga\hertz}$, see \cref{sec:t}.
\begin{circuitikz}\draw (0,0) to[C] (2,0);\end{circuitikz}
\begin{quantikz}\lstick{$\ket{0}$} & \gate{H} & \ctrl{1} & \\ \lstick{$\ket{0}$} & & \targ{} & \end{quantikz}
\end{document}
EOF
# Same preamble as the draw-circuit skill's template
cat > "$T/figure.tex" <<'EOF'
\documentclass[border=8pt, xcolor={usenames,dvipsnames}]{standalone}
\usepackage{tikz}
\usepackage{circuitikz}
\usetikzlibrary{arrows.meta,calc}
\begin{document}
\begin{circuitikz}[line width = 0.8pt]
  \draw (0,2) to[C, l=$C$, *-*] (0,0) node[ground]{};
  \draw (0,2) -- (2,2) to[L, l=$L$] (2,0) -- (0,0);
\end{circuitikz}
\end{document}
EOF
cd "$T"
for name in paper figure; do
  compile "$name" || { echo "ERROR: TeX smoke test failed on $name.tex"; tail -30 "$name.log"; exit 1; }
  pdftoppm -png -r 50 "$name.pdf" "$name" >/dev/null
done
echo "TeX setup OK"
cd /
rm -rf "$T"

# --- draw-circuit skill, if it has been committed to this repo ---
SK="$HOME/.claude/skills/draw-circuit"
mkdir -p "$SK"
for f in SKILL.md driver.py template.tex; do
  curl -fsSL "$REPO_RAW/skills/draw-circuit/$f" -o "$SK/$f" \
    || { echo "NOTE: draw-circuit skill not in env_files repo; skipping"; rm -rf "$SK"; break; }
done
