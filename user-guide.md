# Lazy-Tube User Guide

## What this release includes

This release package bundles the Lazy-Tube backend into a standalone Windows executable named Lazy-Tube.exe.
It also includes the configuration files, data directory, and this user guide for easier sharing.

## How to use the release

1. Extract the published folder to a location on your computer.
2. Run Lazy-Tube.exe.
3. Open the local web address shown in the console window.
4. If prompted, allow the app through your firewall.

## Notes

- The app expects local Ollama to be installed and running if you want AI generation features.
- The backend reads configuration from the bundled config folder and data folder.
- For troubleshooting, check the console window for startup errors.

## Building a new release

From the project root, run:

```bat
publish.bat
```

This creates the executable under the dist/publish folder.
