exports.triggerMouseEvent = (element, eventType) ->
    clickEvent = document.createEvent 'MouseEvents'
    clickEvent.initEvent eventType, true, true
    element.dispatchEvent clickEvent
