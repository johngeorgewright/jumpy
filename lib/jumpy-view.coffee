# TODO: Merge in @willdady's code for better accuracy.
# TODO: Remove space-pen?

### global atom ###
LabelManagerIterator = require './label-manager-iterator'
{CompositeDisposable} = require 'atom'
{View, $} = require 'space-pen'
_ = require 'lodash'

class JumpyView extends View

    @content: ->
        @div ''

    initialize: () ->
        @disposables = new CompositeDisposable()
        @commands = new CompositeDisposable()
        @labelManager = new LabelManagerIterator @disposables, @commands

        @commands.add atom.commands.add 'atom-workspace',
            'jumpy:toggle': => @toggle()
            'jumpy:reset': => @reset()
            'jumpy:clear': => @clearJumpMode()

        commands = LabelManagerIterator.chars.reduce(
            (commands, c) => _.set(commands, "jumpy:#{c}", => @getKey c),
            {}
        )
        @commands.add atom.commands.add 'atom-workspace', commands

        # TODO: consider moving this into toggle for new bindings.
        @backedUpKeyBindings = _.clone atom.keymaps.keyBindings

        @workspaceElement = atom.views.getView(atom.workspace)
        @statusBar = document.querySelector 'status-bar'
        @statusBar?.addLeftTile
            item: $('<div id="status-bar-jumpy" class="inline-block"></div>')
            priority: -1
        @statusBarJumpy = document.getElementById 'status-bar-jumpy'

        @initKeyFilters()

    getKey: (character) ->
        @statusBarJumpy?.classList.remove 'no-match'

        # Assert: labelPosition will start at 0!
        labelPosition = (if not @firstChar then 0 else 1)
        if not @labelManager.isMatchOfCurrentLabels character, labelPosition
            @statusBarJumpy?.classList.add 'no-match'
            @statusBarJumpyStatus?.innerHTML = 'No match!'
            return

        if not @firstChar
            @firstChar = character
            @statusBarJumpyStatus?.innerHTML = @firstChar
            # TODO: Refactor this so not 2 calls to observeTextEditors
            @disposables.add atom.workspace.observeTextEditors (editor) =>
                editorView = atom.views.getView(editor)
                return if $(editorView).is ':not(:visible)'
                @labelManager.markIrrelevant @firstChar
        else if not @secondChar
            @secondChar = character

        if @secondChar
            @jump() # Jump first. Currently need the placement of the labels.
            _.defer @clearJumpModeHandler

    clearKeys: ->
        @firstChar = null
        @secondChar = null

    reset: ->
        @clearKeys()
        @labelManager.unmarkIrrelevant()
        @statusBarJumpy?.classList.remove 'no-match'
        @statusBarJumpyStatus?.innerHTML = 'Jump Mode!'

    initKeyFilters: ->
        @filteredJumpyKeys = @getFilteredJumpyKeys()
        Object.observe atom.keymaps.keyBindings, ->
            @filteredJumpyKeys = @getFilteredJumpyKeys()
        # Don't think I need a corresponding unobserve

    getFilteredJumpyKeys: ->
        atom.keymaps.keyBindings.filter (keymap) ->
            keymap.command
                .indexOf('jumpy') > -1 if typeof keymap.command is 'string'

    turnOffSlowKeys: ->
        atom.keymaps.keyBindings = @filteredJumpyKeys

    toggle: ->
        @clearJumpMode()

        # Set dirty for @clearJumpMode
        @cleared = false

        # 'jumpy-jump-mode is for keymaps and utilized by tests
        document.body.classList.add 'jumpy-jump-mode'

        # TODO: Can the following few lines be singleton'd up? ie. instance var?
        @turnOffSlowKeys()
        @statusBarJumpy?.classList.remove 'no-match'
        @statusBarJumpy?.innerHTML =
            'Jumpy: <span class="status">Jump Mode!</span>'
        @statusBarJumpyStatus =
            document.querySelector '#status-bar-jumpy .status'

        @labelManager.toggle()

        @disposables.add atom.workspace.observeTextEditors (editor) =>
            editorView = atom.views.getView(editor)
            @initializeClearEvents(editorView)

    clearJumpModeHandler: =>
        @clearJumpMode()

    initializeClearEvents: (editorView) ->
        @disposables.add editorView.onDidChangeScrollTop @clearJumpModeHandler
        @disposables.add editorView.onDidChangeScrollLeft @clearJumpModeHandler

        for e in ['blur', 'click']
            editorView.addEventListener(e, _.debounce(@clearJumpModeHandler),
                true)

    clearJumpMode: ->
        if @cleared
            return

        @cleared = true
        @clearKeys()
        @statusBarJumpy?.innerHTML = ''
        @disposables.add atom.workspace.observeTextEditors (editor) =>
            editorView = atom.views.getView(editor)

            document.body.classList.remove 'jumpy-jump-mode'
            for e in ['blur', 'click']
                editorView.removeEventListener e, @clearJumpModeHandler, true
        atom.keymaps.keyBindings = @backedUpKeyBindings
        @labelManager.destroy()
        @disposables?.dispose()
        @detach()

    jump: ->
        @labelManager.jumpTo @firstChar, @secondChar

    # Returns an object that can be retrieved when package is activated
    serialize: ->

    # Tear down any state and detach
    destroy: ->
        @commands?.dispose()
        @clearJumpMode()

module.exports = JumpyView
