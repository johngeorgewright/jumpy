LabelManager = require './label-manager'
{triggerMouseEvent} = require './events'

class UILabelManager extends LabelManager
    constructor: ->
        super
        @locations = []

    getLabelPrepender: (element) ->
        element

    getElements: ->
        []

    toggle: (keys) ->
        elements = @getElements()
        for element in elements when keys.length
            prepender = @getLabelPrepender element
            label = @createLabel keys.shift()
            @locations.push {label, element}
            prepender.parentNode.insertBefore label, prepender

    destroy: ->
        location.label.remove() while location = @locations.shift()
        super

    drawBeacon: ({label}) ->
        beacon = @createBeacon()
        label.parentNode.insertBefore beacon, label
        setTimeout beacon.remove.bind(beacon), 2000

    jumpTo: (firstChar, secondChar) ->
        match = "#{firstChar}#{secondChar}"
        location = @locations.find ({label}) -> label.textContent is match
        return unless location
        @select location
        @drawBeacon location

    select: ({element}) ->
        triggerMouseEvent element, 'mousedown'

    markIrrelevant: (firstChar) ->
        @locations
            .filter(({label}) -> not label.textContent.startsWith firstChar)
            .forEach(({label}) -> label.classList.add 'irrelevant')

    unmarkIrrelevant: ->
        label.classList.remove 'irrelevant' for {label} in @locations

    isMatchOfCurrentLabels: (character, position) ->
        @locations.find ({label}) -> label.textContent[position] is character

    getContainingElements: ->
        []

    getClearEvents: ->
        ['blur', 'click']

    initializeClearEvents: (clear) ->
        for containers in @getContainingElements()
            for e in @getClearEvents()
                do (treeView, e) =>
                    container.addEventListener e, clear
                    @disposables.add new Disposable ->
                        container.removeEventListener e, clear

module.exports = UILabelManager
