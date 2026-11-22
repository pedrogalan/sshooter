# sShooter

sShooter is a lightweight, native macOS menu bar screenshot utility. Press **⌘⇧2**, drag over an area of the screen, and mark it up with arrows, squares, pencil and highlight strokes, text, stamps, and blur, then crop, before copying or saving it.

[Download sShooter](https://github.com/pedrogalan/sshooter/releases/latest)

## Requirements

- macOS 14 or later
- Apple silicon or Intel Mac
- Screen Recording permission to capture the screen

## Install

1. Download the ZIP from the [GitHub Releases page](https://github.com/pedrogalan/sshooter/releases).
2. Open the ZIP and move `sShooter.app` to your Applications folder.
3. Open sShooter. If macOS warns that it can’t verify the app, Control-click `sShooter.app`, choose **Open**, then confirm.
4. Take a screenshot with **⌘⇧2**. When macOS asks for Screen Recording, open **Permissions** in Settings and grant it, then quit and reopen sShooter if macOS asks you to.

sShooter is distributed without an Apple Developer ID signature or notarization, so macOS may show a security warning on first launch. The app is universal and runs natively on both Apple silicon and Intel Macs.

## Use sShooter

sShooter runs in the menu bar, not the Dock. Click the camera icon to open its menu, then choose **Capture area** or press **⌘⇧2** and drag over the screen. While selecting, dotted horizontal and vertical guides follow the pointer across the whole screen to help line up the capture.

The selected area opens in the annotation window. The Pointer tool is selected by default: it keeps the arrow cursor active and clicks on the image do nothing. Choose an annotation tool to draw.

- **Arrow** — drag on the canvas to draw an arrow. The arrow tool stays highlighted while it is active; click it again to return to the Pointer tool. The new arrow stays selected: drag either endpoint to change its length or direction, or drag the line itself to move the whole arrow.
- **Square** — drag on the canvas to mark an area. Squares stay selected after drawing; drag a corner to resize, or drag the body to move one.
- **Blur** — drag a rectangle to redact part of the capture; the image underneath is blurred. Blur regions are edited like squares. Blur is baked into Copy and Save at full resolution.
- **Pencil** — drag freehand to draw a thin, solid line. The stroke stays selected after drawing; drag it to move it. Pencil strokes render above blur but below arrows and squares, so sharper annotations stay legible on top.
- **Highlight** — drag freehand to draw a translucent marker stroke, like a real highlighter. The stroke stays selected after drawing; drag it to move it. The pencil and the marker share one freehand engine but keep their own colour and thickness, so you can mix fine solid lines with broad translucent ones. Highlight strokes render above blur but below arrows and squares, so sharper annotations stay legible on top.
- **Text** — with the text tool active the pointer becomes an I-beam: click anywhere to start typing. **Return** adds a newline so labels can span several lines; click outside the label or press **Esc** to commit it. Drag a label to move it, or double-click it to edit the wording. A selected label gets four corner handles and a circular rotation handle just outside its top-right corner: drag a corner to change the font size, or drag the circular handle to rotate the label through ±180°. The editing field stays horizontal and centred on the label, so wording is easy to change even after rotation. Text renders above the arrows, squares, and blur regions.
- **Stamp** — choose a colour, then click the canvas to drop a ready-sized stamp or drag to draw it at the size you want. A border appears and you type directly on it; **Return** finishes the text. Stamps start horizontal. Drag a corner handle to resize, drag the circular handle just outside the top-right corner to rotate, and drag the stamp body to move it. Double-click a stamp to edit its wording later, even after rotation; **Esc** cancels the current edit. **Delete** removes the selected stamp. Stamps have a worn-ink texture so they look printed rather than pixel-perfect, and they are baked into Copy and Save.
- **Crop** — click the crop button to trim the capture. Drag the frame to move it, drag a corner or edge handle to resize it, or drag outside it to draw a new frame. Press **Return** to apply the crop or **Esc** to cancel it. Cropping only ever trims: once you apply a crop the discarded area is gone, and cropping again works within what is left. It is still undoable, so **⌘Z** brings the full capture back. Applying or cancelling a crop returns to the Pointer tool.

Press **Delete** to remove the selected annotation. Use **⌘Z** to undo annotation changes and **⇧⌘Z** to redo them. Text entry is undoable one edit at a time, including after you commit the label; resizing or rotating a text label is one undo step. Adding or changing a stamp is one undo step when you finish its text.

As soon as a drawing tool is selected, an options bar appears at the top-right and shows only that tool’s controls. The arrow and square tools show colour swatches and a line-thickness slider; the square tool also adds a rounded-corner toggle and three fill buttons: **full transparency** (outline only), **medium transparency**, or **opaque**. The pencil and highlight tools each show colour swatches and a thickness slider of their own: the pencil draws thin, solid lines and the marker draws broad, translucent ones, and each remembers its own colour and width. On the thickness sliders the thin line on the left and the thick line on the right mark the narrowest and widest strokes, and dragging one resizes the selected annotation live. The text tool shows text colour swatches, background choices, and the text-size buttons, and a selected label gets corner resize handles plus a separate circular rotation handle. The stamp tool shows colour swatches only; its text is typed on the canvas, and a selected stamp gets the same resize and rotation handles. The blur tool has no styling and the crop tool uses the whole canvas, so the bar hides while either is active. The fill level never changes the square’s border, which is always fully opaque. Changes apply to the selected annotation (or to the next one if nothing is selected) and are remembered between launches.

The canvas has a checkerboard work area around the image, so annotations can start or end outside the capture. The image and the annotations together are treated as the content: they are fitted at up to 1:1 into the window with a checkerboard border on every side. Smaller captures therefore get a larger grey area. The zoom then stays wherever you put it; adding or moving annotations never zooms the view. This zoom is visual only; Copy and Save always use the content’s real pixel size regardless of the zoom level.

To zoom manually, pinch on a trackpad or hold **⌘** and scroll; the content zooms around the pointer. Two-finger scroll pans when you need to reach another part of the canvas. Press **⌘0** (or two-finger double-tap) to fit all content, including annotations that extend into the grey area, with a border again.

Press **⌘C** to copy the annotated image and close the window, or **⌘S** to save a PNG to your chosen folder. Without a crop, Copy and Save grow the output to include every annotation; the added area outside the original capture stays transparent. Once a crop is applied, Copy and Save use the crop frame instead and anything drawn outside it is cut off. Press **Esc** to cancel a drag, then again to deselect an annotation, then again to close the editor.

After closing the editor, choose **Reopen editor** from the camera menu to bring back the last capture with its annotations, selection, and zoom exactly as you left it. A new capture replaces the stored one.

While the annotation window is open, sShooter temporarily behaves like a regular app: it shows its own menu bar (File, Edit, Window) and a Dock icon. Closing the editor returns it to a menu-bar-only app. **⌘Q** (or **⌘W**) closes the editor but keeps sShooter running. To quit the app completely, choose **Quit sShooter** from the camera menu in the menu bar (or from the **sShooter** app menu while the editor is open).

## Settings

Open **Settings** from the camera menu. It has three tabs:

- **General** — choose the screenshot folder and optionally save each capture automatically.
- **Permissions** — shows the Screen Recording status and links to the relevant System Settings pane.
- **About** — version, project link, and license.

Automatic saves contain the original capture without annotations; use **⌘S** in the editor to save arrows, text, and other annotations with the image.

## Permissions

sShooter needs Screen Recording to capture the screen. The first capture asks for it; you can also grant it from the Permissions tab. If macOS keeps asking, quit and reopen sShooter after granting it.

## Uninstall

Quit sShooter from the camera menu in the menu bar, then remove `sShooter.app` from your Applications folder.

## License

sShooter is available under the [MIT License](LICENSE).

Stamps use the [Due Date font](https://www.1001fonts.com/due-date-font.html) by Typographer Mediengestaltung, with the full character set by Dieter Steffmann. It is embedded in the app under the [1001Fonts Free For Commercial Use License](https://www.1001fonts.com/licenses/ffc.html) and is not offered as a separate download.
