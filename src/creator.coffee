CrosswordCreator = angular.module('crosswordCreator', [])

CrosswordCreator.directive 'focusMe', ($timeout, $parse) ->
	link: (scope, element, attrs) ->
		model = $parse(attrs.focusMe)
		scope.$watch model, (value) ->
			if value is true
				$timeout ->
					element[0].focus()
		element.bind 'blur', ->
			scope.$apply(model.assign(scope, false))

CrosswordCreator.directive 'selectMe', ($timeout, $parse) ->
	link: (scope, element, attrs) ->
		model = $parse(attrs.selectMe)
		scope.$watch model, (value) ->
			if value is true
				$timeout ->
					$(element[0]).focus().select()
		element.bind 'blur', ->
			scope.$apply(model.assign(scope, false))


CrosswordCreator.controller 'crosswordCreatorCtrl', ($scope) ->

	### Initialize class variables ###

	_title = _qset = _hasFreshPuzzle = null

	$scope.widget =
		title: 'New Crossword Widget'
		hintPenalty: 50
		freeWords: 1
		puzzleItems: []

	# dialogs
	$scope.showIntroDialog = false
	$scope.showOptionsDialog = false
	$scope.showTitleDialog = false

	### Materia Interface Methods ###

	materiaInterface =
		initNewWidget: (widget, baseUrl) ->
			$scope.$apply ->
				$scope.showIntroDialog = true

		initExistingWidget: (title,widget,qset,version,baseUrl) ->
			_qset = qset
			_items = qset.items[0].items

			$scope.$apply ->
				$scope.widget.title	= title
				$scope.widget.puzzleItems = []
				$scope.widget.freeWords = qset.options.freeWords
				$scope.widget.hintPenalty = qset.options.hintPenalty
				$scope.addPuzzleItem( _items[i].questions[0].text, _items[i].answers[0].text , _items[i].options.hint, _items[i].id) for i in [0..._items.length]

			_drawCurrentPuzzle _items
			_hasFreshPuzzle = true

		onSaveClicked: (mode = 'save') ->
			if not _buildSaveData()
				return Materia.CreatorCore.cancelSave 'Required fields not filled out'
			Materia.CreatorCore.save _title, _qset

		onSaveComplete: (title, widget, qset, version) -> true

		onQuestionImportComplete: (items) ->
			$scope.$apply ->
				$scope.addPuzzleItem item.questions[0].text, item.answers[0].text, item.options.hint, item.id for item in items

		onMediaImportComplete : (media) -> null

	### Private methods ###

	_buildSaveData = (force = false) ->
		if !_qset? then _qset = {}

		_qset.options = { hintPenalty: $scope.widget.hintPenalty, freeWords: $scope.widget.freeWords }

		words = []

		_qset.assets = []
		_qset.rand = false
		_qset.name = ''
		_title = $scope.widget.title
		_okToSave = if _title? && _title != '' then true else false

		_puzzleItems = $scope.widget.puzzleItems

		# if the puzzle has changed, regenerate
		if not _hasFreshPuzzle
			_items = []

			for i in [0..._puzzleItems.length]
				_items.push _process _puzzleItems[i]
				words.push _puzzleItems[i].answer

			# generate the puzzle using the guessing algorithm in puzzle.coffee
			_items = Crossword.Puzzle.generatePuzzle _items, force
			if !_items
				return false

			_drawCurrentPuzzle _items

			_qset.items = [{ items: _items }]

			_hasFreshPuzzle = _okToSave

		for i in [0..._puzzleItems.length]
			for item in _qset.items[0].items
				if item.answers[0].text == _puzzleItems[i].answer
					item.questions[0].text = _puzzleItems[i].question
					item.options.hint = _puzzleItems[i].hint
					break

		$scope.unused = false
		for item in $scope.widget.puzzleItems
			continue if item.answer == ''
			found = false
			for qitem in _qset.items[0].items
				if item.answer == qitem.answers[0].text
					found = true

			item.found = found
			if not found
				$scope.unused = true
		$scope.error = $scope.unused or $scope.tooBig

		_okToSave

	_drawCurrentPuzzle = (items) ->
		$('#preview_kids').empty()

		_left = _top = 0

		for item in items
			letters = item.answers[0].text.split ''
			x = ~~item.options.x
			y = ~~item.options.y

			for i in [0...letters.length]
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

		$scope.$apply ->
			$scope.tooBig = _left > 17 or _top > 20
			$scope.error = $scope.tooBig or $scope.unused

	_process = (puzzleItem) ->
		questionObj =
			text: puzzleItem.question
		answerObj =
			text: puzzleItem.answer,
			value: '100',
			id: ''

		questions: [questionObj]
		answers: [answerObj]
		id: puzzleItem.id
		type: 'QA'
		assets: []
		options:
			hint: puzzleItem.hint
			x: 0
			y: 0

	### Scope Methods ###

	$scope.addPuzzleItem = (q='', a='', h='', id='') ->
		$scope.widget.puzzleItems.push
			question: q
			answer: a
			hint: h
			id: id
			found: true

	$scope.removePuzzleItem = (index) ->
		$scope.widget.puzzleItems.splice(index,1)
		$scope.noLongerFresh()
		$scope.generateNewPuzzle()

	$scope.introComplete = ->
		$scope.showIntroDialog = false

	$scope.closeDialog = ->
		$scope.showIntroDialog = $scope.showTitleDialog = $scope.showOptionsDialog = false

	$scope.showOptions = ->
		$scope.showOptionsDialog = true

	$scope.generateNewPuzzle = (force = false, reset = false) ->
		return if _hasFreshPuzzle and not force
		$('.loading').show()
		$scope.isBuilding = true

		setTimeout ->
			if reset
				Crossword.Puzzle.resetRandom()

			_hasFreshPuzzle = false
			_buildSaveData(reset)
			$('.loading').hide()
			$scope.stopTimer()

			$scope.$apply ->
				$scope.isBuilding = false
		,300

	$scope.noLongerFresh = ->
		_hasFreshPuzzle = false
		$scope.resetTimer()

	$scope.$watch('widget.hintPenalty', (newValue, oldValue) ->
		if newValue? and newValue.match and not newValue.match(/^[0-9]?[0-9]?$/)
			$scope.widget.hintPenalty = oldValue
	)

	$scope.$watch('widget.freeWords', (newValue, oldValue) ->
		if newValue? and newValue.match and not newValue.match(/^[0-9]?[0-9]?$/)
			$scope.widget.freeWords = oldValue
	)

	$scope.printPuzzle = ->
		$scope.generateNewPuzzle()
		if _qset?.items?.length?
			setTimeout ->
				Crossword.Print.printBoard({ name: $scope.widget.title }, _qset.items[0].items)
			,500

	# Timer for regenerating
	$scope.startTimer = ->
		$scope.stopTimer()
		$scope.timer = setInterval($scope.generateNewPuzzle, 1000)

	$scope.stopTimer = -> clearInterval($scope.timer)

	$scope.resetTimer = ->
		$scope.stopTimer()
		$scope.startTimer()


	Materia.CreatorCore.start materiaInterface