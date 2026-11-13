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
annotated image and close the window, or **⌘S** to save a PNG to your chosen
folder. Press **Esc** to cancel an arrow in progress, or again to close the
editor.

Choose **Save Folder** from the menu bar menu to change the destination. If no
folder is configured, saving asks for one the first time.

While the annotation window is open, sshooter temporarily behaves like a regular
app: it shows its own menu bar (File, Edit, Window) and a Dock icon. Closing the
editor returns it to a menu-bar-only app.

**⌘Q** (or **⌘W**) closes the editor but keeps sshooter running. To quit the
app completely, choose **Quit sshooter** from the camera menu in the menu bar
(or from the **sshooter** app menu while the editor is open).

The first capture asks macOS for Screen Recording permission. Grant it to
**sshooter** in System Settings → Privacy & Security → Screen & System Audio
Recording, then quit and reopen sshooter if macOS asks you to.
