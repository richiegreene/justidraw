# justidraw

Experimental DAW.

[![Video of Justidraw in action](http://img.youtube.com/vi/JhLQWR3zdeU/0.jpg)](http://www.youtube.com/watch?v=JhLQWR3zdeU)

For the optimal experience, use with a drawing tablet on Windows (wintab driver).

macOS and Linux work but only mouse input.

# How to run

1. Install the latest version of [love2d](https://love2d.org/)
2. Download the [latest release](https://github.com/Sin-tel/justidraw/releases) (you need the `.love` file)

# Controls
* middle mouse: pan
* hold ctrl: zoom
### freehand draw tool
* left click: draw
* hold ctrl: erase
* hold shift: smooth
* radius determines input stabilization
### line tool
* left click: draw flat lines
* hold alt: draw slanted lines
* hold ctrl: erase
### selection
* left click: normal select
* hold shift: add
* hold ctrl: subtract

## Shortcuts
* I: show keyboard shortcuts
### Tools
* B: freehand draw (Brush)
* P: line tool (Pen)
* E: Eraser
* O: pan/zoom
* G: Grab
* M: Move
* S: Smooth
* F: Flatten
* N: eNvelope tool
* H: Dodge/burn envelope (ctrl to decrease)
* T: Transpose/stretch
* U: smUdge / vibrato
### Selection
* R: Rectangular selection
* L: Lasso selection
* D: Deselect
* shift+D: duplicate selection
* Delete / backspace: delete selection. With nothing selected, opens a new project.
* J: Join ends of selected notes
* shift+n: toggle between selecting notes or vertices
### Vertex density
A note is a chain of vertices, and the synth draws a straight line between each
pair of them, in pitch and in volume alike. So a vertex that already sits on the
line between its two neighbours carries no information: dropping it does not
change a single sample. Recorded, imported and heavily edited songs collect a
great many of those, and every one of them costs drawing time, undo memory and
responsiveness.
* V: thin the selection. Each press removes up to half of the vertices, and only
ever removes one when the straight line replacing it stays within 3 cents and
0.03 pressure of it, so what you hear stays put. Press it again to go further;
it stops when there is nothing safe left to remove. The message line reports the
count before and after, and the largest pitch error introduced.
* shift+V: densify the selection, by putting a vertex in the middle of every
segment. It carries the value the synth was interpolating there anyway, so this
one cannot change the sound at all. Use it to get brush resolution back on a
note you thinned too far.
* ctrl+V: cycle the maximum segment length (80, 200, 400, 800 pixels, where 100
is one beat). This is how far apart vertices are allowed to get, so it sets how
far `V` can thin. It is also the spacing notes are resampled to while you edit
them, so raising it and thinning leaves a song that stays thin; lowering it
again fills the notes back in the next time you draw on them.
* ctrl/cmd+H: open a ratio field for time-warping the selection, accepting exact
values like 2, 0.5, 3:2, or 2/1.

Both commands work on whatever is selected: a lasso, a rectangle, whole notes
(`shift+N`), or every note in a part (`shift+ctrl+alt+N`). With nothing selected
they act on the note under the cursor. Vertices are only ever added or removed,
never moved, and the first and last vertex of a note are always left alone, so
nothing shifts in time and no note changes length.
### Parts
Notes can be tagged with one of 32 parts so that separate voices are easy to
tell apart. Each part draws in its own color, with a matching highlight color
when selected. Untagged notes keep the normal theme colors.
* ctrl+alt+1 .. 32: assign the selection to a part (cmd+option on macOS). Type
the two digits quickly for parts 10 through 32.
Pressing the same combination again clears it back to the default color.
With nothing selected, the note under the cursor is used.
* ctrl+alt+R: assign the selection by average register from bottom to top into
parts 1 through 32.
* ctrl+alt+0: clear the part of the selection
* shift+ctrl+alt+1 .. 32: select every note in that part, anywhere in the project
* shift+ctrl+alt+0: select every note that has not been assigned to a part
* alt+1 .. 32: mute a part. Type the two digits quickly for parts 10 through 32.
Muted notes are greyed out and stop sounding, both during playback and in a
rendered wav. Muting takes effect straight away, even while the song is playing.
* alt+0: mute the notes that have not been assigned to a part

A muted part is also locked. It cannot be selected, erased, grabbed, moved,
smoothed, flattened, smudged or drawn onto, and new notes will not join onto
it, so it sits there as a fixed backdrop to work against. Anything of it that
was selected is released when you mute it. Unmute to edit it again.

Parts are stored in the save file, mutes are not: like the reverb and echo
switches they last for the session only.
A part always covers a whole note, so selecting a single vertex is enough to
tag everything connected to it. Joining two notes (`J`, or by drawing one onto
the end of another) keeps the part of the note on the left, so the joined note
ends up in one color.
### File
* Space: play/pause
* ctrl+Z: undo
* ctrl+Y / ctrl+shift+Z: redo
* ctrl+R: render wav
* ctrl+S: save 
* ctrl+O: open save folder 
* ctrl+N: rename project
* Escape: quit
### Misc
* [ and ] : change brush radius (when applicable)
* \+ and - : change bpm
* left/right arrows: move bpm grid
* up/down arrows: change volume
* Y: Hold down to view local harmonic series grid
* ctrl+T: cycle between themes
* ctrl+B: cycle between synthesizers
* ctrl+P: toggle audio preview when editing
* ctrl+F: toggle follow mode (nice for recording videos)
* shift+e: toggle echo effect
* shift+r: toggle reverb effect

Drag and drop save files to open them!
Your last save file will be loaded on startup.
Start a new project with by hitting backspace or delete with nothing selected.
New projects get a randomly generated name, rename them with `ctrl+N`.

You will find a file `user_themes.lua` in your save directory.
Edit it to define custom themes (requires restart).

Part colors are part of the theme, under the `parts` key:
```lua
parts = {
	{ color = "#ff8a2b", highlight = "#ffc46b" },
	{ color = "#3fcf6e" }, -- highlight is optional, a lighter tint is used
	"#a472ff",             -- so is the table, a bare color works too
	{ 1.0, 0.3, 0.49 },
}
```
Any theme that leaves `parts` out (all of the older ones do) gets the built-in
palette that suits its background, so existing `user_themes.lua` files keep
working untouched. `muteFade` (0.0 - 1.0, 0.75 by default) sets how far a muted
part fades towards the background.

The yellow bar in top right shows the CPU load, if it gets high you might need to reduce the number of simultaneous notes.
The green bar shows the peak volume, if it goes red, you should probably reduce the volume (down arrow).
