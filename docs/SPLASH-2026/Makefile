# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CPRR Paper Build System
# org-mode → LaTeX → PDF (ACM sigconf)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PAPER     := cprr-splash
SPRINT    := cprr-sprint-plan
EMACS     := emacs --batch --no-init-file
PDFLATEX  := pdflatex -interaction=nonstopmode
BIBTEX    := bibtex

# ACM class variant: sigconf | sigplan | manuscript
ACM_CLASS := sigconf

.PHONY: all paper sprint clean distclean help

all: paper sprint  ## Build everything

# ━━━ Paper Pipeline ━━━

paper: $(PAPER).pdf  ## Build the SPLASH paper

# Direct LaTeX compilation (from hand-tuned .tex)
$(PAPER).pdf: $(PAPER).tex cprr.bib
	$(PDFLATEX) $(PAPER)
	-$(BIBTEX) $(PAPER) 2>/dev/null || true
	$(PDFLATEX) $(PAPER)
	$(PDFLATEX) $(PAPER)
	@echo "━━━ $(PAPER).pdf: $$(wc -c < $@) bytes ━━━"

# Org → TeX export (requires acmart class registration)
$(PAPER)-from-org.tex: $(PAPER).org
	$(EMACS) \
	  --eval '(require (quote ox-latex))' \
	  --eval '(add-to-list (quote org-latex-classes) \
	           (quote ("acmart" \
	                   "\\documentclass{acmart}" \
	                   ("\\section{%s}" . "\\section*{%s}") \
	                   ("\\subsection{%s}" . "\\subsection*{%s}") \
	                   ("\\subsubsection{%s}" . "\\subsubsection*{%s}"))))' \
	  --eval '(setq org-latex-default-class "acmart")' \
	  --eval '(setq org-export-with-toc nil)' \
	  --visit $(PAPER).org \
	  --funcall org-latex-export-to-latex
	mv $(PAPER).tex $(PAPER)-from-org.tex
	@echo "━━━ Exported $(PAPER)-from-org.tex ━━━"

# ━━━ Sprint Plan Exports ━━━

sprint: $(SPRINT).html $(SPRINT).md $(SPRINT).txt $(SPRINT).pdf  ## Build all sprint plan formats

$(SPRINT).html: $(SPRINT).org
	$(EMACS) \
	  --eval '(require (quote ox-html))' \
	  --visit $< \
	  --funcall org-html-export-to-html

$(SPRINT).md: $(SPRINT).org
	$(EMACS) \
	  --eval '(require (quote ox-md))' \
	  --visit $< \
	  --funcall org-md-export-to-markdown

$(SPRINT).txt: $(SPRINT).org
	$(EMACS) \
	  --eval '(require (quote ox-ascii))' \
	  --visit $< \
	  --funcall org-ascii-export-to-ascii

$(SPRINT).tex: $(SPRINT).org
	$(EMACS) \
	  --eval '(require (quote ox-latex))' \
	  --visit $< \
	  --funcall org-latex-export-to-latex

$(SPRINT).pdf: $(SPRINT).tex
	$(PDFLATEX) $(SPRINT)
	$(PDFLATEX) $(SPRINT)

# ━━━ Mermaid Diagrams ━━━

diagrams: cprr-states.png cprr-deps.png  ## Render Mermaid diagrams

%.png: %.mmd
	mmdc -i $< -o $@ -t dark -b transparent 2>/dev/null || \
	echo "⚠  mmdc not found — install @mermaid-js/mermaid-cli"

# Extract mermaid blocks from org source
cprr-states.mmd: $(PAPER).org
	@awk '/^#\+begin_src mermaid/{p=1;next}/^#\+end_src/{if(p)exit}{if(p)print}' $< > $@

cprr-deps.mmd: $(PAPER).org
	@awk 'BEGIN{n=0}/^#\+begin_src mermaid/{n++;p=(n==2);next}/^#\+end_src/{if(p)exit}{if(p)print}' $< > $@

# ━━━ Housekeeping ━━━

clean:  ## Remove build artifacts
	rm -f *.aux *.log *.out *.bbl *.blg *.fls *.fdb_latexmk
	rm -f *.toc *.nav *.snm *.vrb

distclean: clean  ## Remove all generated files
	rm -f $(PAPER).pdf $(PAPER)-from-org.tex
	rm -f $(SPRINT).html $(SPRINT).md $(SPRINT).txt $(SPRINT).tex $(SPRINT).pdf
	rm -f *.mmd *.png

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
