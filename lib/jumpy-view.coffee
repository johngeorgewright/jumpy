{View, $} = require 'space-pen'
_ = require 'lodash'

lowerCharacters =
    (String.fromCharCode(a) for a in ['a'.charCodeAt()..'z'.charCodeAt()])
upperCharacters =
    (String.fromCharCode(a) for a in ['A'.charCodeAt()..'Z'.charCodeAt()])
keys = []

# A little ugly.
# I used itertools.permutation in python.
# Couldn't find a good one in npm.  Don't worry this takes < 1ms once.
for c1 in lowerCharacters
    for c2 in lowerCharacters
        keys.push c1 + c2
for c1 in upperCharacters
    for c2 in lowerCharacters
        keys.push c1 + c2
for c1 in lowerCharacters
    for c2 in upperCharacters
        keys.push c1 + c2

module.exports =
class JumpyView extends View

    @content: ->
        @div ''

    initialize: (serializeState) ->
        atom.commands.add 'atom-workspace',
            'jumpy:toggle': => @toggle()
            'jumpy:reset': => @reset()
            'jumpy:clear': => @clear()

        for characterSet in [lowerCharacters, upperCharacters]
            for c in characterSet
                atom.commands.add 'atom-workspace',
                    'jumpy:' + c: (c) => @getKey c

        # TODO: consider moving this into toggle for new bindings.
        @backedUpKeyBindings = _.clone atom.keymap.keyBindings

        @workspaceElement = atom.views.getView(atom.workspace)
        @workspaceElement.statusBar?.prependLeft(
            '<div id="status-bar-jumpy" class="inline-block"></div>')

    getKey: (character, labelPosition) ->
        character = character.type.charAt(character.type.length - 1)
        isMatchOfCurrentLabels = (character, labelPosition) ->
            found = false
            atom.workspace.observeTextEditors (editor) ->
                editorView = atom.views.getView(editor)
                $(editorView).find('.label:not(.irrelevant)').each (i, label) ->
                    if label.innerHTML[labelPosition] == character
                        found = true
                        return false
            return found

        labelPosition = (if not @firstChar then 0 else 1)
        if !isMatchOfCurrentLabels character, labelPosition
            @workspaceElement.statusBar?.find '#status-bar-jumpy'
                .addClass 'no-match'
                .find '.status'
                    .html 'No match!'
            return
        else
            @workspaceElement.statusBar?.find '#status-bar-jumpy'
                .removeClass 'no-match'

        if not @firstChar
            @firstChar = character
            @workspaceElement.statusBar?.find '#status-bar-jumpy .status'
                .html @firstChar
            atom.workspace.observeTextEditors (editor) =>
                editorView = atom.views.getView(editor)
                for label in editorView.find '.jumpy.label'
                    if label.innerHTML.indexOf(@firstChar) != 0
                        label.classList.add 'irrelevant'
        else if not @secondChar
            @secondChar = character

        if @secondChar
            @jump() # Jump first.  Currently need the placement of the labels.
            @clearJumpMode()

    clearKeys: ->
        @firstChar = null
        @secondChar = null

    reset: ->
        @clearKeys()
        atom.workspace.observeTextEditors (editor) =>
            editorView = atom.views.getView(editor)
            $(editorView).find '.irrelevant'
                .removeClass 'irrelevant'
        @workspaceElement.statusBar?.find '#status-bar-jumpy'
            .removeClass 'no-match'
            .find '.status'
                .html 'Jump Mode!'

    clear: ->
        @clearJumpMode()

    turnOffSlowKeys: ->
        atom.keymap.keyBindings = atom.keymap.keyBindings.filter (keymap) ->
            keymap.command.indexOf('jumpy') > -1

    toggle: ->
        wordsPattern = new RegExp (atom.config.get 'jumpy.matchPattern'), 'g'

        fontSize = atom.config.get 'jumpy.fontSize'
        fontSize = .75 if isNaN(fontSize) or fontSize > 1
        fontSize = (fontSize * 100) + '%'
        highContrast = atom.config.get 'jumpy.highContrast'

        @turnOffSlowKeys()
        @workspaceElement.statusBar?.find '#status-bar-jumpy'
            .removeClass 'no-match'
            .html 'Jumpy: <span class="status">Jump Mode!</span>'

        @allPositions = {}
        $(@workspaceElement).find '*'
            .on 'mousedown scroll', (e) =>
                @clear()

        nextKeys = _.clone keys
        atom.workspace.observeTextEditors (editor) =>
            editorView = atom.views.getView(editor)
            return if editorView.hidden
            $(editorView).addClass 'jumpy-jump-mode'
            $labels = $(editorView).find '.overlayer'
                .append '<div class="jumpy labels"></div>'

            drawLabels = (column) =>
                return unless nextKeys.length

                keyLabel = nextKeys.shift()
                position = {row: lineNumber, column: column}
                # creates a reference:
                @allPositions[keyLabel] = {
                    editor: editor.id
                    position: position
                }
                pixelPosition = editor
                    .pixelPositionForScreenPosition [lineNumber,
                    column]
                labelElement =
                    $("<div class='jumpy label'>#{keyLabel}</div>")
                        .css
                            left: pixelPosition.left
                            top: pixelPosition.top
                            fontSize: fontSize
                if highContrast
                    labelElement.addClass 'high-contrast'
                $labels
                    .append labelElement

            [firstVisibleRow, lastVisibleRow] = editor.getVisibleRowRange()
            for lineNumber in [firstVisibleRow...lastVisibleRow]
                lineContents = editor.lineTextForScreenRow(lineNumber)
                if editor.isFoldedAtScreenRow(lineNumber)
                    drawLabels 0
                else
                    while ((word = wordsPattern.exec(lineContents)) != null)
                        drawLabels word.index

    clearJumpMode: ->
        @clearKeys()
        $('#status-bar-jumpy').html ''
        atom.workspace.observeTextEditors (editor) ->
            editorView = atom.views.getView(editor)
            $(editorView)
                .find('.jumpy')
                .remove()
                .removeClass 'jumpy-jump-mode'
        atom.keymap.keyBindings = @backedUpKeyBindings
        @detach()

    jump: ->
        location = @findLocation()
        if location == null
            console.log "Jumpy canceled jump.  No location found."
            return
        useHomingBeacon = atom.config.get 'jumpy.useHomingBeaconEffectOnJumps'
        atom.workspace.observeTextEditors (editor) ->
            editorView = atom.views.getView(editor)
            currentEditor = editorView.getEditor()
            if currentEditor.id != location.editor
                return

            pane = editorView.getPaneView()
            pane.activate()
            isVisualMode = editorView.view().hasClass 'visual-mode'
            if isVisualMode || (currentEditor.getSelections().length == 1 &&
                currentEditor.getSelectedText() != '')
                    currentEditor.selectToScreenPosition(location.position)
            else
                currentEditor.setCursorScreenPosition location.position
            if useHomingBeacon
                cursor = pane.find '.cursors .cursor'
                cursor.addClass 'beacon'
                setTimeout ->
                    cursor.removeClass 'beacon'
                , 150
            console.log "Jumpy jumped to: #{@firstChar}#{@secondChar} at " +
                "(#{location.position.row},#{location.position.column})"

    findLocation: ->
        label = "#{@firstChar}#{@secondChar}"
        if label of @allPositions
            return @allPositions[label]

        return null

    # Returns an object that can be retrieved when package is activated
    serialize: ->

    # Tear down any state and detach
    destroy: ->
        console.log 'Jumpy: "destroy" called. Detaching.'
        @clearJumpMode()
        @detach()
