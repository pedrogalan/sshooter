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
While selecting, dotted horizontal and vertical guides follow the pointer
across the whole screen to help line up the capture.

After closing the editor, choose **Reopen Editor** from the camera menu to bring
back the last capture with its annotations, selection, and zoom exactly as you
left it. A new capture replaces the stored one.

Draw an arrow by dragging on the canvas. The arrow tool stays highlighted while
it is active; click it again to stop drawing and just select arrows. The new
arrow stays selected: drag either endpoint to change its length or direction,
or drag the line itself to move the whole arrow. Press **Delete** to remove the
selected arrow.

The square tool works the same way: drag on the canvas to mark an area. Squares
stay selected after drawing; drag a corner to resize, or drag the body to move
one. Press **Delete** to remove it.

The canvas has a checkerboard work area around the image, so annotations can
start or end outside the capture. The image and the annotations together are
treated as the content: they are fitted at up to 1:1 into the window with a
checkerboard border on every side. Smaller captures therefore get a larger grey
area. The zoom then stays wherever you put it; adding or moving annotations
never zooms the view. This zoom is visual only; Copy and Save always use the
content's real pixel size regardless of the zoom level.

To zoom manually, pinch on a trackpad or hold **⌘** and scroll; the content
zooms around the pointer. Two-finger scroll pans when you need to reach another
part of the canvas. Press **⌘0** (or two-finger double-tap) to fit all content,
including annotations that extend into the grey area, with a border again.

After the first annotation, an options panel appears at the top-right with color
swatches, line thickness buttons, and square options. Color and thickness apply
to both arrows and squares. For squares, the rounded-corner button toggles
between sharp and rounded corners, and the three fill buttons choose **full
transparency** (outline only), **medium transparency**, or **opaque**. The fill
level never changes the square's border, which is always fully opaque. Changes
apply to the selected annotation (or to the next one if nothing is selected) and
are remembered between launches. Copy and Save grow the output to include every
annotation; the added area outside the original capture stays transparent.

Press **⌘C** to copy the annotated image and close the window, or **⌘S** to save
a PNG to your chosen folder. Press **Esc** to cancel a drag, then again to
deselect an annotation, then again to close the editor.

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
