###

Materia
It's a thing

Widget	: Crossword, Creator
Authors	: Jonathan Warner
Updated	: 10/13

###

CrosswordCreator = angular.module('crosswordCreator', [])

CrosswordCreator.controller 'crosswordCreatorCtrl', ['$scope', ($scope) ->
	$scope.widget =
		title: ''
		puzzleItems: [{question:null,answer:null,hint:null}]

	$scope.addPuzzleItem = (q=null, a=null, h=null) ->	$scope.widget.puzzleItems.push { question: q, answer: a, hint: h }
	$scope.removePuzzleItem = (index) -> $scope.widget.puzzleItems.splice(index,1)
]

Namespace('Crossword').Creator = do ->
	_title = _qset = _scope = null

	initNewWidget = (widget, baseUrl) ->
		_scope = angular.element($('body')).scope()

	initExistingWidget = (title,widget,qset,version,baseUrl) ->
		_qset = qset
		console.log qset
		_items = qset.items[0].items
		console.log _items
		_scope = angular.element($('body')).scope()
		_scope.$apply ->
			_scope.widget.title	= title
			_scope.widget.puzzleItems = []
			_scope.addPuzzleItem( _items[i].questions[0].text, _items[i].answers[0].text , _items[i].options.hint) for i in [0.._items.length-1]

	onSaveClicked = (mode = 'save') ->
		if _buildSaveData() then Materia.CreatorCore.save _title, _qset
		else Materia.CreatorCore.cancelSave 'Widget not ready to save.'

	onSaveComplete = (title, widget, qset, version) -> true

	onQuestionImportComplete = (questions) ->

	onMediaImportComplete = (questions) ->

	onMediaImportComplete = (media) -> null

	_buildSaveData = ->
		words = []
		if !_qset? then _qset = {}
		_qset.options = { hintPenalty: 50, freeWords: 2 }
		_qset.assets = []
		_qset.rand = false
		_qset.name = ''
		_title = _scope.widget.title
		_okToSave = if _title? && _title != '' then true else false

		_items = []
		_puzzleItems = _scope.widget.puzzleItems

		for i in [0.._puzzleItems.length-1]
			_items.push(_process _puzzleItems[i])
			words.push _puzzleItems[i].answer


		_items = Crossword.Puzzle.generatePuzzle _items

		_qset.items = [{ items: _items }]

		_okToSave
		
	_process = (puzzleItem) ->
		questionObj =
			text: puzzleItem.question
		answerObj =
			text: puzzleItem.answer,
			value: '100',
			id: ''

		qsetItem = {}
		qsetItem.questions = [questionObj]
		qsetItem.answers = [answerObj]
		qsetItem.id = ''
		qsetItem.type = 'QA'
		qsetItem.assets = []
		qsetItem.options = { hint: puzzleItem.hint, x: 0, y: 0 }

		qsetItem

	_trace = -> if console? and console.log? then console.log.apply console, arguments

	# Public members
	initNewWidget            : initNewWidget
	initExistingWidget       : initExistingWidget
	onSaveClicked            : onSaveClicked
	onMediaImportComplete    : onMediaImportComplete
	onQuestionImportComplete : onQuestionImportComplete
	onSaveComplete           : onSaveComplete


angular.bootstrap document, ['crosswordCreator']
