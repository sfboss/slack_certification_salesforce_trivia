# Agent Task: Generate MkDocs Documentation Site

## Objective

Create a comprehensive, production-ready MkDocs documentation site that fully documents the entire Slack Certification Salesforce Trivia application. The documentation must cover both the Salesforce and Slack integration sides, include complete implementation details extracted from source code, and provide end-to-end user guides. Every public function, class, API endpoint, slash command, event handler, Apex class, Lightning Web Component, and configuration option must be documented with examples grounded in the actual source code — no placeholders, no generic boilerplate.

## Guiding Principles

1. **Source-of-truth first**: Every doc page must be derived from real files in this repo. Cite file paths and line ranges where useful.
2. **No hallucinations**: If a feature/command/endpoint is not in the source, do not invent it. Mark gaps in a `docs/_gaps.md` file for follow-up.
3. **Cross-link everything**: Every Salesforce concept should link to its Slack counterpart and vice versa.
4. **Runnable examples**: All code snippets must be copy-paste runnable (with placeholders for secrets clearly marked as `<YOUR_TOKEN>`).
5. **Diagrams over prose**: Use Mermaid for sequence diagrams, ERDs, and architecture views wherever it clarifies flow.

## Task Overview

You are tasked with generating a fully functional MkDocs site that integrates:

- Local application source code documentation (Apex, LWC, Node/Python, configs)
- Existing docs, READMEs, and configuration files in the repo
- Salesforce integration details (objects, fields, flows, permission sets, connected apps)
- Slack bot integration details (manifest, scopes, commands, events, interactivity)
- Complete user guides, admin guides, and getting started instructions
- Developer onboarding, contribution, and deployment runbooks

## Step-by-Step Instructions

### 1. Audit the Local Codebase

- Scan all source files in the project root
- Identify key directories: `salesforce/`, `slack/`, `src/`, `config/`, `tests/`, etc.
- Extract function signatures, class definitions, and module purposes
- Document API endpoints and webhooks
- Note configuration requirements and environment variables

### 2. Examine Existing Documentation

- Review all existing `.md` files in the project
- Identify architecture diagrams and setup guides
- Extract configuration examples and best practices
- Note any installation or deployment instructions

### 3. Structure the MkDocs Site

Create the following directory structure:

```
docs/
├── index.md                 # Home page and overview
├── getting-started/
│   ├── installation.md      # Installation instructions
│   ├── prerequisites.md     # Requirements (Node.js, Python, etc.)
│   └── quick-start.md       # Quick start guide
├── salesforce/
│   ├── overview.md          # Salesforce integration overview
│   ├── setup.md             # Salesforce configuration steps
│   ├── apis.md              # Salesforce API endpoints
│   ├── authentication.md    # Authentication flow
│   └── deployment.md        # Deployment to Salesforce org
├── slack/
│   ├── overview.md          # Slack bot overview
│   ├── setup.md             # Slack workspace setup
│   ├── commands.md          # Slash commands reference
│   ├── events.md            # Slack events handling
│   └── permissions.md       # Required Slack permissions
├── user-guide/
│   ├── features.md          # Feature descriptions
│   ├── workflows.md         # Common workflows
│   ├── troubleshooting.md   # Troubleshooting guide
│   └── faq.md               # Frequently asked questions
├── architecture/
│   ├── overview.md          # System architecture
│   ├── data-flow.md         # Data flow diagrams
│   └── components.md        # Component descriptions
├── api-reference/
│   ├── salesforce-api.md    # Salesforce API reference
│   └── slack-api.md         # Slack API reference
└── development/
    ├── contributing.md      # Contributing guidelines
    ├── testing.md           # Testing procedures
    └── deployment.md        # Deployment procedures
```

### 4. Generate Core Documentation Files

**docs/index.md** - Homepage

- Project overview
- Key features
- Quick links to getting started
- Architecture at a glance

**docs/getting-started/installation.md**

- System prerequisites (Node.js, Python versions, databases)
- Step-by-step installation commands
- Verification steps

**docs/getting-started/quick-start.md**

- 5-minute setup guide
- Basic configuration
- Running first test

**docs/salesforce/overview.md**

- Salesforce integration purpose
- Objects and fields used
- Data synchronization details

**docs/salesforce/setup.md**

- Org setup requirements
- Custom objects creation
- Permission set assignments
- Connected app configuration

**docs/slack/overview.md**

- Slack bot capabilities
- Supported commands
- User interaction flows

**docs/slack/setup.md**

- Slack app creation steps
- OAuth token configuration
- Event subscriptions setup
- App installation

**docs/user-guide/features.md**

- Trivia quiz functionality
- Scoring system
- Leaderboards
- Certification tracking

**docs/user-guide/workflows.md**

- Starting a quiz
- Submitting answers
- Viewing results
- Tracking progress

### 5. Extract and Document Code

For each major component, create reference documentation:

- Function signatures and parameters
- Return types and examples
- Error handling
- Usage examples

### 6. Create mkdocs.yml Configuration

```yaml
site_name: Slack Certification Salesforce Trivia
site_description: Complete documentation for the Salesforce-Slack Trivia application
docs_dir: docs
site_dir: site
theme:
    name: material
    palette:
        scheme: slate
        primary: blue
        accent: blue
    features:
        - navigation.tabs
        - navigation.sections
        - toc.integrate
        - search.suggest
        - search.highlight
plugins:
    - search
    - mermaid2
nav:
    - Home: index.md
    - Getting Started:
          - Installation: getting-started/installation.md
          - Prerequisites: getting-started/prerequisites.md
          - Quick Start: getting-started/quick-start.md
    - Salesforce Guide:
          - Overview: salesforce/overview.md
          - Setup: salesforce/setup.md
          - APIs: salesforce/apis.md
          - Authentication: salesforce/authentication.md
    - Slack Guide:
          - Overview: slack/overview.md
          - Setup: slack/setup.md
          - Commands: slack/commands.md
          - Events: slack/events.md
    - User Guide:
          - Features: user-guide/features.md
          - Workflows: user-guide/workflows.md
          - Troubleshooting: user-guide/troubleshooting.md
          - FAQ: user-guide/faq.md
    - Architecture:
          - Overview: architecture/overview.md
          - Data Flow: architecture/data-flow.md
          - Components: architecture/components.md
    - API Reference:
          - Salesforce: api-reference/salesforce-api.md
          - Slack: api-reference/slack-api.md
    - Development:
          - Contributing: development/contributing.md
          - Testing: development/testing.md
          - Deployment: development/deployment.md
```

### 7. Build and Deploy

```bash
# Install dependencies
pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin

# Build the site
mkdocs build

# Serve locally for testing
mkdocs serve

# Deploy to GitHub Pages or hosting service
mkdocs gh-deploy
```

## Deliverables

- ✅ Complete docs/ directory with all markdown files
- ✅ mkdocs.yml configuration file
- ✅ API reference documentation
- ✅ User guides and tutorials
- ✅ Salesforce integration documentation
- ✅ Slack integration documentation
- ✅ Getting started guide with installation steps
- ✅ Architecture and design documentation
- ✅ Troubleshooting and FAQ sections

## Output Format

Place all documentation files in the appropriate directories and create a single `mkdocs.yml` file in the project root. Ensure all markdown follows proper formatting with appropriate headers, code blocks, and links.
