describe('Creator', () => {
	require('angular/angular.js')
	require('angular-mocks/angular-mocks.js')

	var $controller, $rootScope

	beforeEach(() => {
		jest.resetModules()
		angular.mock.module('crosswordCreator')
		global.Materia = {
			CreatorCore: {
				start: jest.fn(),
				save: jest.fn(),
				cancelSave: jest.fn()
			}
		}
		global.$ = require('jquery')

		require('./creator.coffee')

		// use angular mock to access angular modules
		inject(function(_$controller_) {
			$controller = _$controller_
			// $rootScope = _$rootScope_
		})
	})

	test('crosswordCreatorCtrl calls creatorCore start', () => {
		// var $scope = $rootScope.$new()
		var $scope = { $watch: jest.fn() }
		var controller = $controller('crosswordCreatorCtrl', { $scope })
		expect(global.Materia.CreatorCore.start).toHaveBeenCalledTimes(1)
	})

	test('Creator has expected callbacks', () => {
		var $scope = { $watch: jest.fn() }
		var controller = $controller('crosswordCreatorCtrl', { $scope })

		expect($scope).toHaveProperty('initNewWidget', expect.any(Function))
		expect($scope).toHaveProperty('initExistingWidget', expect.any(Function))
		expect($scope).toHaveProperty('onSaveClicked', expect.any(Function))
		expect($scope).toHaveProperty('onSaveComplete', expect.any(Function))
		expect($scope).toHaveProperty('onQuestionImportComplete', expect.any(Function))
	})

	test('initExistingWidget sets up environment correctly', () => {
		var demo = require('./demo.json')
		var $scope = {
				$apply: jest.fn().mockImplementation(fn => {
					if(angular.isFunction(fn)) fn()
				}),
				$watch: jest.fn()
			}
		var controller = $controller('crosswordCreatorCtrl', { $scope })
		var callback = global.Materia.CreatorCore.start.mock.calls.pop()[0]

		callback.initExistingWidget('Famous Landmarks',demo.name,demo.qset.data,2,'base-url')

		// THIS WORKS
		// $scope.$apply.mock.calls.pop()[0]()
		// console.log($scope.widget.title)

		// $scope.$apply.mock.calls.pop()[0]()
		// console.log($scope.widget.title)

		// THIS DOESNT
		// let apply = $scope.$apply.mock.calls[1][0]
		// apply()
		// console.log($scope.widget.title)

		expect($scope.widget.title).toBe('Famous Landmarks')
		expect($scope.widget.puzzleItems.length).toBe(6)
		expect($scope.widget.freeWords = demo.qset.data.options.freeWords)
		expect($scope.widget.hintPenalty = demo.qset.data.options.hintPenalty)
	})

	test('onSaveClicked saves correctly', () => {
		var demo = require('./demo.json')
		var $scope = {
			$apply: jest.fn().mockImplementation(fn => {
				if(angular.isFunction(fn)) fn()
			}),
			$watch: jest.fn()
		}
		var controller = $controller('crosswordCreatorCtrl', { $scope })
		var callback = global.Materia.CreatorCore.start.mock.calls.pop()[0]

		callback.initExistingWidget('Famous Landmarks',demo.name,demo.qset.data,2,'base-url')

		callback.onSaveClicked()
		expect(global.Materia.CreatorCore.cancelSave).toHaveBeenCalledTimes(0)
		expect(global.Materia.CreatorCore.save).toHaveBeenCalledTimes(1)
	})

	test('onQuestionImportComplete properly adds an item', () => {
		var demo = require('./demo.json')
		var $scope = {
			$apply: jest.fn().mockImplementation(fn => {
				if(angular.isFunction(fn)) fn()
			}),
			$watch: jest.fn()
		}

		var controller = $controller('crosswordCreatorCtrl', { $scope })
		var callback = global.Materia.CreatorCore.start.mock.calls.pop()[0]

		callback.initExistingWidget('Famous Landmarks',demo.name,demo.qset.data,2,'base-url')
		expect($scope.widget.puzzleItems.length).toBe(6)

		var imported = [
			{
				"questions": [
					{
						"text":"Here is some test text"
					}
				],
				"answers": [
					{
						"text":"Here is some test answer text"
					}
				],
				"options": {
					"hint":"What is the airspeed velocity of an unladen swallow?",

				},
				"id": 0
			}
		]

		callback.onQuestionImportComplete(imported)
		expect($scope.widget.puzzleItems.length).toBe(7)
	})

})