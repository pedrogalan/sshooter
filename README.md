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

Draw an arrow by dragging on the canvas. The arrow tool stays highlighted while
it is active; click it again to stop drawing and just select arrows. The new
arrow stays selected: drag either endpoint to change its length or direction,
or drag the line itself to move the whole arrow. Press **Delete** to remove the
selected arrow.

The canvas has a checkerboard work area around the image, so arrows can start
or end outside the capture. The image and the arrows together are treated as
the content: they are fitted at up to 1:1 into the window with a checkerboard
border on every side. Smaller captures therefore get a larger grey area. The
zoom then stays wherever you put it; adding or moving arrows never zooms the
view. This zoom is visual only; Copy and Save always use the content's real
pixel size regardless of the zoom level.

To zoom manually, pinch on a trackpad or hold **⌘** and scroll; the content
zooms around the pointer. Two-finger scroll pans when you need to reach another
part of the canvas. Press **⌘0** (or two-finger double-tap) to fit all content,
including arrows that extend into the grey area, with a border again.

After the first arrow, an options panel appears at the top-right with color
swatches and line thickness buttons. Changes apply to the selected arrow (or to
the next arrow if nothing is selected) and are remembered between launches.
Copy and Save grow the output to include every arrow; the added area outside
the original capture stays transparent.

Press **⌘C** to copy the annotated image and close the window, or **⌘S** to save
a PNG to your chosen folder. Press **Esc** to cancel a drag, then again to
deselect an arrow, then again to close the editor.

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
