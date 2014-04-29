###

Materia
It's a thing

Widget	: Crossword, Creator
Authors	: Jonathan Warner
Updated	: 4/14

###

CrosswordCreator = angular.module('crosswordCreator', [])

CrosswordCreator.controller 'crosswordCreatorCtrl', ['$scope', ($scope) ->
	$scope.widget =
		title: 'New Crossword Widget'
		hintPenalty: 50
		freeWords: 1
		puzzleItems: []
	
	$scope.step = 0

	$scope.addPuzzleItem = (q='', a='', h='') -> $scope.widget.puzzleItems.push { question: q, answer: a, hint: h, found: true }
	$scope.removePuzzleItem = (index) ->
		$scope.widget.puzzleItems.splice(index,1)
		$scope.noLongerFresh()
		$scope.generateNewPuzzle()

	$scope.changeTitle = ->
		$('#backgroundcover, .title').addClass 'show'
		$('.title input[type=text]').focus()
		$('.title input[type=button]').click ->
			$('#backgroundcover, .title').removeClass 'show'
	
	$scope.introComplete = ->
		$('#backgroundcover, .intro').removeClass 'show'
		$scope.widget.title = $('.intro input[type=text]').val() or $scope.widget.title
		$scope.step = 1

	$scope.hideCover = ->
		$('#backgroundcover, .title, .intro').removeClass 'show'
	
	$scope.showOptions = ->
		$('#backgroundcover, .options').addClass 'show'
		$('.options input[type=button]').click ->
			$('#backgroundcover, .options').removeClass 'show'
	
	$scope.$watch('widget.hintPenalty', (newValue, oldValue) ->
		if newValue? and newValue.match and not newValue.match(/^[0-9]?[0-9]?$/)
			$scope.widget.hintPenalty = oldValue
	)
	$scope.$watch('widget.freeWords', (newValue, oldValue) ->
		if newValue? and newValue.match and not newValue.match(/^[0-9]?[0-9]?$/)
			$scope.widget.freeWords = oldValue
	)
]


Namespace('Crossword').Creator = do ->
	_title = _qset = _scope = _hasFreshPuzzle = null

	initScope = ->
		_scope = angular.element($('body')).scope()
		_scope.$apply ->
			_scope.generateNewPuzzle = (force = false, reset = false) ->
				return if _hasFreshPuzzle and not force
				$('.loading').show()
				_scope.isBuilding = true

				setTimeout ->
					if reset
						Crossword.Puzzle.resetRandom()

					_hasFreshPuzzle = false
					_buildSaveData(reset)
					$('.loading').hide()
					_scope.stopTimer()

					_scope.$apply ->
						_scope.isBuilding = false
				,300

			_scope.noLongerFresh = ->
				_hasFreshPuzzle = false
				_scope.resetTimer()
			_scope.startTimer = ->
				_scope.stopTimer()
				_scope.timer = setInterval(_scope.generateNewPuzzle, 1000)
			_scope.stopTimer = -> clearInterval(_scope.timer)
			_scope.resetTimer = ->
				_scope.stopTimer()
				_scope.startTimer()

		$('#printbtn').click (e) ->
			_scope.generateNewPuzzle()
			setTimeout ->
				Crossword.Print.printBoard(e, { name: _scope.widget.title }, _qset.items[0].items)
			,500

	initNewWidget = (widget, baseUrl) ->
		initScope()

		$('#backgroundcover, .intro').addClass 'show'

		$('.intro input[type=button]').click ->
			$scope.$apply $scope.introComplete

	initExistingWidget = (title,widget,qset,version,baseUrl) ->
		# Set up the scope functions
		initScope()

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

	_buildSaveData = (force = false) ->
		if !_qset? then _qset = {}

		_qset.options = { hintPenalty: _scope.widget.hintPenalty, freeWords: _scope.widget.freeWords }

		words = []

		_qset.assets = []
		_qset.rand = false
		_qset.name = ''
		_title = _scope.widget.title
		_okToSave = if _title? && _title != '' then true else false

		_puzzleItems = _scope.widget.puzzleItems

		# if the puzzle has changed, regenerate
		if not _hasFreshPuzzle
			_items = []

			for i in [0.._puzzleItems.length-1]
				_items.push _process _puzzleItems[i]
				words.push _puzzleItems[i].answer

			# generate the puzzle using the guessing algorithm in puzzle.coffee
			_items = Crossword.Puzzle.generatePuzzle _items, force
			if !_items
				return false

			_drawCurrentPuzzle _items

			_qset.items = [{ items: _items }]

			_hasFreshPuzzle = _okToSave

		console.log 'generating'

		for i in [0..._puzzleItems.length]
			if not _qset.items[0].items[i]?
				continue
			_qset.items[0].items[i].questions[0].text = _puzzleItems[i].question
			_qset.items[0].items[i].options.hint = _puzzleItems[i].hint

		_scope.unused = false
		for item in _scope.widget.puzzleItems
			found = false if item.answer != ''
			for qitem in _qset.items[0].items
				if item.answer == qitem.answers[0].text
					found = true

			item.found = found
			if not found
				_scope.unused = true
		_scope.error = _scope.unused or _scope.tooBig

		_okToSave

	_drawCurrentPuzzle = (items) ->
		$('#preview_kids').empty()

		_left = _top = 0
			
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

				_left = letterLeft if letterLeft > _left
				_top = letterTop if letterTop > _top

				letter = document.createElement 'div'

				letter.id = 'letter_' + letterLeft + '_' + letterTop
				letter.className = 'letter'
				letter.style.top = letterTop * 25 + 'px'
				letter.style.left = letterLeft * 27 + 'px'
				letter.innerHTML = letters[i].toUpperCase()

				if letters[i] == ' '
					# if it's a space, make it a black block
					letter.className += ' space'

				$('#preview_kids').append letter
		
		_scope.$apply ->
			_scope.tooBig = _left > 17 or _top > 20
			_scope.error = _scope.tooBig or _scope.unused
		
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

