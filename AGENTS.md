# pkgflow Architecture & Design

This document explains the internal architecture and design decisions of pkgflow for developers and AI agents working on the codebase.

## Overview

pkgflow is a universal package manifest transformer for Nix that bridges multiple package management formats. It's designed to be modular, extensible, and work seamlessly with NixOS, home-manager, and nix-darwin.

## Architecture

### Module Structure

```
pkgflow/
├── flake.nix           # Flake outputs and module exports
├── shared.nix          # Shared options and global configuration
├── home.nix            # Core manifest processing (works for both home-manager & NixOS)
├── darwin.nix          # Darwin-specific Homebrew conversion
├── default.nix         # Default module bundle (home-manager/NixOS)
├── darwin-default.nix  # Default module bundle (Darwin)
├── config/
│   └── mapping.toml    # Nix ↔ Homebrew package name mappings
└── examples/           # Usage examples
```

### Design Principles

1. **Single Responsibility**: Each module handles one concern
   - `shared.nix`: Global configuration options
   - `home.nix`: Manifest parsing and package resolution
   - `darwin.nix`: Homebrew conversion logic

2. **Platform Flexibility**: `home.nix` automatically detects context
   - Checks for `environment.systemPackages` to determine if running in NixOS/Darwin
   - Uses `mkMerge` to conditionally apply configurations

3. **Lazy Evaluation**: Only processes manifests when modules are enabled

4. **Extensibility**: Easy to add new format transformers (future: APT, DNF, etc.)

## Core Logic

### Manifest Processing (`home.nix`)

The manifest processing pipeline:

1. **Load Manifest**: Import TOML file using `lib.importTOML`
2. **System Filtering**: Apply system compatibility checks
3. **Package Resolution**: Resolve packages from nixpkgs or flake inputs
4. **Installation**: Install to `home.packages` or `environment.systemPackages`

#### System Matching Strategy

```nix
systemMatches = attrs:
  !manifestCfg.requireSystemMatch
  || !(attrs ? systems)
  || lib.elem pkgs.system attrs.systems;
```

Logic breakdown:
- If `requireSystemMatch = false`: Accept packages without `systems` OR packages where current system is listed
- If `requireSystemMatch = true`: ONLY accept packages where current system is explicitly listed

**Default behavior** (`requireSystemMatch = false`):
- Package without `systems` → ✅ Install
- Package with matching system → ✅ Install
- Package with non-matching system → ❌ Skip

### Darwin Homebrew Strategy (`darwin.nix`)

The Darwin module implements a **selective filtering strategy** to enable dual Nix/Homebrew workflows:

```nix
packages = lib.filterAttrs (name: attrs: !(attrs ? systems)) originalPackages;
```

**Key insight**: Packages with `systems` attribute are **Nix-exclusive**.

#### macOS Best Practices

**Recommended Strategy 1: Homebrew-First (Most Common)**

Use Homebrew for most packages, Nix only for packages unavailable in Homebrew:

```nix
# Enable both modules
pkgflow.homebrewManifest.enable = true;

pkgflow.manifestPackages = {
  enable = true;
  requireSystemMatch = true;  # IMPORTANT: Only install packages with explicit systems
};
```

**Why this works:**
- `homebrewManifest` installs packages **WITHOUT** `systems` → Homebrew
- `manifestPackages` with `requireSystemMatch = true` installs packages **WITH** `systems` → Nix
- No overlap = No duplicate installations

**Manifest structure:**
```toml
[install]
# Common CLI tools → Homebrew (better macOS integration)
git.pkg-path = "git"
neovim.pkg-path = "neovim"
nodejs.pkg-path = "nodejs"

# Nix-specific packages → Nix only
nixfmt-rfc-style.pkg-path = "nixfmt-rfc-style"
nixfmt-rfc-style.systems = ["aarch64-darwin", "x86_64-linux"]

# Flake packages → Nix only
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin"]
```

**Recommended Strategy 2: Nix-Only**

Use Nix for everything (same behavior as Linux):

```nix
pkgflow.manifestPackages = {
  enable = true;
  # requireSystemMatch = false (default)
};
```

**Why this works:**
- Same as NixOS/Linux behavior
- No Homebrew needed
- All compatible packages install via Nix

#### Why This Design?

On macOS, users typically want:
- **Homebrew**: Better macOS integration, native binaries, auto-updates
- **Nix**: Reproducibility, packages unavailable in Homebrew, specific versions

The `systems` attribute serves dual purposes:
1. **Cross-platform compatibility**: Filter packages by architecture/OS
2. **macOS marker**: Designate "Nix-only" packages when using Homebrew-first strategy

**Decision Matrix:**

| Package Type | No `systems` | Has `systems` |
|--------------|--------------|---------------|
| `homebrewManifest` | ✅ Install | ❌ Skip |
| `manifestPackages` (requireSystemMatch=false) | ✅ Install | ✅ Install if matches |
| `manifestPackages` (requireSystemMatch=true) | ❌ Skip | ✅ Install if matches |

This design prevents duplicate installations and gives fine-grained control.

### Package Resolution

Two types of packages are supported:

1. **Regular nixpkgs packages**:
   ```toml
   git.pkg-path = "git"
   neovim.pkg-path = "neovim"
   ```
   Resolved via: `lib.attrByPath (splitString "." pkg-path) null pkgs`

2. **Flake packages**:
   ```toml
   helix.flake = "github:helix-editor/helix"
   ```
   Resolved via: `flakeInputs.<name>.packages.<system>.default`

## Configuration Flow

### Global vs Local Options

```nix
# Global configuration (shared.nix)
pkgflow.manifest.file = ./manifest.toml;
pkgflow.manifest.flakeInputs = inputs;

# Module-specific override (home.nix)
pkgflow.manifestPackages = {
  enable = true;
  manifestFile = ./other-manifest.toml;  # Overrides global
};
```

**Resolution order**: Module-specific > Global > null

### Convenience Option

The `pkgflow.enable` option (in `shared.nix`) provides smart defaults:

```nix
pkgflow.enable = true;
# Expands to:
pkgflow.manifestPackages.enable = true;
pkgflow.manifestPackages.manifestFile = <auto-detected>;
```

Auto-detection searches for:
1. `./manifest.toml`
2. `./.flox/env/manifest.toml`
3. `pkgflow.manifest.file` (global)

## Optimization Opportunities

### Current Implementation Details

1. **TOML Parsing**: Done per-module (can be cached globally)
2. **Package Resolution**: Happens at evaluation time (pure, cacheable)
3. **Flake Input Resolution**: Requires explicit passing (could use global option)

### Performance Characteristics

- **Build-time**: No extra overhead (pure Nix evaluation)
- **Evaluation time**: Linear with number of packages in manifest
- **Memory**: Minimal (lazy evaluation of package attributes)

## Extension Points

### Adding New Format Support

To add support for a new package format (e.g., Brewfile, apt packages):

1. Create a new module file (e.g., `brewfile.nix`)
2. Implement format-specific parsing logic
3. Reuse `processManifest` or create custom resolver
4. Export module in `flake.nix`

Example structure:
```nix
# brewfile.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.pkgflow.brewfileImport;

  parseBrewfile = file: /* ... */;

  convertToNixPkgs = brewPackages: /* ... */;
in
{
  options.pkgflow.brewfileImport = { /* ... */ };

  config = lib.mkIf cfg.enable {
    home.packages = convertToNixPkgs (parseBrewfile cfg.brewfile);
  };
}
```

### Mapping Files

The `config/mapping.toml` file handles package name differences:

```toml
[[package]]
nix = "nodejs"
brew = "node"

[[package]]
nix = "delta"
brew = "git-delta"
```

Format:
- `nix`: Package path in nixpkgs or flake URL
- `brew`: Homebrew formula/cask name
- `type`: "formula" (default) or "cask"
- `args`: Optional array of Homebrew install arguments

## Common Patterns

### Pattern: Dual Install (Nix + Homebrew)

```nix
# Install same manifest to both Nix and Homebrew
pkgflow.manifest.file = ./manifest.toml;

pkgflow.manifestPackages.enable = true;  # Nix packages

pkgflow.homebrewManifest.enable = true;  # Homebrew conversion
```

Result: Packages without `systems` → Homebrew, Packages with `systems` → Nix

### Pattern: Project-Specific Manifests

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.homeModules.default ];

  # Different manifests for different purposes
  pkgflow.manifestPackages = {
    enable = true;
    manifestFile = ./dev-tools.toml;
  };

  # Could add another module instance for different manifest
  # (would require extending the module system)
}
```

### Pattern: System-Specific Packages

```toml
[install]
# Cross-platform
git.pkg-path = "git"

# Linux only
systemd.pkg-path = "systemd"
systemd.systems = ["x86_64-linux", "aarch64-linux"]

# macOS only
iina.pkg-path = "iina"
iina.systems = ["x86_64-darwin", "aarch64-darwin"]
```

## Error Handling

### Current Behavior

- Missing manifest file: Silent failure (returns empty package list)
- Invalid TOML: Nix evaluation error
- Package not found: Filtered out (null check)
- Flake input missing: Package skipped if flakeInputs not provided

### Validation (Post-Optimization)

After implementing validation assertions:
- Missing manifest: Clear error message with path
- Invalid path: Assertion failure before evaluation
- Missing flake inputs: Warning when flake packages detected

## Testing Strategy

### Manual Testing

Use the examples in `examples/` directory:
```bash
cd examples/
nix build .#homeConfigurations.example.activationPackage
```

### Integration Testing

Future: Add to `flake.nix`:
```nix
checks = {
  example-home = import ./examples/home-manager.nix;
  example-darwin = import ./examples/darwin.nix;
};
```

## Future Enhancements

1. **CLI Tool**: Standalone converter (`pkgflow convert manifest.toml --to brewfile`)
2. **Bidirectional Conversion**: Generate manifests from existing Nix configs
3. **Package Validation**: Verify packages exist before installation
4. **Profile Support**: Multiple named package sets per manifest
5. **Conditional Packages**: Per-host, per-user package selection

## Contributing Guidelines

When modifying pkgflow:

1. **Maintain Backward Compatibility**: Existing configs should continue working
2. **Document System Matching**: Any changes to filtering logic must be documented
3. **Update Examples**: Keep `examples/` in sync with new features
4. **Preserve Modularity**: Each module should remain independently functional
5. **Test Multi-Platform**: Verify on Linux, macOS (x86_64 + aarch64)

## Debugging Tips

### Enable Trace Output

```nix
pkgflow.manifestPackages = {
  enable = true;
  manifestFile = lib.traceVal ./manifest.toml;
};
```

### Check Resolved Packages

```bash
nix eval .#homeConfigurations.myhost.config.home.packages --json | jq
```

### Inspect Module Options

```bash
nix repl
:lf .
:p nixosModules.default
```

## References

- [Flox Manifest Spec](https://flox.dev/docs/concepts/manifest/)
- [Home-Manager Modules](https://nix-community.github.io/home-manager/index.xhtml#sec-writing-modules)
- [Nix Module System](https://nixos.wiki/wiki/Module)
- [Homebrew Bundle Format](https://github.com/Homebrew/homebrew-bundle)
