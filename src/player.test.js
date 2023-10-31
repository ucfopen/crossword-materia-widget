const fs = require('fs')
const path = require('path')

describe('Player', function() {
	require('angular/angular.js')
	require('angular-mocks/angular-mocks.js')

	var widgetInfo;
	var qset;

	const html = fs.readFileSync(path.resolve(__dirname, './player.html'))

	beforeEach(() => {
		jest.resetModules();

		document.documentElement.innerHTML = html.toString();

		// mock materia
		global.Materia = {
			Engine: {
				start: jest.fn(),
				end: jest.fn(),
				setHeight: jest.fn()
			},
			Score: {
				submitQuestionForScoring: jest.fn()
			}
		}

		global.$ = require('jquery');

		// load qset
		widgetInfo = require('./demo.json');
		qset = widgetInfo.qset;

		require('../node_modules/materia-widget-dependencies/js/materia.js');
		require('./player.coffee');
	});

	test('widget starts properly', () => {
		Crossword.Engine.start(widgetInfo, qset.data);

		expect(global.Materia.Engine.setHeight).toHaveBeenCalled()
	});
});