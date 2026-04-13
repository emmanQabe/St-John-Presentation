# St John's Mixed Used Development Presentation

This repository is ready to be hosted on GitHub Pages as a static site.

## Publish on GitHub Pages

1. Push this repository to GitHub.
2. Open the repository on GitHub.
3. Go to `Settings` -> `Pages`.
4. Under `Build and deployment`, set:
   - `Source`: `Deploy from a branch`
   - `Branch`: `main`
   - `Folder`: `/ (root)`
5. Save.

GitHub Pages will publish `index.html` from the repository root and serve the `Assets/` folder alongside it.

## Local files

- Main source deck: `index.html`
- Static assets: `Assets/`
- Standalone export script: `export-standalone.ps1`

## Optional standalone export

To generate a single self-contained HTML file for sharing:

```powershell
powershell -ExecutionPolicy Bypass -File .\export-standalone.ps1
```

This writes `index-standalone.html`.
