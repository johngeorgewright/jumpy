UILabelManager = require '../ui-label-manager'
{triggerMouseEvent} = require '../events'

class TabsLabelManager extends UILabelManager
    getElements: ->
        elements = atom.document.querySelectorAll '.tab-bar .tab'
        if elements.length > 1 then elements else []

    getLabelPrepender: (element) ->
        element.querySelector '.title'

    getContainingElements: ->
        atom.document.getElementsByClassName 'tab-bar'

module.exports = TabsLabelManager
