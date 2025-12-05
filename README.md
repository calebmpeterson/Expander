# Expander

Small macOS menu bar app that expands short snippet keys into text wherever you type.

## Build
- Prereqs: Xcode command line tools
- Build: `make`
- Run the built app at `build/Expander.app`

## Snippets
- Default snippets are bundled in code.
- Optional user file at `~/.expander/snippets` (KEY=VALUE per line, comments with `#`, `//`, or `;`).
- Use the menu bar “Reload Snippets” item to re-read the file without restarting.
