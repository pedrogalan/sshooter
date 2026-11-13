# sshooter

A small native macOS menu bar screenshot utility.

## Build and launch

Build a standalone app bundle and launch it through macOS Launch Services:

```sh
./Scripts/build-app.sh
open dist/sshooter.app
```

The app appears in the menu bar. Choose **Capture Area** or press **⌘⇧2**,
drag over the screen, and the selected area opens in the annotation window.
Choose **Arrow**, click its start and end points, then press **⌘C** to copy the
annotated image and close the window.

The first capture asks macOS for Screen Recording permission. Grant it to
**sshooter** in System Settings → Privacy & Security → Screen & System Audio
Recording, then quit and reopen sshooter if macOS asks you to.
