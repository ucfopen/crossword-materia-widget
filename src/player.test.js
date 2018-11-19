describe('Player', function() {

    require('materia-server-client-assets/src/js/materia-namespace')

    var widgetInfo
    var qset

    beforeEach(() => {
        jest.resetModules()

        global.Materia = {
            Engine: {
                start: jest.fn(),
                alert: jest.fn(),
                end: jest.fn()
            },
            Score: {
                submitFinalScoreFromClient: jest.fn()
            }
        }

        global.$ = require('jquery')

        require('./player.coffee')
        widgetInfo = require('./demo.json')
        qset = widgetInfo.qset
    })
    
    // put tests here

});