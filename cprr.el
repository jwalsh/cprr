;;; cprr.el --- Conjecture → Proof → Refutation → Refinement  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 JW
;; Author: JW
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (transient "0.4.0"))
;; Keywords: tools, project, org
;; URL: https://github.com/jwalsh/cprr

;; This file is not part of GNU Emacs.

;;; Commentary:

;; CPRR (Conjecture → Proof → Refutation → Refinement) is a
;; Lakatos-informed methodology for experiment-driven development.
;;
;; This package provides Emacs tooling for:
;; - Creating and navigating experiments (experiments/NNN-name/)
;; - Managing CPRR phase documents (CONJECTURE.md, PROOF.md, etc.)
;; - Integrating with bd (beads) for bead tracking
;; - Rendering Mermaid diagrams from org-mode
;; - Officer role dispatching (Professor, Constable, Refinery, Deacon)
;;
;; Usage:
;;   M-x cprr-dispatch    — main transient menu
;;   C-c C-p              — cprr-dispatch (when cprr-mode active)
;;
;; Configuration:
;;   (require 'cprr)
;;   (setq cprr-project-root "~/ghq/github.com/jwalsh/cprr")

;;; Code:

(require 'transient)
(require 'org)
(require 'project)

;; ── Customization ──────────────────────────────────────────────

(defgroup cprr nil
  "CPRR: Conjecture → Proof → Refutation → Refinement."
  :group 'tools
  :prefix "cprr-")

(defcustom cprr-project-root nil
  "Root directory of the CPRR project.
When nil, uses `project-root' or searches upward for AGENTS.md."
  :type '(choice (const nil) directory)
  :group 'cprr)

(defcustom cprr-experiments-dir "experiments"
  "Directory name for experiments relative to project root."
  :type 'string
  :group 'cprr)

(defcustom cprr-bd-executable "bd"
  "Path to the bd (beads) executable."
  :type 'string
  :group 'cprr)

(defcustom cprr-mmdc-executable "mmdc"
  "Path to mermaid-cli (mmdc) for rendering diagrams."
  :type 'string
  :group 'cprr)

(defcustom cprr-stale-threshold-hours 24
  "Hours after which a bead is considered stale."
  :type 'integer
  :group 'cprr)

(defcustom cprr-phase-documents
  '((conjecture  . "CONJECTURE.md")
    (proof       . "PROOF.md")
    (refutation  . "REFUTATION.md")
    (refinement  . "REFINEMENT.md"))
  "Alist mapping CPRR phases to their document filenames."
  :type '(alist :key-type symbol :value-type string)
  :group 'cprr)

(defcustom cprr-bead-statuses
  '((conjecture  . "conjecture-stated")
    (proof       . "proof-demonstrated")
    (survived    . "refutation-survived")
    (refuted     . "refuted")
    (refined     . "refined"))
  "Alist mapping CPRR phases to bd bead statuses."
  :type '(alist :key-type symbol :value-type string)
  :group 'cprr)

(defcustom cprr-hardening-levels
  '(("L0" . "Vibe code")
    ("L1" . "Example-tested")
    ("L2" . "Property-tested")
    ("L3" . "Contract-guarded")
    ("L4" . "Formally verified"))
  "Alist of hardening levels and descriptions."
  :type '(alist :key-type string :value-type string)
  :group 'cprr)

;; ── Faces ──────────────────────────────────────────────────────

(defface cprr-phase-conjecture
  '((t :foreground "#4a7c4a" :weight bold))
  "Face for conjecture phase indicators."
  :group 'cprr)

(defface cprr-phase-proof
  '((t :foreground "#4a6a9e" :weight bold))
  "Face for proof phase indicators."
  :group 'cprr)

(defface cprr-phase-refutation
  '((t :foreground "#9e4a4a" :weight bold))
  "Face for refutation phase indicators."
  :group 'cprr)

(defface cprr-phase-refinement
  '((t :foreground "#7a4a9e" :weight bold))
  "Face for refinement phase indicators."
  :group 'cprr)

(defface cprr-survived
  '((t :foreground "#22c55e" :weight bold))
  "Face for survived experiments."
  :group 'cprr)

(defface cprr-refuted
  '((t :foreground "#ef4444" :weight bold))
  "Face for refuted experiments."
  :group 'cprr)

;; ── Project Root Discovery ─────────────────────────────────────

(defun cprr--find-root ()
  "Find the CPRR project root.
Checks `cprr-project-root', then `project-root', then searches
upward for AGENTS.md."
  (or cprr-project-root
      (when-let ((proj (project-current)))
        (let ((root (project-root proj)))
          (when (file-exists-p (expand-file-name "AGENTS.md" root))
            root)))
      (locate-dominating-file default-directory "AGENTS.md")
      (locate-dominating-file default-directory "experiments")
      (user-error "Not in a CPRR project (no AGENTS.md found)")))

(defun cprr--experiments-path ()
  "Return absolute path to the experiments directory."
  (expand-file-name cprr-experiments-dir (cprr--find-root)))

(defun cprr--ensure-experiments-dir ()
  "Ensure the experiments directory exists."
  (let ((dir (cprr--experiments-path)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    dir))

;; ── Experiment Numbering ───────────────────────────────────────

(defun cprr--list-experiments ()
  "Return sorted list of experiment directory names."
  (let ((dir (cprr--experiments-path)))
    (when (file-directory-p dir)
      (sort
       (seq-filter
        (lambda (f)
          (and (file-directory-p (expand-file-name f dir))
               (string-match-p "\\`[0-9]\\{3\\}-" f)))
        (directory-files dir nil "\\`[0-9]\\{3\\}-"))
       #'string<))))

(defun cprr--next-experiment-number ()
  "Return the next experiment number as a zero-padded string."
  (let ((experiments (cprr--list-experiments)))
    (if experiments
        (format "%03d"
                (1+ (string-to-number
                     (substring (car (last experiments)) 0 3))))
      "000")))

(defun cprr--experiment-path (name)
  "Return absolute path for experiment NAME."
  (expand-file-name name (cprr--experiments-path)))

(defun cprr--current-experiment ()
  "Detect the current experiment from buffer file path.
Returns the experiment directory name (e.g., \"003-cache-layer\") or nil."
  (when-let ((file (or buffer-file-name default-directory)))
    (let ((exp-dir (cprr--experiments-path)))
      (when (string-prefix-p (expand-file-name exp-dir) (expand-file-name file))
        (let ((relative (file-relative-name file exp-dir)))
          (car (split-string relative "/")))))))

;; ── Phase Detection ────────────────────────────────────────────

(defun cprr--experiment-phase (experiment)
  "Determine the current phase of EXPERIMENT by checking which docs exist."
  (let ((path (cprr--experiment-path experiment)))
    (cond
     ((file-exists-p (expand-file-name "REFINEMENT.md" path)) 'refinement)
     ((file-exists-p (expand-file-name "REFUTATION.md" path)) 'refutation)
     ((file-exists-p (expand-file-name "PROOF.md" path))      'proof)
     ((file-exists-p (expand-file-name "CONJECTURE.md" path)) 'conjecture)
     (t 'opening))))

(defun cprr--phase-face (phase)
  "Return the face for PHASE."
  (pcase phase
    ('conjecture 'cprr-phase-conjecture)
    ('proof      'cprr-phase-proof)
    ('refutation 'cprr-phase-refutation)
    ('refinement 'cprr-phase-refinement)
    (_           'default)))

;; ── Bead Integration ───────────────────────────────────────────

(defun cprr--bd-available-p ()
  "Check if bd executable is available."
  (executable-find cprr-bd-executable))

(defun cprr--bd-run (&rest args)
  "Run bd with ARGS and return output as string."
  (if (cprr--bd-available-p)
      (with-temp-buffer
        (let ((default-directory (cprr--find-root)))
          (apply #'call-process cprr-bd-executable nil t nil args)
          (string-trim (buffer-string))))
    (message "bd not found; bead operations unavailable")
    nil))

(defun cprr--bd-run-async (callback &rest args)
  "Run bd with ARGS asynchronously, calling CALLBACK with output."
  (if (cprr--bd-available-p)
      (let ((buf (generate-new-buffer " *cprr-bd*"))
            (default-directory (cprr--find-root)))
        (set-process-sentinel
         (apply #'start-process "cprr-bd" buf cprr-bd-executable args)
         (lambda (proc _event)
           (when (eq (process-status proc) 'exit)
             (with-current-buffer (process-buffer proc)
               (funcall callback (string-trim (buffer-string))))
             (kill-buffer (process-buffer proc))))))
    (message "bd not found; bead operations unavailable")))

(defun cprr-bd-create (experiment &optional template)
  "Create a bead for EXPERIMENT with optional TEMPLATE."
  (interactive
   (list (completing-read "Experiment: " (cprr--list-experiments))
         (completing-read "Template: "
                          '("conjecture" "proof" "refutation" "refinement")
                          nil t "conjecture")))
  (let ((result (cprr--bd-run "create" "--template" template experiment)))
    (when result
      (message "Bead created: %s" result)
      result)))

(defun cprr-bd-status (bead-id status)
  "Set STATUS on BEAD-ID."
  (interactive
   (list (read-string "Bead ID: ")
         (completing-read "Status: "
                          (mapcar #'cdr cprr-bead-statuses)
                          nil t)))
  (let ((result (cprr--bd-run "status" bead-id status)))
    (when result (message "%s" result))))

(defun cprr-bd-close (bead-id reason)
  "Close BEAD-ID with REASON."
  (interactive
   (list (read-string "Bead ID: ")
         (read-string "Reason: ")))
  (let ((result (cprr--bd-run "close" bead-id "--reason" reason)))
    (when result (message "%s" result))))

(defun cprr-bd-list (&optional status)
  "List beads, optionally filtered by STATUS."
  (interactive
   (list (completing-read "Filter status (empty for all): "
                          (cons "" (mapcar #'cdr cprr-bead-statuses))
                          nil nil "")))
  (let* ((args (if (and status (not (string-empty-p status)))
                   (list "ls" "--status" status)
                 (list "ls")))
         (result (apply #'cprr--bd-run args)))
    (if result
        (with-current-buffer (get-buffer-create "*cprr-beads*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (propertize "CPRR Beads\n\n" 'face 'bold))
            (when (and status (not (string-empty-p status)))
              (insert (format "Filter: %s\n\n" status)))
            (insert result)
            (goto-char (point-min))
            (special-mode))
          (display-buffer (current-buffer)))
      (message "No beads found"))))

(defun cprr-bd-list-refuted ()
  "List all refuted experiments (institutional memory)."
  (interactive)
  (cprr-bd-list "refuted"))

;; ── Experiment Creation ────────────────────────────────────────

(defun cprr--slugify (name)
  "Convert NAME to a kebab-case slug."
  (thread-last name
    (downcase)
    (replace-regexp-in-string "[^a-z0-9]+" "-")
    (replace-regexp-in-string "\\`-+" "")
    (replace-regexp-in-string "-+\\'" "")))

(defun cprr--conjecture-template (title)
  "Return CONJECTURE.md template for TITLE."
  (format "# Conjecture: %s

## Hypothesis
[One sentence: \"We believe that X because Y.\"]

## Motivation
[Why does this matter? What problem does it solve?]

## Falsification Criteria
[How would we know this is WRONG? Be specific.]
- If [condition], the conjecture is refuted.
- If [metric] exceeds [threshold], the conjecture is refuted.

## Prior Art
[What experiments or external work informed this?]

## Scope
- **IN**: [what is in scope]
- **OUT**: [what is explicitly out of scope]

## Target Hardening Level
L2 (Property-tested)
" title))

(defun cprr--makefile-template ()
  "Return Makefile template for an experiment."
  ".PHONY: test bench clean

test:
\t@echo \"=== Running tests ===\"
\t@python3 -m pytest tests/ -v || echo \"No tests yet\"

bench:
\t@echo \"=== Running benchmarks ===\"
\t@echo \"No benchmarks configured\"

clean:
\t@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
\t@find . -name '*.pyc' -delete 2>/dev/null || true
")

(defun cprr-new-experiment (title)
  "Create a new experiment with TITLE.
Scaffolds the directory, writes CONJECTURE.md template,
creates a Makefile, and optionally creates a bead."
  (interactive "sExperiment title: ")
  (let* ((num (cprr--next-experiment-number))
         (slug (cprr--slugify title))
         (dirname (format "%s-%s" num slug))
         (exp-path (cprr--experiment-path dirname)))
    ;; Create directories
    (make-directory (expand-file-name "src" exp-path) t)
    (make-directory (expand-file-name "tests" exp-path) t)
    ;; Write CONJECTURE.md
    (let ((conj-file (expand-file-name "CONJECTURE.md" exp-path)))
      (with-temp-file conj-file
        (insert (cprr--conjecture-template title))))
    ;; Write Makefile
    (let ((makefile (expand-file-name "Makefile" exp-path)))
      (with-temp-file makefile
        (insert (cprr--makefile-template))))
    ;; Create bead if bd is available
    (when (cprr--bd-available-p)
      (cprr--bd-run "create" "--template" "conjecture" dirname))
    ;; Open the conjecture file
    (find-file (expand-file-name "CONJECTURE.md" exp-path))
    (message "Created experiment: %s" dirname)
    dirname))

(defun cprr-new-child-experiment (parent title)
  "Create a child experiment of PARENT with TITLE.
Links the child bead to the parent via bd."
  (interactive
   (list (completing-read "Parent experiment: " (cprr--list-experiments) nil t)
         (read-string "Child experiment title: ")))
  (let ((child (cprr-new-experiment title)))
    (when (cprr--bd-available-p)
      (cprr--bd-run "link" parent "--children" child))
    (message "Created child %s of parent %s" child parent)))

;; ── Phase Document Navigation ──────────────────────────────────

(defun cprr--open-phase-doc (experiment phase)
  "Open the PHASE document for EXPERIMENT, creating from template if needed."
  (let* ((filename (alist-get phase cprr-phase-documents))
         (filepath (expand-file-name filename (cprr--experiment-path experiment))))
    (find-file filepath)))

(defun cprr-goto-conjecture ()
  "Open CONJECTURE.md for the current experiment."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (cprr--open-phase-doc exp 'conjecture)
    (user-error "Not in an experiment directory")))

(defun cprr-goto-proof ()
  "Open PROOF.md for the current experiment."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (cprr--open-phase-doc exp 'proof)
    (user-error "Not in an experiment directory")))

(defun cprr-goto-refutation ()
  "Open REFUTATION.md for the current experiment."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (cprr--open-phase-doc exp 'refutation)
    (user-error "Not in an experiment directory")))

(defun cprr-goto-refinement ()
  "Open REFINEMENT.md for the current experiment."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (cprr--open-phase-doc exp 'refinement)
    (user-error "Not in an experiment directory")))

(defun cprr-goto-makefile ()
  "Open Makefile for the current experiment."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (find-file (expand-file-name "Makefile" (cprr--experiment-path exp)))
    (user-error "Not in an experiment directory")))

(defun cprr-goto-experiment (experiment)
  "Navigate to EXPERIMENT's directory in dired."
  (interactive
   (list (completing-read "Experiment: " (cprr--list-experiments) nil t)))
  (dired (cprr--experiment-path experiment)))

(defun cprr-cycle-phase ()
  "Cycle to the next phase document for the current experiment.
Follows: CONJECTURE → PROOF → REFUTATION → REFINEMENT → CONJECTURE."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (let* ((current-phase (cprr--experiment-phase exp))
             (next-phase (pcase current-phase
                           ('conjecture 'proof)
                           ('proof      'refutation)
                           ('refutation 'refinement)
                           ('refinement 'conjecture)
                           (_           'conjecture))))
        (cprr--open-phase-doc exp next-phase))
    (user-error "Not in an experiment directory")))

;; ── Experiment Status Overview ─────────────────────────────────

(defun cprr--experiment-status-line (experiment)
  "Return a formatted status line for EXPERIMENT."
  (let* ((phase (cprr--experiment-phase experiment))
         (face (cprr--phase-face phase))
         (refuted-p (file-exists-p
                     (expand-file-name
                      "REFUTATION.md"
                      (cprr--experiment-path experiment))))
         ;; Check verdict in REFUTATION.md if it exists
         (verdict (when refuted-p
                    (with-temp-buffer
                      (insert-file-contents
                       (expand-file-name
                        "REFUTATION.md"
                        (cprr--experiment-path experiment)))
                      (cond
                       ((search-forward "SURVIVED" nil t) "✅ SURVIVED")
                       ((search-forward "REFUTED" nil t)  "❌ REFUTED")
                       ((search-forward "PARTIAL" nil t)  "⚠️  PARTIAL")
                       (t nil))))))
    (format "  %-30s  %-15s  %s"
            experiment
            (propertize (symbol-name phase) 'face face)
            (or verdict ""))))

(defun cprr-dashboard ()
  "Display the CPRR experiment dashboard."
  (interactive)
  (let ((experiments (cprr--list-experiments))
        (buf (get-buffer-create "*cprr-dashboard*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "CPRR Dashboard" 'face '(:height 1.3 :weight bold)))
        (insert "\n")
        (insert (propertize (format "Project: %s" (cprr--find-root))
                            'face 'font-lock-comment-face))
        (insert "\n\n")
        ;; Experiments table
        (insert (propertize
                 (format "  %-30s  %-15s  %s\n" "Experiment" "Phase" "Verdict")
                 'face 'bold))
        (insert "  " (make-string 65 ?─) "\n")
        (if experiments
            (dolist (exp experiments)
              (insert (cprr--experiment-status-line exp) "\n"))
          (insert "  (no experiments yet)\n"))
        ;; Summary
        (insert "\n")
        (let ((counts (make-hash-table :test 'eq)))
          (dolist (exp experiments)
            (let ((phase (cprr--experiment-phase exp)))
              (puthash phase (1+ (gethash phase counts 0)) counts)))
          (insert (propertize "Summary:" 'face 'bold) "\n")
          (maphash (lambda (phase count)
                     (insert (format "  %s: %d\n"
                                     (propertize (symbol-name phase)
                                                 'face (cprr--phase-face phase))
                                     count)))
                   counts))
        ;; Keybindings help
        (insert "\n")
        (insert (propertize "Actions:" 'face 'bold) "\n")
        (insert "  n  new experiment    g  refresh    q  quit\n")
        (insert "  RET  visit experiment\n")
        (goto-char (point-min))
        ;; Simple keymap
        (local-set-key (kbd "n") #'cprr-new-experiment)
        (local-set-key (kbd "g") #'cprr-dashboard)
        (local-set-key (kbd "q") #'quit-window)
        (local-set-key (kbd "RET")
                       (lambda ()
                         (interactive)
                         (let ((line (thing-at-point 'line t)))
                           (when (string-match "\\([0-9]\\{3\\}-[^ ]+\\)" line)
                             (cprr-goto-experiment (match-string 1 line))))))
        (special-mode)))
    (display-buffer buf)))

;; ── Mermaid Rendering ──────────────────────────────────────────

(defun cprr--mmdc-available-p ()
  "Check if mmdc (mermaid-cli) is available."
  (executable-find cprr-mmdc-executable))

(defun cprr-render-mermaid-block ()
  "Render the mermaid source block at point to PNG.
Uses the :file header argument if present, otherwise generates
a filename from the block name or position."
  (interactive)
  (unless (cprr--mmdc-available-p)
    (user-error "mmdc not found; install @mermaid-js/mermaid-cli"))
  (save-excursion
    (let* ((element (org-element-at-point))
           (lang (org-element-property :language element)))
      (unless (equal lang "mermaid")
        (user-error "Not in a mermaid source block"))
      (let* ((body (org-element-property :value element))
             (params (org-babel-parse-header-arguments
                      (org-element-property :parameters element)))
             (out-file (or (cdr (assq :file params))
                           (format "img/mermaid-%s.png"
                                   (format-time-string "%Y%m%d-%H%M%S"))))
             (out-path (expand-file-name out-file (cprr--find-root)))
             (tmp-file (make-temp-file "cprr-mermaid-" nil ".mmd")))
        ;; Ensure output directory exists
        (make-directory (file-name-directory out-path) t)
        ;; Write mermaid source to temp file
        (with-temp-file tmp-file
          (insert body))
        ;; Render
        (let ((exit-code
               (call-process cprr-mmdc-executable nil "*cprr-mermaid*" nil
                             "-i" tmp-file
                             "-o" out-path
                             "-b" "transparent")))
          (delete-file tmp-file)
          (if (zerop exit-code)
              (progn
                (message "Rendered: %s" out-path)
                ;; Display inline if in org-mode
                (when (derived-mode-p 'org-mode)
                  (org-redisplay-inline-images)))
            (pop-to-buffer "*cprr-mermaid*")
            (user-error "Mermaid rendering failed")))))))

(defun cprr-render-all-mermaid ()
  "Render all mermaid blocks in the current org buffer."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in an org-mode buffer"))
  (let ((count 0))
    (org-babel-map-src-blocks nil
      (when (equal lang "mermaid")
        (goto-char beg-block)
        (condition-case err
            (progn
              (cprr-render-mermaid-block)
              (cl-incf count))
          (error (message "Failed to render block: %s" (error-message-string err))))))
    (message "Rendered %d mermaid block(s)" count)))

;; ── Experiment Shell Commands ──────────────────────────────────

(defun cprr-make-test ()
  "Run `make test' in the current experiment directory."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (let ((default-directory (cprr--experiment-path exp)))
        (compile "make test"))
    (user-error "Not in an experiment directory")))

(defun cprr-make-bench ()
  "Run `make bench' in the current experiment directory."
  (interactive)
  (if-let ((exp (cprr--current-experiment)))
      (let ((default-directory (cprr--experiment-path exp)))
        (compile "make bench"))
    (user-error "Not in an experiment directory")))

(defun cprr-init-project ()
  "Initialize CPRR in the current project by running cprr-init.sh."
  (interactive)
  (let* ((root (or cprr-project-root
                   (read-directory-name "Project root: ")))
         (script (expand-file-name "scripts/cprr-init.sh" root)))
    (if (file-exists-p script)
        (let ((default-directory root))
          (compile (format "bash %s" (shell-quote-argument script))))
      ;; No script yet — offer to create structure manually
      (when (yes-or-no-p "No cprr-init.sh found. Create minimal structure?")
        (let ((default-directory root))
          (make-directory "experiments" t)
          (make-directory "src" t)
          (make-directory "tests" t)
          (make-directory "docs/decisions" t)
          (make-directory ".beads/templates" t)
          (message "Created CPRR directory structure in %s" root))))))

;; ── JITIR Integration ──────────────────────────────────────────

(defun cprr-search-prior-art (query)
  "Search for prior art related to QUERY across experiments.
Searches CONJECTURE.md, REFUTATION.md, and REFINEMENT.md files."
  (interactive "sPrior art search: ")
  (let ((default-directory (cprr--find-root)))
    (grep-find
     (format "find %s -name '*.md' -exec grep -l -i %s {} +"
             (shell-quote-argument cprr-experiments-dir)
             (shell-quote-argument query)))))

(defun cprr-search-refuted (query)
  "Search refuted experiments for QUERY.
Helps avoid repeating past failures."
  (interactive "sSearch refuted experiments: ")
  (let ((default-directory (cprr--find-root))
        (results '()))
    (dolist (exp (cprr--list-experiments))
      (let ((refutation-file
             (expand-file-name "REFUTATION.md" (cprr--experiment-path exp))))
        (when (file-exists-p refutation-file)
          (with-temp-buffer
            (insert-file-contents refutation-file)
            (when (and (search-forward "REFUTED" nil t)
                       (goto-char (point-min))
                       (search-forward query nil t))
              (push exp results))))))
    (if results
        (message "Refuted experiments matching \"%s\": %s"
                 query (string-join results ", "))
      (message "No refuted experiments match \"%s\"" query))))

;; ── Org-Babel Mermaid Support ──────────────────────────────────

(defun org-babel-execute:mermaid (body params)
  "Execute a mermaid BODY source block with PARAMS.
Renders to the file specified by :file parameter."
  (let* ((out-file (cdr (assq :file params)))
         (tmp-file (make-temp-file "ob-mermaid-" nil ".mmd"))
         (mmdc (or (executable-find cprr-mmdc-executable)
                   (error "mmdc not found"))))
    (unless out-file
      (error "Mermaid blocks require a :file parameter"))
    (make-directory (file-name-directory
                     (expand-file-name out-file default-directory))
                    t)
    (with-temp-file tmp-file
      (insert body))
    (let ((exit-code
           (call-process mmdc nil "*ob-mermaid*" nil
                         "-i" tmp-file
                         "-o" (expand-file-name out-file default-directory)
                         "-b" "transparent")))
      (delete-file tmp-file)
      (unless (zerop exit-code)
        (with-current-buffer "*ob-mermaid*"
          (error "Mermaid rendering failed: %s" (buffer-string)))))
    nil))

;; ── Transient Dispatch ─────────────────────────────────────────

(transient-define-prefix cprr-dispatch ()
  "CPRR: Conjecture → Proof → Refutation → Refinement."
  [:description
   (lambda ()
     (let ((exp (cprr--current-experiment)))
       (if exp
           (format "CPRR [%s] — %s"
                   (propertize exp 'face 'font-lock-keyword-face)
                   (propertize
                    (symbol-name (cprr--experiment-phase exp))
                    'face (cprr--phase-face (cprr--experiment-phase exp))))
         "CPRR — No active experiment")))
   ["Experiments"
    ("n" "New experiment"       cprr-new-experiment)
    ("c" "New child experiment" cprr-new-child-experiment)
    ("e" "Go to experiment"     cprr-goto-experiment)
    ("d" "Dashboard"            cprr-dashboard)]
   ["Navigate Phases"
    ("1" "CONJECTURE.md"  cprr-goto-conjecture)
    ("2" "PROOF.md"       cprr-goto-proof)
    ("3" "REFUTATION.md"  cprr-goto-refutation)
    ("4" "REFINEMENT.md"  cprr-goto-refinement)
    ("TAB" "Cycle phase"  cprr-cycle-phase)
    ("m" "Makefile"       cprr-goto-makefile)]
   ["Beads (bd)"
    ("b c" "Create bead"    cprr-bd-create)
    ("b s" "Set status"     cprr-bd-status)
    ("b x" "Close bead"     cprr-bd-close)
    ("b l" "List beads"     cprr-bd-list)
    ("b r" "List refuted"   cprr-bd-list-refuted)]
   ["Build & Test"
    ("t" "make test"   cprr-make-test)
    ("B" "make bench"  cprr-make-bench)]
   ["Search"
    ("s" "Prior art search"    cprr-search-prior-art)
    ("r" "Search refuted"      cprr-search-refuted)]
   ["Mermaid"
    ("M" "Render block at point"  cprr-render-mermaid-block)
    ("A" "Render all blocks"      cprr-render-all-mermaid)]
   ["Project"
    ("I" "Init CPRR project" cprr-init-project)]])

;; ── Minor Mode ─────────────────────────────────────────────────

(defvar cprr-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-p") #'cprr-dispatch)
    (define-key map (kbd "C-c p n") #'cprr-new-experiment)
    (define-key map (kbd "C-c p d") #'cprr-dashboard)
    (define-key map (kbd "C-c p e") #'cprr-goto-experiment)
    (define-key map (kbd "C-c p 1") #'cprr-goto-conjecture)
    (define-key map (kbd "C-c p 2") #'cprr-goto-proof)
    (define-key map (kbd "C-c p 3") #'cprr-goto-refutation)
    (define-key map (kbd "C-c p 4") #'cprr-goto-refinement)
    (define-key map (kbd "C-c p TAB") #'cprr-cycle-phase)
    (define-key map (kbd "C-c p t") #'cprr-make-test)
    (define-key map (kbd "C-c p s") #'cprr-search-prior-art)
    map)
  "Keymap for `cprr-mode'.")

(defun cprr--mode-line-indicator ()
  "Return a mode-line indicator for the current experiment."
  (when-let ((exp (cprr--current-experiment)))
    (let ((phase (cprr--experiment-phase exp)))
      (format " CPRR[%s:%s]"
              (substring exp 0 3)
              (substring (symbol-name phase) 0 4)))))

;;;###autoload
(define-minor-mode cprr-mode
  "Minor mode for CPRR experiment-driven development.

\\{cprr-mode-map}"
  :lighter (:eval (cprr--mode-line-indicator))
  :keymap cprr-mode-map
  :group 'cprr
  (if cprr-mode
      (message "CPRR mode enabled. C-c C-p for dispatch.")
    (message "CPRR mode disabled.")))

;;;###autoload
(defun cprr-mode-maybe ()
  "Enable `cprr-mode' if the current file is in a CPRR project."
  (when (and buffer-file-name
             (locate-dominating-file buffer-file-name "AGENTS.md"))
    (cprr-mode 1)))

;; Auto-enable in CPRR projects
;;;###autoload
(add-hook 'find-file-hook #'cprr-mode-maybe)

(provide 'cprr)

;;; cprr.el ends here
