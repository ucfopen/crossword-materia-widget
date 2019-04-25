# Overview

Crossword is a quiz tool that uses words and clues to randomly generate a crossword puzzle.

![Annotated Crossword screen image](assets/widget_guides_crossword.jpg "Annotated Crossword screen")

> Annotated Crossword screen
1. Title of the widget
2. Zoom in/out controls
3. Clue list
4. Selected clue
5. Puzzle area
6. Hints remaining
7. Free words remaining
8. Finish button
9. Help: Keyboard controls
10. Print puzzle


## Details

### Clue Selected State

After clicking on a clue in the clue list, two buttons appear underneath the selected clue.

**Get Hint** will provide you with a hint (if hints are provided for the widget), using one of your remaining hints. Using a hint also reduces the score for the clue by a percentage set in the settings by the creator.

Clicking the **Free Word** button will automatically fill in the word (if free words have been provided).

### Submitting

Clicking **Finish** will submit your puzzle and take you to the score screen to review how you did.

### Example

```javascript
Materia.CreatorCore.alert('Alert Title', 'Alert Message')
```

## Materia.CreatorCore.showMediaImporter

Display Materia's media importer.  The importer will allow the user to upload and choose media files to insert into the widget.  To make use of this method, make sure you define a `onMediaImportComplete` callback with `Materia.CreatorCore.start`.

| Argument | Required | Description
| --- | --- | ---
| mediaTypes | **yes** | Array of media types the user is allowed to upload. Supported types: `jpg`, `gif`, `png`, and `mp3`

### Example

```javascript
// import images
Materia.CreatorCore.showMediaImporter(['jpg', 'gif', 'png'])

// import audio
Materia.CreatorCore.showMediaImporter(['mp3'])
```
