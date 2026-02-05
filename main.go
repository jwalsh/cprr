package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Version info (set via ldflags)
var (
	Version   = "dev"
	GitCommit = "none"
	BuildDate = "unknown"
)

type Status string

const (
	StatusOpen       Status = "open"
	StatusTesting    Status = "testing"
	StatusConfirmed  Status = "confirmed"
	StatusRefuted    Status = "refuted"
	StatusAbandoned  Status = "abandoned"
)

// Transition represents a state machine edge
type Transition struct {
	From   Status
	To     Status
	Guards []Guard
}

// Guard is a precondition for a state transition
type Guard struct {
	Name    string
	Check   func(*Conjecture) bool
	Message string
}

// State machine definition
var transitions = []Transition{
	{
		From: StatusOpen,
		To:   StatusTesting,
		Guards: []Guard{
			{
				Name:    "hypothesis_required",
				Check:   func(c *Conjecture) bool { return c.Hypothesis != "" },
				Message: "hypothesis required: use `cprr add ... -h \"your hypothesis\"`",
			},
		},
	},
	{
		From: StatusTesting,
		To:   StatusConfirmed,
		Guards: []Guard{
			{
				Name:    "min_evidence",
				Check:   func(c *Conjecture) bool { return len(c.Evidence) >= 2 },
				Message: "minimum 2 pieces of evidence required for confirmation",
			},
			{
				Name:    "hypothesis_required",
				Check:   func(c *Conjecture) bool { return c.Hypothesis != "" },
				Message: "hypothesis required to confirm",
			},
		},
	},
	{
		From: StatusTesting,
		To:   StatusRefuted,
		Guards: []Guard{
			{
				Name:    "min_evidence",
				Check:   func(c *Conjecture) bool { return len(c.Evidence) >= 1 },
				Message: "at least 1 piece of evidence required to refute",
			},
		},
	},
	// Abandoned is always reachable (escape hatch)
	{From: StatusOpen, To: StatusAbandoned, Guards: nil},
	{From: StatusTesting, To: StatusAbandoned, Guards: nil},
	{From: StatusConfirmed, To: StatusAbandoned, Guards: nil},
	{From: StatusRefuted, To: StatusAbandoned, Guards: nil},
}

// Forward path for `next` command
var forwardPath = map[Status]Status{
	StatusOpen:    StatusTesting,
	StatusTesting: StatusConfirmed,
}

// Available commands for suggestions
var commands = []string{"init", "add", "list", "show", "next", "evidence", "status", "delete", "quickstart", "help", "version"}

type Conjecture struct {
	ID          int       `json:"id"`
	Title       string    `json:"title"`
	Hypothesis  string    `json:"hypothesis"`
	Evidence    []string  `json:"evidence,omitempty"`
	Status      Status    `json:"status"`
	Tags        []string  `json:"tags,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type Config struct {
	Local bool `json:"local,omitempty"`
}

type Store struct {
	Conjectures []Conjecture `json:"conjectures"`
	NextID      int          `json:"next_id"`
	Config      Config       `json:"config,omitempty"`
}

var (
	localMode   bool
	verboseMode bool
)

func dataDir() string {
	if localMode {
		return ".cprr"
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cprr")
}

func dataFile() string {
	dir := dataDir()
	os.MkdirAll(dir, 0755)
	return filepath.Join(dir, "conjectures.json")
}

func loadStore() (*Store, error) {
	store := &Store{NextID: 1}

	// Check for local .cprr first
	if _, err := os.Stat(".cprr/conjectures.json"); err == nil {
		localMode = true
	}

	data, err := os.ReadFile(dataFile())
	if err != nil {
		if os.IsNotExist(err) {
			return store, nil
		}
		return nil, err
	}
	if err := json.Unmarshal(data, store); err != nil {
		return nil, err
	}
	localMode = store.Config.Local
	return store, nil
}

func (s *Store) save() error {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(dataFile(), data, 0644)
}

func verbose(format string, args ...interface{}) {
	if verboseMode {
		fmt.Fprintf(os.Stderr, "[verbose] "+format+"\n", args...)
	}
}

func usage() {
	fmt.Print(`cprr - Conjecture & Experiment Tracker

Quick Start:
  cprr init --examples          # Initialize with sample data
  cprr add "My hypothesis" -h "Expected outcome"
  cprr list                     # See all conjectures
  cprr next 1                   # Advance state (guards enforced)

Commands:
  init       Initialize a new store
  add        Create a conjecture
  list       List conjectures
  show       Show details
  next       Advance to next state
  evidence   Add evidence
  status     Set status directly
  delete     Remove a conjecture

Global Flags:
  -h, --help       Show help
  -v, --version    Show version
  -V, --verbose    Verbose output

Run 'cprr <command> --help' for command-specific help.
`)
}

func versionInfo() {
	fmt.Printf("cprr %s\n", Version)
	if verboseMode {
		fmt.Printf("  commit:  %s\n", GitCommit)
		fmt.Printf("  built:   %s\n", BuildDate)
		fmt.Printf("  go:      %s\n", "1.21+")
	}
}

// levenshtein calculates edit distance between two strings
func levenshtein(a, b string) int {
	if len(a) == 0 {
		return len(b)
	}
	if len(b) == 0 {
		return len(a)
	}

	matrix := make([][]int, len(a)+1)
	for i := range matrix {
		matrix[i] = make([]int, len(b)+1)
		matrix[i][0] = i
	}
	for j := range matrix[0] {
		matrix[0][j] = j
	}

	for i := 1; i <= len(a); i++ {
		for j := 1; j <= len(b); j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			matrix[i][j] = min(
				matrix[i-1][j]+1,
				matrix[i][j-1]+1,
				matrix[i-1][j-1]+cost,
			)
		}
	}
	return matrix[len(a)][len(b)]
}

func min(nums ...int) int {
	m := nums[0]
	for _, n := range nums[1:] {
		if n < m {
			m = n
		}
	}
	return m
}

func suggestCommand(input string) string {
	bestMatch := ""
	bestDistance := 3 // Only suggest if within 2 edits

	for _, cmd := range commands {
		dist := levenshtein(strings.ToLower(input), cmd)
		if dist < bestDistance {
			bestDistance = dist
			bestMatch = cmd
		}
	}
	return bestMatch
}

func parseGlobalFlags(args []string) ([]string, bool) {
	var remaining []string
	showHelp := false

	// Only parse global flags BEFORE the command
	for i := 0; i < len(args); i++ {
		arg := args[i]

		// Once we hit a non-flag, treat rest as command + args
		if !strings.HasPrefix(arg, "-") {
			remaining = append(remaining, args[i:]...)
			break
		}

		switch arg {
		case "-v", "--version":
			versionInfo()
			os.Exit(0)
		case "-h", "--help":
			showHelp = true
		case "-V", "--verbose":
			verboseMode = true
		default:
			// Unknown global flag, pass through
			remaining = append(remaining, arg)
		}
	}
	return remaining, showHelp
}

func main() {
	args, showHelp := parseGlobalFlags(os.Args[1:])

	if len(args) == 0 || showHelp {
		usage()
		os.Exit(0)
	}

	cmd := args[0]
	cmdArgs := args[1:]

	verbose("command=%s args=%v", cmd, cmdArgs)

	// Handle init before loading store
	if cmd == "init" {
		cmdInit(cmdArgs)
		return
	}

	// Handle quickstart before loading store (it may init)
	if cmd == "quickstart" {
		cmdQuickstart(cmdArgs)
		return
	}

	// Handle help/version without store
	switch cmd {
	case "help":
		usage()
		return
	case "version":
		versionInfo()
		return
	}

	store, err := loadStore()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to load store: %v\n", err)
		fmt.Fprintf(os.Stderr, "\nTry running: cprr init\n")
		os.Exit(1)
	}

	verbose("store loaded: %d conjectures", len(store.Conjectures))

	switch cmd {
	case "add":
		cmdAdd(store, cmdArgs)
	case "list", "ls":
		cmdList(store, cmdArgs)
	case "show", "get":
		cmdShow(store, cmdArgs)
	case "next":
		cmdNext(store, cmdArgs)
	case "evidence", "ev":
		cmdEvidence(store, cmdArgs)
	case "status":
		cmdStatus(store, cmdArgs)
	case "delete", "rm":
		cmdDelete(store, cmdArgs)
	default:
		fmt.Fprintf(os.Stderr, "error: unknown command '%s'\n", cmd)
		if suggestion := suggestCommand(cmd); suggestion != "" {
			fmt.Fprintf(os.Stderr, "\nDid you mean: cprr %s?\n", suggestion)
		}
		fmt.Fprintf(os.Stderr, "\nRun 'cprr --help' for usage.\n")
		os.Exit(1)
	}
}

func cmdInit(args []string) {
	var useLocal, withExamples, force, showHelp bool

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		case "--local", "-l":
			useLocal = true
		case "--examples", "-e":
			withExamples = true
		case "--force", "-f":
			force = true
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr init [flags]

Initialize a new cprr store for tracking conjectures.

Flags:
  -l, --local      Store in ./.cprr (project-local) instead of ~/.cprr
  -e, --examples   Seed with example conjectures
  -f, --force      Overwrite existing store
  -h, --help       Show this help

Examples:
  cprr init                    # Global store in ~/.cprr
  cprr init --local            # Project store in ./.cprr
  cprr init --local --examples # With sample data
`)
		return
	}

	localMode = useLocal
	targetFile := dataFile()

	verbose("target file: %s", targetFile)

	if _, err := os.Stat(targetFile); err == nil && !force {
		fmt.Fprintf(os.Stderr, "error: store already exists at %s\n", targetFile)
		fmt.Fprintf(os.Stderr, "\nTo overwrite, run: cprr init --force\n")
		os.Exit(1)
	}

	store := &Store{
		NextID: 1,
		Config: Config{Local: useLocal},
	}

	if withExamples {
		now := time.Now()
		store.Conjectures = []Conjecture{
			{
				ID:         1,
				Title:      "Caching reduces p99 latency by 50%",
				Hypothesis: "Adding Redis cache for DB queries will cut tail latency in half",
				Status:     StatusOpen,
				Tags:       []string{"performance", "infrastructure"},
				CreatedAt:  now,
				UpdatedAt:  now,
			},
			{
				ID:         2,
				Title:      "Dark mode increases engagement",
				Hypothesis: "Users with dark mode enabled have 10% longer sessions",
				Evidence:   []string{"A/B test setup with 5000 users per cohort"},
				Status:     StatusTesting,
				Tags:       []string{"ux", "experiment"},
				CreatedAt:  now,
				UpdatedAt:  now,
			},
			{
				ID:         3,
				Title:      "Null hypothesis: button color doesn't matter",
				Hypothesis: "Red vs blue CTA button has no significant conversion difference",
				Evidence:   []string{"n=10000, p=0.73", "conversion: red 3.2%, blue 3.1%"},
				Status:     StatusConfirmed,
				Tags:       []string{"ux", "experiment"},
				CreatedAt:  now,
				UpdatedAt:  now,
			},
		}
		store.NextID = 4
	}

	if err := store.save(); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to create store: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Initialized cprr store at %s\n", targetFile)
	if withExamples {
		fmt.Printf("Added %d example conjectures\n", len(store.Conjectures))
	}
	fmt.Println("\nNext steps:")
	fmt.Println("  cprr add \"Your hypothesis\" -h \"Expected outcome\"")
	fmt.Println("  cprr list")
}

func cmdAdd(store *Store, args []string) {
	var showHelp bool
	var hypothesis, tags string
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		case "--hypothesis":
			if i+1 < len(args) {
				hypothesis = args[i+1]
				i++
			}
		case "-t", "--tags":
			if i+1 < len(args) {
				tags = args[i+1]
				i++
			}
		default:
			// Check for -hVALUE style (hypothesis shorthand)
			if strings.HasPrefix(args[i], "-h") && len(args[i]) > 2 {
				hypothesis = args[i][2:]
			} else {
				positional = append(positional, args[i])
			}
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr add <title> [flags]

Create a new conjecture to track.

Arguments:
  <title>          Short description of the conjecture

Flags:
  --hypothesis <text>   Full hypothesis statement (required to advance)
  -t, --tags <list>     Comma-separated tags
  -h, --help            Show this help

Note: The hypothesis flag uses --hypothesis (not -h) to avoid
conflict with the help flag.

Examples:
  cprr add "Redis improves latency"
  cprr add "Cache hypothesis" --hypothesis "p99 drops 50%"
  cprr add "A/B test" --hypothesis "Variant B wins" -t "ux,experiment"
`)
		return
	}

	if len(positional) < 1 {
		fmt.Fprintln(os.Stderr, "error: missing title")
		fmt.Fprintln(os.Stderr, "\nUsage: cprr add <title> [--hypothesis <text>] [-t <tags>]")
		fmt.Fprintln(os.Stderr, "\nExample: cprr add \"Redis improves latency\" --hypothesis \"p99 drops 50%\"")
		os.Exit(1)
	}

	c := Conjecture{
		ID:         store.NextID,
		Title:      positional[0],
		Hypothesis: hypothesis,
		Status:     StatusOpen,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
	if tags != "" {
		c.Tags = strings.Split(tags, ",")
	}
	store.NextID++

	store.Conjectures = append(store.Conjectures, c)
	if err := store.save(); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to save: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Created conjecture #%d: %s\n", c.ID, c.Title)

	if c.Hypothesis == "" {
		fmt.Println("\nNote: No hypothesis set. To advance to 'testing', add one:")
		fmt.Printf("  cprr show %d  # then add hypothesis\n", c.ID)
	}
}

func cmdNext(store *Store, args []string) {
	var showHelp, force, dryRun bool
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		case "-f", "--force":
			force = true
		case "-n", "--dry-run":
			dryRun = true
		default:
			positional = append(positional, args[i])
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr next <id> [flags]

Advance a conjecture to the next state in the workflow.

The state machine enforces guards (preconditions) before transitions:

  open ──[hypothesis]──> testing ──[2+ evidence]──> confirmed
                              │
                              └──[1+ evidence]──> refuted

Arguments:
  <id>             Conjecture ID

Flags:
  -n, --dry-run    Preview transition without executing
  -f, --force      Bypass guard checks (not recommended)
  -h, --help       Show this help

Examples:
  cprr next 1              # Advance #1 to next state
  cprr next 1 --dry-run    # Preview what would happen
  cprr next 1 --force      # Skip guard checks
`)
		return
	}

	if len(positional) < 1 {
		fmt.Fprintln(os.Stderr, "error: missing conjecture ID")
		fmt.Fprintln(os.Stderr, "\nUsage: cprr next <id>")
		fmt.Fprintln(os.Stderr, "\nExample: cprr next 1")
		os.Exit(1)
	}

	id, err := strconv.Atoi(positional[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid ID '%s' (must be a number)\n", positional[0])
		os.Exit(1)
	}

	c := findByID(store, id)
	if c == nil {
		fmt.Fprintf(os.Stderr, "error: conjecture #%d not found\n", id)
		fmt.Fprintln(os.Stderr, "\nRun 'cprr list' to see available conjectures.")
		os.Exit(1)
	}

	nextStatus, ok := forwardPath[c.Status]
	if !ok {
		fmt.Printf("#%d is in terminal state '%s'\n", id, c.Status)
		fmt.Println("\nTerminal states cannot advance further.")
		fmt.Println("Use 'cprr status' to manually change if needed.")
		os.Exit(0)
	}

	// Find the transition
	var transition *Transition
	for i := range transitions {
		if transitions[i].From == c.Status && transitions[i].To == nextStatus {
			transition = &transitions[i]
			break
		}
	}

	if transition == nil {
		fmt.Fprintf(os.Stderr, "error: no transition defined from %s to %s\n", c.Status, nextStatus)
		os.Exit(1)
	}

	// Check guards
	var violations []string
	for _, guard := range transition.Guards {
		if !guard.Check(c) {
			violations = append(violations, fmt.Sprintf("  %s: %s", guard.Name, guard.Message))
		}
	}

	if len(violations) > 0 && !force {
		fmt.Printf("Cannot advance #%d from '%s' to '%s'\n", id, c.Status, nextStatus)
		fmt.Println("\nGuard violations:")
		for _, v := range violations {
			fmt.Println(v)
		}
		fmt.Println("\nTo fix:")
		if c.Hypothesis == "" {
			fmt.Println("  Add hypothesis: cprr show", id, "# then update")
		}
		if len(c.Evidence) < 2 && c.Status == StatusTesting {
			fmt.Printf("  Add evidence:   cprr evidence %d \"your observation\"\n", id)
		}
		fmt.Println("\nOr use --force to bypass (not recommended)")
		os.Exit(1)
	}

	if dryRun {
		fmt.Printf("[dry-run] Would advance #%d: %s -> %s\n", id, c.Status, nextStatus)
		if len(violations) > 0 && force {
			fmt.Println("  (with --force, bypassing guards)")
		}
		return
	}

	oldStatus := c.Status
	c.Status = nextStatus
	c.UpdatedAt = time.Now()

	if err := store.save(); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to save: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Advanced #%d: %s -> %s\n", id, oldStatus, nextStatus)

	// Show what's needed for next transition
	if next, ok := forwardPath[nextStatus]; ok {
		for i := range transitions {
			if transitions[i].From == nextStatus && transitions[i].To == next {
				fmt.Printf("\nTo reach '%s':\n", next)
				for _, g := range transitions[i].Guards {
					marker := "[ ]"
					if g.Check(c) {
						marker = "[x]"
					}
					fmt.Printf("  %s %s\n", marker, g.Message)
				}
				break
			}
		}
	} else {
		fmt.Println("\nConjecture reached terminal state.")
	}
}

func cmdList(store *Store, args []string) {
	var showHelp bool
	var filterStatus Status
	var filterTag string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		case "-s", "--status":
			if i+1 < len(args) {
				filterStatus = Status(args[i+1])
				i++
			}
		case "--tag":
			if i+1 < len(args) {
				filterTag = args[i+1]
				i++
			}
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr list [flags]

List all conjectures, optionally filtered.

Flags:
  -s, --status <status>   Filter by status (open, testing, confirmed, refuted, abandoned)
  --tag <tag>             Filter by tag
  -h, --help              Show this help

Examples:
  cprr list                    # All conjectures
  cprr list --status open      # Only open conjectures
  cprr list --tag performance  # Only performance-tagged
`)
		return
	}

	if len(store.Conjectures) == 0 {
		fmt.Println("No conjectures yet.")
		fmt.Println("\nGet started:")
		fmt.Println("  cprr add \"Your hypothesis\" --hypothesis \"Expected outcome\"")
		return
	}

	count := 0
	for _, c := range store.Conjectures {
		if filterStatus != "" && c.Status != filterStatus {
			continue
		}
		if filterTag != "" && !contains(c.Tags, filterTag) {
			continue
		}
		fmt.Printf("#%-3d [%-10s] %s\n", c.ID, c.Status, c.Title)
		count++
	}

	if count == 0 {
		fmt.Println("No conjectures match the filter.")
	}
}

func cmdShow(store *Store, args []string) {
	var showHelp bool
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		default:
			positional = append(positional, args[i])
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr show <id>

Show detailed information about a conjecture.

Arguments:
  <id>          Conjecture ID

Flags:
  -h, --help    Show this help

Example:
  cprr show 1
`)
		return
	}

	if len(positional) < 1 {
		fmt.Fprintln(os.Stderr, "error: missing conjecture ID")
		fmt.Fprintln(os.Stderr, "\nUsage: cprr show <id>")
		os.Exit(1)
	}

	id, err := strconv.Atoi(positional[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid ID '%s'\n", positional[0])
		os.Exit(1)
	}

	c := findByID(store, id)
	if c == nil {
		fmt.Fprintf(os.Stderr, "error: conjecture #%d not found\n", id)
		os.Exit(1)
	}

	fmt.Printf("Conjecture #%d\n", c.ID)
	fmt.Printf("Title:      %s\n", c.Title)
	fmt.Printf("Status:     %s\n", c.Status)
	if c.Hypothesis != "" {
		fmt.Printf("Hypothesis: %s\n", c.Hypothesis)
	}
	if len(c.Tags) > 0 {
		fmt.Printf("Tags:       %s\n", strings.Join(c.Tags, ", "))
	}
	if len(c.Evidence) > 0 {
		fmt.Println("Evidence:")
		for i, e := range c.Evidence {
			fmt.Printf("  %d. %s\n", i+1, e)
		}
	}
	fmt.Printf("Created:    %s\n", c.CreatedAt.Format(time.RFC3339))
	fmt.Printf("Updated:    %s\n", c.UpdatedAt.Format(time.RFC3339))

	fmt.Println()
	showStateMachine(c)
}

func showStateMachine(c *Conjecture) {
	states := []Status{StatusOpen, StatusTesting, StatusConfirmed}
	fmt.Print("Progress: ")
	for i, s := range states {
		if s == c.Status {
			fmt.Printf("[%s]", s)
		} else if i < indexOf(states, c.Status) {
			fmt.Printf("(%s)", s)
		} else {
			fmt.Printf(" %s ", s)
		}
		if i < len(states)-1 {
			fmt.Print(" -> ")
		}
	}
	fmt.Println()

	if c.Status == StatusRefuted {
		fmt.Println("  (refuted branch)")
	} else if c.Status == StatusAbandoned {
		fmt.Println("  (abandoned)")
	}
}

func indexOf(slice []Status, item Status) int {
	for i, s := range slice {
		if s == item {
			return i
		}
	}
	return -1
}

func cmdEvidence(store *Store, args []string) {
	var showHelp bool
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		default:
			positional = append(positional, args[i])
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr evidence <id> <text>

Add evidence to support or refute a conjecture.

Arguments:
  <id>      Conjecture ID
  <text>    Evidence description

Flags:
  -h, --help    Show this help

Examples:
  cprr evidence 1 "Baseline p99: 450ms"
  cprr evidence 1 "With cache: 180ms, n=10000"
  cprr evidence 1 "p-value: 0.02, statistically significant"
`)
		return
	}

	if len(positional) < 2 {
		fmt.Fprintln(os.Stderr, "error: missing ID or evidence text")
		fmt.Fprintln(os.Stderr, "\nUsage: cprr evidence <id> <text>")
		fmt.Fprintln(os.Stderr, "\nExample: cprr evidence 1 \"Baseline measurement: 450ms\"")
		os.Exit(1)
	}

	id, err := strconv.Atoi(positional[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid ID '%s'\n", positional[0])
		os.Exit(1)
	}

	c := findByID(store, id)
	if c == nil {
		fmt.Fprintf(os.Stderr, "error: conjecture #%d not found\n", id)
		os.Exit(1)
	}

	evidence := strings.Join(positional[1:], " ")
	c.Evidence = append(c.Evidence, evidence)
	c.UpdatedAt = time.Now()

	if err := store.save(); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to save: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Added evidence to #%d (%d total)\n", id, len(c.Evidence))

	// Hint about next steps
	if c.Status == StatusTesting {
		if len(c.Evidence) >= 2 {
			fmt.Println("\nReady to advance: cprr next", id)
		} else {
			fmt.Printf("\nNeed %d more evidence to advance.\n", 2-len(c.Evidence))
		}
	}
}

func cmdStatus(store *Store, args []string) {
	var showHelp bool
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		default:
			positional = append(positional, args[i])
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr status <id> <status>

Directly set a conjecture's status, bypassing guards.

Arguments:
  <id>       Conjecture ID
  <status>   New status: open, testing, confirmed, refuted, abandoned

Flags:
  -h, --help    Show this help

Note: This bypasses guard checks. Prefer 'cprr next' for normal flow.

Examples:
  cprr status 1 abandoned    # Give up on conjecture
  cprr status 1 refuted      # Mark as disproven
`)
		return
	}

	if len(positional) < 2 {
		fmt.Fprintln(os.Stderr, "error: missing ID or status")
		fmt.Fprintln(os.Stderr, "\nUsage: cprr status <id> <status>")
		fmt.Fprintln(os.Stderr, "Status: open, testing, confirmed, refuted, abandoned")
		fmt.Fprintln(os.Stderr, "\nNote: Prefer 'cprr next' for guarded transitions.")
		os.Exit(1)
	}

	id, err := strconv.Atoi(positional[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid ID '%s'\n", positional[0])
		os.Exit(1)
	}

	c := findByID(store, id)
	if c == nil {
		fmt.Fprintf(os.Stderr, "error: conjecture #%d not found\n", id)
		os.Exit(1)
	}

	newStatus := Status(positional[1])
	switch newStatus {
	case StatusOpen, StatusTesting, StatusConfirmed, StatusRefuted, StatusAbandoned:
		c.Status = newStatus
		c.UpdatedAt = time.Now()
	default:
		fmt.Fprintf(os.Stderr, "error: invalid status '%s'\n", positional[1])
		fmt.Fprintln(os.Stderr, "\nValid: open, testing, confirmed, refuted, abandoned")
		os.Exit(1)
	}

	if err := store.save(); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to save: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Updated #%d status to '%s' (guards bypassed)\n", id, newStatus)
}

func cmdDelete(store *Store, args []string) {
	var showHelp bool
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-h", "--help":
			showHelp = true
		default:
			positional = append(positional, args[i])
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr delete <id>

Permanently delete a conjecture.

Arguments:
  <id>          Conjecture ID

Flags:
  -h, --help    Show this help

Example:
  cprr delete 1
`)
		return
	}

	if len(positional) < 1 {
		fmt.Fprintln(os.Stderr, "error: missing conjecture ID")
		fmt.Fprintln(os.Stderr, "\nUsage: cprr delete <id>")
		os.Exit(1)
	}

	id, err := strconv.Atoi(positional[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid ID '%s'\n", positional[0])
		os.Exit(1)
	}

	for i, c := range store.Conjectures {
		if c.ID == id {
			store.Conjectures = append(store.Conjectures[:i], store.Conjectures[i+1:]...)
			if err := store.save(); err != nil {
				fmt.Fprintf(os.Stderr, "error: failed to save: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("Deleted conjecture #%d\n", id)
			return
		}
	}

	fmt.Fprintf(os.Stderr, "error: conjecture #%d not found\n", id)
	os.Exit(1)
}

func findByID(store *Store, id int) *Conjecture {
	for i := range store.Conjectures {
		if store.Conjectures[i].ID == id {
			return &store.Conjectures[i]
		}
	}
	return nil
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

func cmdQuickstart(args []string) {
	var showHelp bool

	for _, arg := range args {
		if arg == "-h" || arg == "--help" {
			showHelp = true
		}
	}

	if showHelp {
		fmt.Print(`Usage: cprr quickstart

Interactive walkthrough of the CPRR workflow for agents and humans.

This command:
  1. Shows the state machine and guard requirements
  2. Demonstrates a complete conjecture lifecycle
  3. Provides copy-paste examples

Flags:
  -h, --help    Show this help

No arguments required. Safe to run multiple times.
`)
		return
	}

	fmt.Println(`CPRR Quickstart
===============

## State Machine

  open ──[hypothesis]──> testing ──[2+ evidence]──> confirmed
                              │
                              └──[1+ evidence]──> refuted

  Any state ──> abandoned (escape hatch)

## Guards (Preconditions)

  open → testing:     Requires hypothesis
  testing → confirmed: Requires 2+ pieces of evidence
  testing → refuted:   Requires 1+ piece of evidence

## Workflow Demo`)

	// Check if store exists, init if not
	localMode = true // Use local store for demo
	store, err := loadStore()
	if err != nil || len(store.Conjectures) == 0 {
		fmt.Println("\n  [Creating demo store...]")
		store = &Store{
			NextID: 1,
			Config: Config{Local: true},
		}
	}

	// Create a demo conjecture
	demoID := store.NextID
	demo := Conjecture{
		ID:         demoID,
		Title:      "Quickstart demo conjecture",
		Hypothesis: "This demo will complete in <5 seconds",
		Status:     StatusOpen,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
	store.Conjectures = append(store.Conjectures, demo)
	store.NextID++
	store.save()

	fmt.Printf(`
  Created: #%d "Quickstart demo conjecture"
  Status:  open

  # Advance to testing (hypothesis already set)
  $ cprr next %d
`, demoID, demoID)

	// Advance to testing
	c := findByID(store, demoID)
	c.Status = StatusTesting
	c.UpdatedAt = time.Now()
	store.save()

	fmt.Printf(`  Status:  testing

  # Add evidence (need 2 for confirmation)
  $ cprr evidence %d "First observation"
  $ cprr evidence %d "Second observation"
`, demoID, demoID)

	// Add evidence
	c.Evidence = append(c.Evidence, "Demo evidence 1: command executed")
	c.Evidence = append(c.Evidence, "Demo evidence 2: output rendered")
	c.UpdatedAt = time.Now()
	store.save()

	fmt.Printf(`  Evidence: 2 pieces added

  # Advance to confirmed
  $ cprr next %d
`, demoID)

	// Confirm
	c.Status = StatusConfirmed
	c.UpdatedAt = time.Now()
	store.save()

	fmt.Printf(`  Status:  confirmed

## Quick Reference

  cprr init --local         # Initialize project store
  cprr add "Title" --hypothesis "H"  # Create conjecture
  cprr list                 # List all
  cprr show <id>            # Details + state machine
  cprr evidence <id> "text" # Add evidence
  cprr next <id>            # Advance (guards enforced)
  cprr status <id> refuted  # Direct status (bypasses guards)

## For Agents

The CPRR cycle maps to experiment-driven development:

  Phase        | Status    | Artifact
  -------------|-----------|------------------
  Conjecture   | open      | CONJECTURE.md
  Proof        | testing   | Implementation + tests
  Refutation   | testing   | Adversarial tests
  Refinement   | confirmed | Code in src/, ADR

Demo conjecture #%d is now confirmed. Run 'cprr list' to see it.
`, demoID)
}
