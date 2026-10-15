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
  revtex quantumarticle standalone natbib doi cleveref babel-english \
  mathtools physics braket siunitx esint doublestroke bbm bbm-macros jknapltx rsfs \
  pgf circuitikz pgfplots tikz-cd quantikz qcircuit xypic \
  booktabs multirow makecell threeparttable caption float enumitem \
  microtype comment lipsum soul ulem todonotes \
  cm-super lm type1cm dvipng \
  || echo "WARNING: some TeX packages failed to install (see above)"

# draw-circuit greps the circuitikz manual, which TinyTeX omits by default
"$TLMGR" install --reinstall --with-doc circuitikz

ln -sf "$TT"/* /usr/local/bin/

# --- Smoke test: fail the setup now rather than mid-session ---
for f in revtex4-2.cls quantumarticle.cls standalone.cls physics.sty braket.sty \
         siunitx.sty cleveref.sty circuitikz.sty tikzlibraryquantikz2.code.tex; do
  kpsewhich "$f" >/dev/null || echo "WARNING: $f not found"
done
command -v latexmk pdftoppm pdftotext pdfinfo texdoc >/dev/null
texdoc -l -M circuitikz | grep -q '\.pdf' || echo "WARNING: circuitikz manual not found"

T=$(mktemp -d)
cat > "$T/test.tex" <<'EOF'
\documentclass[aps,pra,twocolumn]{revtex4-2}
\usepackage{amsmath,physics,siunitx,circuitikz}
\begin{document}
$\ket{\psi} = \alpha\ket{0} + \beta\ket{1}$, $\omega = 2\pi\times\SI{5}{\giga\hertz}$
\begin{circuitikz}\draw (0,0) to[C] (2,0);\end{circuitikz}
\end{document}
EOF
(cd "$T" && latexmk -pdf -interaction=nonstopmode -halt-on-error test.tex >/dev/null) \
  || { echo "ERROR: TeX smoke test failed"; tail -30 "$T/test.log"; exit 1; }
pdftoppm -png -r 50 "$T/test.pdf" "$T/test" && echo "TeX setup OK"
rm -rf "$T"
