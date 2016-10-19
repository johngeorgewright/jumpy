UILabelManager = require '../ui-label-manager'

class TreeViewManager extends UILabelManager
    getElements: ->
        atom.document.querySelectorAll '.tree-view *[data-path]'

    select: ({element}) ->
        atom.commands.dispatch element, 'tree-view:show'
        super
        atom.commands.dispatch element, 'tree-view:open-selected-entry'

    getContainingElements: ->
        atom.document.getElementsByClassName 'tree-view'

module.exports = TreeViewManager
