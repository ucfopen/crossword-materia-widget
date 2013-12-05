###

Materia
It's a thing

Widget	: Crossword, Creator
Authors	: Jonathan Warner
Updated	: 10/13

###

Namespace('Crossword').Creator = do ->
	_title = _qset = _scope = _hasFreshPuzzle = null

	initNewWidget = (widget, baseUrl) ->
		_scope = angular.element($('body')).scope()
		_scope.$apply ->
			_scope.widget.title	= 'New Crossword Widget'
			_scope.generateNewPuzzle = ->
				_hasFreshPuzzle = false
				_buildSaveData()
			_scope.noLongerFresh = ->
				_hasFreshPuzzle = false

	initExistingWidget = (title,widget,qset,version,baseUrl) ->
		# Set up the scope functions
		initNewWidget widget, baseUrl

		_qset = qset
		_items = qset.items[0].items

		_scope.$apply ->
			_scope.widget.title	= title
			_scope.widget.puzzleItems = []
			_scope.widget.freeWords = qset.options.freeWords
			_scope.widget.hintPenalty = qset.options.hintPenalty
			_scope.addPuzzleItem( _items[i].questions[0].text, _items[i].answers[0].text , _items[i].options.hint) for i in [0.._items.length-1]

		_drawCurrentPuzzle _items
		_hasFreshPuzzle = true

	onSaveClicked = (mode = 'save') ->
		if not _buildSaveData()
			return Materia.CreatorCore.cancelSave 'Required fields not filled out'
		Materia.CreatorCore.save _title, _qset

	onSaveComplete = (title, widget, qset, version) -> true

	onQuestionImportComplete = (items) ->
		_scope = angular.element($('body')).scope()
		_scope.$apply ->
			_scope.addPuzzleItem item.questions[0].text, item.answers[0].text, item.options.hint for item in items

	_buildSaveData = ->
		if !_qset? then _qset = {}

		_qset.options = { hintPenalty: _scope.widget.hintPenalty, freeWords: _scope.widget.freeWords }

		words = []

		_qset.assets = []
		_qset.rand = false
		_qset.name = ''
		_title = _scope.widget.title
		_okToSave = if _title? && _title != '' then true else false

		# if the puzzle has changed, regenerate
		if not _hasFreshPuzzle
			_items = []
			_puzzleItems = _scope.widget.puzzleItems

			for i in [0.._puzzleItems.length-1]
				_items.push _process _puzzleItems[i]
				words.push _puzzleItems[i].answer

			# generate the puzzle using the guessing algorithm in puzzle.coffee
			_items = Crossword.Puzzle.generatePuzzle _items
			if !_items
				return false

			_drawCurrentPuzzle _items

			_qset.items = [{ items: _items }]

			_hasFreshPuzzle = _okToSave

		_okToSave

	_drawCurrentPuzzle = (items) ->
		$('#preview').empty()
			
		for item in items
			letters = item.answers[0].text.split ''
			x = item.options.x
			y = item.options.y

			for i in [0..letters.length-1]
				if item.options.dir == 0
					letterLeft = x + i
					letterTop = y
				else
					letterLeft = x
					letterTop = y + i

				letter = document.createElement 'div'

				letter.id = 'letter_' + letterLeft + '_' + letterTop
				letter.className = 'letter'
				letter.style.top = letterTop * 15 + 'px'
				letter.style.left = letterLeft * 16 + 'px'
				letter.innerHTML = letters[i].toUpperCase()

				if letters[i] == ' '
					# if it's a space, make it a black block
					letter.className += ' space'

				$('#preview').append letter

		
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
	
	# Crosswords don't have media
	onMediaImportComplete = (media) -> null

	# Public members
	initNewWidget            : initNewWidget
	initExistingWidget       : initExistingWidget
	onSaveClicked            : onSaveClicked
	onMediaImportComplete    : onMediaImportComplete
	onQuestionImportComplete : onQuestionImportComplete
	onSaveComplete           : onSaveComplete

# Now that the creator code is available, load in the controller and bootstrap it

CrosswordCreator = angular.module('crosswordCreator', [])

CrosswordCreator.controller 'crosswordCreatorCtrl', ['$scope', ($scope) ->
	$scope.widget =
		title: ''
		hintPenalty: 50
		freeWords: 1
		puzzleItems: [{question:'',answer:'',hint:''}]

	$scope.addPuzzleItem = (q='', a='', h='') -> $scope.widget.puzzleItems.push { question: q, answer: a, hint: h }
	$scope.removePuzzleItem = (index) ->
		$scope.widget.puzzleItems.splice(index,1)
		$scope.noLongerFresh()
]

angular.bootstrap document, ['crosswordCreator']
