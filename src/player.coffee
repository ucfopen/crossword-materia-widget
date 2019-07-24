Namespace('Crossword').Engine = do ->
	# variables to store widget data in this scope
	_qset                 = null
	_questions            = null
	_usedHints            = []
	_usedFreeWords        = []
	_freeWordsRemaining   = 0
	_puzzleGrid           = {}
	_instance             = {}

	# two words can start at the same point and share a numberlabel
	# key is string of location, value is the number label to use/share at that location
	_wordMapping          = {}
	_labelIndexShift      = 0
	# stores all intersections, key is location, value is list where index is direction
	_wordIntersections    = {}

	# board drag state
	_boardMouseDown       = false
	_boardMoving          = false
	_mouseYAnchor         = 0
	_mouseXAnchor         = 0
	_puzzleY              = 0
	_puzzleX              = 0

	_puzzleHeightOverflow = 0
	_puzzleWidthOverflow  = 0
	_puzzleLetterHeight   = 0
	_puzzleLetterWidth    = 0

	_movableEase          = 0

	# the current typing direction
	_curDir               = -1
	# saved previous typing direction
	_prevDir              = 0
	# the current letter that is highlighted
	_curLetter            = false
	# the current clue that is selected
	_curClue              = 0

	# cache DOM elements for performance
	_domCache             = {}
	_boardDiv             = null # div containing the board

	# these are the allowed user input
	_allowedInput         = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','Á','À','Â','Ä','Ã','Å','Æ','Ç','É','È','Ê','Ë','Í','Ì','Î','Ï','Ñ','Ó','Ò','Ô','Ö','Õ','Ø','Œ','ß','Ú','Ù','Û','Ü']
	_allowedKeys          = null # generated below

	_isMobile             = false
	_zoomedIn             = false

	# constants
	LETTER_HEIGHT         = 23 # how many pixels high is a space?
	LETTER_WIDTH          = 27 # how many pixels wide is a space?
	VERTICAL              = 1 # used to compare dir == 1 or dir == VERTICAL
	BOARD_WIDTH           = 472 # visible board width
	BOARD_HEIGHT          = 485 # visible board height
	BOARD_LETTER_WIDTH    = Math.floor(BOARD_WIDTH / LETTER_WIDTH)
	BOARD_LETTER_HEIGHT   = Math.floor(BOARD_HEIGHT / LETTER_HEIGHT)
	NEXT_RECURSE_LIMIT    = 8 # number of characters in a row we'll try to jump forward before dying

	KEYBOARD_HELP = [
		'Use the Tab key to navigate between the clue list, submit, print, and zoom buttons.'
		'While the clue list is selected, use the Up and Down arrow keys to navigate between clues.'
		'While a clue is selected, Press the H key to receive a hint and reduce the value of a correct answer to that clue.'
		'While a clue is selected, Press the F key to use a free word and have that clue\'s letter tiles in the letter grid filled in automatically.'
		'While a clue is selected, Press the Return or Enter key to select the first letter tile for that clue in the letter grid.'
		'While the letter grid is selected, use the Up, Down, Left, and Right arrow keys inside the letter grid to navigate between letter tiles.'
		'While the letter grid is selected, press the Return or Enter key to automatically move to the first letter tile of the next clue.'
		'While the letter grid is selected, press the Tab key to return to the clue list.'
		'Press the Escape key to cancel or the Return or Enter key to confirm during prompts like this one.'
	]

	CLUE_HELP_TEXT        = 'Press the I key to receive additional instructions. '
	CLUE_BASE_TEXT        = 'Use the Up and Down arrow keys to navigate between clues. Press the Return or Enter key to select the first letter tile for this clue in the letter grid. Press the Tab key to move to the submit button. '
	CLUE_CHECK_TEXT       = 'Press the C key to check if all of this clue\'s letters have been filled in. '
	CLUE_HINT_TEXT        = 'Press the H key to receive a hint and reduce the value of a correct answer to this clue by '
	CLUE_FREE_WORD_TEXT   = 'Press the F key to use a free word and have this clue\'s letter tiles in the letter grid filled in automatically. '
	CLUE_REPEAT_TEXT      = 'Press the R key to repeat this clue. '

	BOARD_HELP_TEXT       = 'Hold the Control key and the Alt key and press the I key to receive additional instructions. '
	BOARD_CLUE_TEXT       = 'Hold the Control key and the Alt key and press the C key to hear the clue or clues this tile is included in. '
	BOARD_LETTERS_TEXT    = 'Hold the Control key and the Alt key and press the W key to hear the letters currently provided for the clue or clues this tile is included in. '
	BOARD_LOCATION_TEXT   = 'Hold the Control key and the Alt key and press the L key to describe the tiles adjacent to this tile. '
	BOARD_BASE_TEXT       = 'Press the Tab key to return to the clue list. Press the Return or Enter key to select the next clue and automatically move to the first letter tile for that clue. '

	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->
		# if we're on a mobile device, some event listening will be different
		_isMobile = navigator.userAgent.match /(iPhone|iPod|iPad|Android|BlackBerry)/
		if _isMobile
			document.ontouchmove = (e) ->
					e.preventDefault()

		# build allowed key list from allowed chars
		_allowedKeys = (char.charCodeAt(0) for char in _allowedInput)

		# store widget data
		_instance = instance
		_qset = qset

		CLUE_HINT_TEXT += qset.options.hintPenalty + '%. '

		# easy access to questions
		_questions = _qset.items[0].items
		_boardDiv = $('#movable')

		# clean qset variables
		forEveryQuestion (i, letters, x, y, dir) ->
			_questions[i].options.x = ~~_questions[i].options.x
			_questions[i].options.y = ~~_questions[i].options.y
			_questions[i].options.dir = ~~_questions[i].options.dir

		puzzleSize = _measureBoard(_questions)
		_scootWordsBy(puzzleSize.minX, puzzleSize.minY) # normalize the qset coordinates

		_puzzleLetterWidth  = puzzleSize.width
		_puzzleLetterHeight = puzzleSize.height
		_puzzleWidthOverflow = (_puzzleLetterWidth * LETTER_WIDTH) - BOARD_WIDTH
		_puzzleHeightOverflow = (_puzzleLetterHeight * LETTER_HEIGHT) - BOARD_HEIGHT

		_curLetter = { x: _questions[0].options.x, y:_questions[0].options.y }

		# render the widget, hook listeners, update UI
		_drawBoard instance.name
		_animateToShowBoardIfNeeded()
		_setupEventHandlers()
		_updateFreeWordsRemaining()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()
		_dom('widget-header').focus()

	# getElementById and cache it, for the sake of performance
	_dom = (id) -> _domCache[id] || (_domCache[id] = document.getElementById(id))

	# measurements are returned in letter coordinates
	# 5 is equal to 5 letters, not pixels
	_measureBoard = (qset) ->
		minX = minY = maxX = maxY = 0

		for word in qset
			# compare first letter coordinates
			# store minimum values
			option = word.options
			minX = option.x if option.x < minX
			minY = option.y if option.y < minY

			# find last letter coordinates
			if option.dir == VERTICAL
				wordMaxX = option.x + 1
				wordMaxY = option.y + word.answers[0].text.length
			else
				wordMaxX = option.x + word.answers[0].text.length
				wordMaxY = option.y + 1

			# store maximum values
			maxY = wordMaxY if wordMaxY > maxY
			maxX = wordMaxX if wordMaxX > maxX

		width  = maxX - minX
		height = maxY - minY

		{minX: minX, minY: minY, maxX: maxX, maxY: maxY, width:width, height:height}

	# shift word coordinates to normalize to 0, 0
	# TODO this currently never does anything since `qset` isn't a thing
	_scootWordsBy = (x, y) ->
		if x != 0 or y != 0
			for word in qset
				word.options.x = word.options.x - x
				word.options.y = word.options.y - y

	# set up listeners on UI elements
	_setupEventHandlers = ->
		# keep focus on the last letter that was highlighted whenever we move the board around
		$('#board').click -> _highlightPuzzleLetter false

		$('#board').keydown _boardKeyDownHandler
		$('#printbtn').click (e) ->
			Crossword.Print.printBoard(_instance, _questions)
		$('#printbtn').keyup (e) ->
			if e.keyCode is 13 then Crossword.Print.printBoard(_instance, _questions)
		$('#zoomout').click _zoomOut
		$('#zoomout').keyup (e) ->
			if e.keyCode is 13 then _zoomOut()
		$('#alertbox .button.cancel').click _hideAlert
		$('#checkBtn').click ->
			_showAlert "Are you sure you're done?", 'Yep, Submit', 'No, Cancel', _submitAnswers

		$('#alertbox').keydown (e) ->
			switch e.keyCode
				when 13 #enter
					$('#okbtn').click()
				when 27 #escape
					$('#cancelbtn').click()
				when 82 #r
					$('#alert-reader').html ''
					regex = new RegExp(/<br\/?>/, 'g')
					formattedKeyboardHelp = $('#alertcaption').html().replace(regex, ' ')
					formattedKeyboardHelp += ' Use the Escape key to cancel or the Return or Enter key to confirm. ' +
						'Press the R key to repeat.'
					$('#alert-reader').html formattedKeyboardHelp
					$('#alertbox').focus()

		$('#keyboard-instructions').keyup (e) ->
			if e.keyCode is 13 or e.keyCode is 32
				formattedKeyboardHelp = ''
				formattedKeyboardHelp += v + '<br/>' for i, v of KEYBOARD_HELP
				_showAlert formattedKeyboardHelp, 'Okay', null, _hideAlert

		$('#specialInputBody span').click ->
			spoof = $.Event('keydown')
			spoof.which = this.innerText.charCodeAt(0)
			spoof.keyCode = this.innerText.charCodeAt(0)
			currentLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
			$(currentLetter).trigger spoof
		$('#specialInputHead').click ->
			$('#specialInput').toggleClass 'down up'

		if _isMobile
			Hammer(document.getElementById('board')).on 'panstart', _mouseDownHandler
			Hammer(document.getElementById('board')).on 'panleft panright panup pandown', _mouseMoveHandler
			Hammer(document).on 'panend', _mouseUpHandler
		else
			document.getElementById('board').addEventListener 'mousedown', _mouseDownHandler
			document.getElementById('board').addEventListener 'mousemove', _mouseMoveHandler
			document.addEventListener 'mouseup', _mouseUpHandler

			$('#clues').keydown _clueKeyDownHandler
			$('#clues').focus _cluesFocused

	# start dragging
	_mouseDownHandler = (e) ->
		context = if _isMobile then e.pointers[0] else e

		return if context.clientX > 515 or not _zoomedIn

		_boardMouseDown = true
		_mouseYAnchor = context.clientY
		_mouseXAnchor = context.clientX

		_prevDir = _curDir unless _curDir is -1
		_curDir = -1

	# start dragging the board when the mousedown occurs
	# coordinates are relative to where we start
	_mouseMoveHandler = (e) ->
		return if not _boardMouseDown
		_boardMoving = true

		context = if _isMobile then e.pointers[0] else e

		_puzzleY += (context.clientY - _mouseYAnchor)
		_puzzleX += (context.clientX - _mouseXAnchor)

		# if its out of range, stop panning
		_limitBoardPosition()

		_mouseYAnchor = context.clientY
		_mouseXAnchor = context.clientX

		m = _dom('movable')
		m.style.top = _puzzleY + 'px'
		m.style.left = _puzzleX + 'px'

		return false if _isMobile

	# stop dragging
	_mouseUpHandler = (e) -> _boardMouseDown = false

	# limits board position to prevent going off into oblivion (down and right)
	_limitBoardPosition = ->
		_puzzleY = -_puzzleHeightOverflow if _puzzleY < -_puzzleHeightOverflow
		_puzzleY = 0 if _puzzleY > 0
		_puzzleX = - _puzzleWidthOverflow if _puzzleX < -_puzzleWidthOverflow
		_puzzleX = 0 if _puzzleX > 0

	# Draw the main board.
	_drawBoard = (title) ->
		# hide freewords label if the widget has none
		_freeWordsRemaining = _qset.options.freeWords
		$('.remaining').css('display','none') if _freeWordsRemaining < 1

		# ellipse the title if too long
		if title is undefined or null
			title = "Widget Title Goes Here"
		title = title.substring(0, 42) + '...' if title.length > 45
		$('#title').html title
		$('#title').css 'font-size', 25 - (title.length / 8) + 'px'

		# used to track the maximum dimensions of the puzzle
		_top = 0

		# generate elements for questions
		forEveryQuestion (i, letters, x, y, dir) ->
			questionText = _questions[i].questions[0].text
			locationList = {}

			location = "" + x + y
			questionNumber = ~~i + 1 - _labelIndexShift
			if not _wordMapping.hasOwnProperty(location)
				_wordMapping[location] = questionNumber
				_renderNumberLabel _wordMapping[location], x, y
			else
				intersection = [questionNumber, _wordMapping[location]]
				intersection.reverse() if _questions[i].options.dir
				_wordIntersections[location] = intersection
				_labelIndexShift += 1
			hintPrefix = _wordMapping[location] + (if dir then ' down' else ' across')

			_renderClue questionText, hintPrefix, i, dir

			_prevDir = dir if ~~i == 0

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#freewordbtn_'+i).css('display', 'none') if not _freeWordsRemaining
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword

			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				locationList['' + letterLeft + letterTop] =
					index: Object.keys(locationList).length
					x: letterLeft
					y: letterTop

				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					# keep track of overlaps and store in _wordIntersections
					intersectedElement = _dom("letter_#{letterLeft}_#{letterTop}")
					intersectedQuestion = ~~intersectedElement.getAttribute("data-q") + 1

					location = "" + letterLeft + letterTop
					intersection = [~~i + 1, intersectedQuestion]
					intersection.reverse() if _questions[i].options.dir
					_wordIntersections[location] = intersection

					return

				protectedSpace = _allowedInput.indexOf(letters[l].toUpperCase()) == -1

				# each letter is a div with coordinates as id
				letterElement = document.createElement if protectedSpace then 'div' else 'input'
				letterElement.id = "letter_#{letterLeft}_#{letterTop}"
				letterElement.classList.add 'letter'
				letterElement.setAttribute 'tabindex', '-1'
				letterElement.setAttribute 'readonly', true
				letterElement.setAttribute 'aria-describedby', 'board-reader'
				letterElement.setAttribute 'aria-hidden', true
				letterElement.setAttribute 'data-q', i
				letterElement.setAttribute 'data-dir', dir
				letterElement.onclick = _letterClicked

				letterElement.style.top = letterTop * LETTER_HEIGHT + 'px'
				letterElement.style.left = letterLeft * LETTER_WIDTH + 'px'

				# if it's not a guessable char, display the char
				if protectedSpace
					letterElement.setAttribute 'data-protected', '1'
					letterElement.innerHTML = letters[l]
						# Black block for spaces
					letterElement.style.backgroundColor = '#000' if letters[l] == ' '

				# init the puzzle grid for this row and letter
				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				_boardDiv.append letterElement

			_questions[i].locations = locationList

		# Select the first clue
		_clueMouseUp {target: $('#clue_0')[0]}

	# zoom animation if dimensions are off screen
	_animateToShowBoardIfNeeded = ->
		if _puzzleLetterWidth > BOARD_LETTER_WIDTH or _puzzleLetterHeight > BOARD_LETTER_HEIGHT
			_zoomOut()

			setTimeout ->
				_zoomIn()
			, 2500

		else # no zooming, just highlight first letter
			_letterClicked { target: _dom("letter_#{_curLetter.x}_#{_curLetter.y}") }

	_zoomOut = ->
		_letterClicked { target: _dom("letter_#{_curLetter.x}_#{_curLetter.y}") }, false

		puzzlePixelHeight = _puzzleLetterHeight * LETTER_HEIGHT
		puzzlePixelWidth  = _puzzleLetterWidth * LETTER_WIDTH

		# x = pixelHeight / visibleDivHeight
		# 5 = 2000 / 400
		heightScaleFactor = puzzlePixelHeight / BOARD_HEIGHT
		widthScaleFactor = puzzlePixelWidth / BOARD_WIDTH

		# find the biggest scale factor
		scaleFactor =  1 / Math.max(widthScaleFactor, heightScaleFactor)

		# translate values need to take scale into account
		translateX = -_puzzleX / scaleFactor
		translateY = -_puzzleY / scaleFactor

		trans = "scale(#{scaleFactor}) translate(#{translateX}px, #{translateY}px)"
		_boardDiv
			.css('-webkit-transform', trans)
			.css('-moz-transform', trans)
			.css('transform', trans)
		_zoomedIn = false

	_zoomIn = ->
		trans = ''
		_boardDiv.css('-webkit-transform', trans)
			.css('-moz-transform', trans)
			.css('transform', trans)
		_zoomedIn = true

	# remove letter focus class from the current letter
	_removePuzzleLetterHighlight = ->
		g = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		g.classList.remove('focus') if g?

	# apply highlight class
	_highlightPuzzleLetter = (animate = true) ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		_zoomIn() unless _zoomedIn

		if highlightedLetter
			highlightedLetter.classList.add 'focus'
			highlightedLetter.focus()

			# figure out if the _curLetter is on the screen
			letterX = _curLetter.x * LETTER_WIDTH
			letterY = _curLetter.y * LETTER_HEIGHT

			isOffBoardX = letterX > _puzzleX or letterX < _puzzleX + BOARD_WIDTH
			isOffBoardY = letterY > _puzzleY or letterY < _puzzleY + BOARD_HEIGHT

			m = _dom('movable')

			if not _boardMoving and (isOffBoardX or isOffBoardY)
				if isOffBoardX
					_puzzleX = -_curLetter.x * LETTER_WIDTH + 100

				if isOffBoardY
					_puzzleY = -_curLetter.y * LETTER_HEIGHT + 100

				if animate
					m.classList.add 'animateall'

				clearTimeout _movableEase

				_movableEase = setTimeout ->
					m.classList.remove 'animateall'

				, 1000

			_limitBoardPosition()
			_boardMoving = false

			m.style.top  = _puzzleY + 'px'
			m.style.left = _puzzleX + 'px'

	# update which clue is highlighted and scrolled to on the side list
	_updateClue = ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		if highlightedLetter
			clue = _dom('clue_'+highlightedLetter.getAttribute('data-q'))

			# if at an intersection, try to keep the same word selected
			location = "" + _curLetter.x + _curLetter.y
			if _wordIntersections.hasOwnProperty(location)
				index = _wordIntersections[location][~~(_prevDir == 1)] - 1
				clue = _dom('clue_'+index)
				_curClue = index

			# if it's already highlighted, do not try to scroll to it
			if clue.classList.contains 'highlight'
				return

			# remove the highlight from all others
			for j of _questions
				_dom('clue_'+j).classList.remove 'highlight'

			scrolly = clue.offsetTop
			clue.classList.add 'highlight'

			$('#clues').stop true
			$('#clues').animate scrollTop: scrolly, 150

	_nextLetter = (direction) ->
		if direction == VERTICAL
			_curLetter.y++
		else
			_curLetter.x++

	_prevLetter = (direction) ->
		if direction == VERTICAL
			_curLetter.y--
		else
			_curLetter.x--

	_clueKeyDownHandler = (keyEvent) ->
		preventDefault = true

		switch keyEvent.keyCode
			when 13 #enter
				_clueMouseUp {target: $('#clue_'+_curClue)[0]}
			when 38 #up
				_changeSelectedClue true
			when 40 #down
				_changeSelectedClue false
			when 67 #c
				_checkCurrentClueCompletion()
			when 70 #f
				unless _freeWordsRemaining is 0 or _usedFreeWords[_curClue]
					_getFreeword {target: $('#clue_'+_curClue)[0]}
					_updateClueReader()
			when 72 #h
				unless _questions[_curClue].options.hint is '' or _usedHints[_curClue]
					_hintConfirm {target: $('#hintbtn_'+_curClue)[0]}
					_updateClueReader()
			when 73 #i
				clue = _questions[_curClue]

				instructionText = ''

				unless clue.options.hint is '' or _usedHints[_curClue]
					instructionText += CLUE_HINT_TEXT + '. '
				unless _freeWordsRemaining is 0 or _usedFreeWords[_curClue]
					plural = if _freeWordsRemaining > 1 then 'words' else 'word'
					instructionText += ' ' + CLUE_FREE_WORD_TEXT + 'You have ' + _freeWordsRemaining + ' free ' + plural + ' remaining. '
				instructionText += ' ' + CLUE_CHECK_TEXT + CLUE_REPEAT_TEXT + CLUE_BASE_TEXT

				_dom('clue-reader').innerHTML = instructionText
			when 82 #r
				_dom('clue-reader').innerHTML = _fullClueText _curClue
			when 87 #w
				question = _questions[_curClue]
				enteredLettersText = 'Letters entered for ' + question.prefix + '. '
				enteredLettersText += _getLettersFilledInForClue question
				_dom('clue-reader').innerHTML = enteredLettersText
			else
				preventDefault = false
		if preventDefault then keyEvent.preventDefault()

	_cluesFocused = (e) ->
		e.preventDefault()
		_dom('clue-reader').innerHTML = ''
		_updateClueReader()

	_checkCurrentClueCompletion = ->
		question = _questions[_curClue]

		missing = null

		for index in Object.keys question.locations
			location = question.locations[index]
			missing = location.index + 1 if _dom("letter_#{location.x}_#{location.y}").value == ''

		completionText = ''

		if missing
			completionText = question.prefix + ' is missing a letter in position ' + missing + '.'
		else
			completionText = 'All letters have all been filled in for word ' + question.prefix + '.'

		_dom('clue-reader').innerHTML = completionText

	_changeSelectedClue = (up) ->
		target = {target: $('#clue_'+_curClue)[0]}
		_clueMouseOut target

		if up
			_curClue--
			if _curClue < 0 then _curClue = _questions.length - 1
		else
			_curClue++
			if _curClue >= _questions.length then _curClue = 0

		target = {target: $('#clue_'+_curClue)[0]}
		_clueMouseOver target
		_updateClueReader()

	_getLettersFilledInForClue = (question) ->
		enteredLettersText = ''
		for location, info of question.locations
			letter = _checkLetterInLocation info.x, info.y
			if letter
				enteredLettersText += ' ' + letter + '. '
			else
				enteredLettersText += 'Blank. '
		enteredLettersText

	_fullClueText = (clueId = false) ->
		clueId = _curClue unless clueId
		clue = _questions[clueId]

		clueText = 'Word ' + (clueId + 1) + ' of ' + _questions.length + '. '
		clueText += clue.prefix + '. '
		clueText += clue.answers[0].text.length + ' letters. '
		clueText += 'Clue is. ' + _ensurePeriod clue.questions[0].text

		if _usedHints[clueId]
			combinedClueText += 'Hint. ' + _ensurePeriod clue.options.hint

		clueText

	_getClueForCurrentLetter = ->
		letterElement = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		location = "" + _curLetter.x + _curLetter.y

		combinedClueText = ''

		#figure out where the current position is and whether it's part of multiple words or not
		if _wordIntersections[location]
			combinedClueText = 'Character is in two words. '

			qi1 = _wordIntersections[location][0] - 1
			qi2 = _wordIntersections[location][1] - 1
			c1 = _fullClueText qi1
			c2 = _fullClueText qi2
			combinedClueText += ' Word one. ' + c1 + '. '
			combinedClueText += ' Word two. ' + c2 + '. '
		else
			qi = letterElement.getAttribute 'data-q'
			combinedClueText = _fullClueText qi

		combinedClueText

	_getWordPositionForCurrentLetter = ->
		letterElement = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		location = "" + _curLetter.x + _curLetter.y

		#figure out where the current position is and whether it's part of multiple words or not
		if _wordIntersections[location]
			qi1 = _wordIntersections[location][0] - 1
			qi2 = _wordIntersections[location][1] - 1
			q1 = _questions[qi1]
			q2 = _questions[qi2]
			p1 = q1.locations[location].index + 1
			p2 = q2.locations[location].index + 1
			locationMessage = ' Intersection of '
			locationMessage += 'word ' + q1.prefix + '. Character ' + p1 + ' of ' + q1.answers[0].text.length
			locationMessage += ' and word ' + q2.prefix + '. Character ' + p2 + ' of ' + q2.answers[0].text.length + '. '
		else
			question = _questions[letterElement.getAttribute('data-q')]
			position = question.locations[location].index + 1
			locationMessage = question.prefix + '. '
			locationMessage += ' Character ' + position + ' of ' + question.answers[0].text.length + '. '

		currentLetter = letterElement.value
		currentLetter = 'Empty' if not currentLetter
		locationMessage += ' Current value. ' + currentLetter + '. '
		if letterElement.getAttribute('data-locked')?
			locationMessage += ' This tile is locked and the value will not be changed. '

		locationMessage

	_describeLocationForCurrentLetter = ->
		# describe the letter's location and current value
		combinedLocationText = 'Current location. ' + _getWordPositionForCurrentLetter()
		# also describe the letters in adjacent cells
		above = _checkLetterInLocation _curLetter.x, _curLetter.y - 1
		left  = _checkLetterInLocation _curLetter.x - 1, _curLetter.y
		right = _checkLetterInLocation _curLetter.x + 1, _curLetter.y
		below = _checkLetterInLocation _curLetter.x, _curLetter.y + 1

		if above then combinedLocationText += ' Character above. ' + above + '. '
		if left then combinedLocationText += ' Character left. ' + left + '. '
		if right then combinedLocationText += ' Character right. ' + right + '. '
		if below then combinedLocationText += ' Character below. ' + below + '. '

		combinedLocationText

	_describeLettersAlreadyEnteredForCurrentLetterWord = ->
		#first - get the word or words the current letter space is in
		letterElement = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		location = "" + _curLetter.x + _curLetter.y

		enteredLettersText = ''

		#figure out where the current position is and whether it's part of multiple words or not
		if _wordIntersections[location]
			qi1 = _wordIntersections[location][0] - 1
			qi2 = _wordIntersections[location][1] - 1
			q1 = _questions[qi1]
			q2 = _questions[qi2]
			enteredLettersText = 'Letters entered for ' + q1.prefix + '. '
			enteredLettersText += _getLettersFilledInForClue q1
			enteredLettersText += 'Letters entered for ' + q2.prefix + '. '
			enteredLettersText += _getLettersFilledInForClue q2
		else
			question = _questions[letterElement.getAttribute('data-q')]
			enteredLettersText = 'Letters entered for ' + question.prefix + '. '
			enteredLettersText += _getLettersFilledInForClue question

		enteredLettersText

	_checkLetterInLocation = (x, y) ->
		letterElement = _dom("letter_#{x}_#{y}")
		if letterElement?.value then letterElement.value else null

	_updateClueReader = ->
		$('#clues .highlight').removeClass 'highlight'
		clueElement = _dom('clue_'+_curClue)
		clueElement.classList.add 'highlight'

		combinedClueText = _fullClueText()

		combinedClueText += CLUE_HELP_TEXT

		_dom('clue-reader').innerHTML = combinedClueText

		$('#clues').stop true
		$('#clues').animate scrollTop: clueElement.offsetTop, 150

	_updateBoardReader = (lastKey = null) ->
		combinedMessage = ''
		#if we got here from a letter input, read out the last letter entered
		if lastKey
			switch lastKey
				when 'Enter', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'
					combinedMessage += ''
				when 'Backspace', 'Delete'
					combinedMessage += 'Last character deleted. '
				else
					combinedMessage += 'Last character. ' + lastKey.toUpperCase() + '. '

		combinedMessage += 'Current location. ' + _getWordPositionForCurrentLetter()

		combinedMessage += BOARD_HELP_TEXT

		_dom('board-reader').innerHTML = combinedMessage

	_ensurePeriod = (text) ->
		unless text[text.length - 1] == '.'
			return text + '. '
		text

	_boardKeyDownHandler = (keyEvent, iteration = 0) ->
		if keyEvent.ctrlKey and keyEvent.altKey
			event.preventDefault()
			switch keyEvent.keyCode
				when 67 #c
					_dom('board-reader').innerHTML = _getClueForCurrentLetter()
				when 73 #i
					_dom('board-reader').innerHTML = BOARD_CLUE_TEXT + BOARD_LETTERS_TEXT + BOARD_LOCATION_TEXT + BOARD_BASE_TEXT
				when 76 #l
					_dom('board-reader').innerHTML = _describeLocationForCurrentLetter()
				when 87 #w
					_dom('board-reader').innerHTML = _describeLettersAlreadyEnteredForCurrentLetterWord()
			return
		preventDefault = true

		_lastLetter = {}
		_lastLetter.x = _curLetter.x
		_lastLetter.y = _curLetter.y

		_removePuzzleLetterHighlight()
		letterElement = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		isProtected = letterElement.getAttribute('data-protected')?
		isLocked = letterElement.getAttribute('data-locked')?

		switch keyEvent.keyCode
			when 37 #left
				_prevDir = ~~letterElement.getAttribute('data-dir')
				_curLetter.x--
				_curDir = -1
				_updateClue()
			when 38 #up
				_prevDir = ~~letterElement.getAttribute('data-dir')
				_curLetter.y--
				_curDir = -1
				_updateClue()
			when 39 #right
				_prevDir = ~~letterElement.getAttribute('data-dir')
				_curLetter.x++
				_curDir = -1
				_updateClue()
			when 40 #down
				_prevDir = ~~letterElement.getAttribute('data-dir')
				_curLetter.y++
				_curDir = -1
				_updateClue()
			when 46 #delete
				letterElement.value = '' unless isProtected or isLocked
				_checkIfDone()
			when 16
				_highlightPuzzleLetter()
				return
			when 9
				keyEvent.preventDefault()
				$('#clues').focus()
				return
			when 13 #enter
				# go to the next clue, based on the clue that is currently selected
				highlightedClue = $(".clue.highlight")
				questionIndex = ~~highlightedClue.attr("data-i")

				nextQuestionIndex = (questionIndex + 1) % _questions.length
				nextQuestion = _questions[nextQuestionIndex]

				_curDir = nextQuestion.options.dir
				_prevDir = _curDir
				_curLetter.x = nextQuestion.options.x
				_curLetter.y = nextQuestion.options.y
				_updateClue()
				keyEvent.keyCode = 39 + _curDir
			when 8 #backspace
				# dont let the page back navigate
				keyEvent.preventDefault()

				if letterElement?
					# if the current direction is unknown
					if _curDir == -1
						# set to the one stored on the letter element from the qset
						_curDir = ~~letterElement.getAttribute('data-dir')

					# move selection back
					_prevLetter(_curDir)

					# clear value
					letterElement.value = '' unless isProtected or isLocked

				_checkIfDone()
			else #any letter
				if keyEvent && keyEvent.key
					letterTyped = keyEvent.key.toUpperCase()
				else
					letterTyped = String.fromCharCode(keyEvent.keyCode)
				# a letter was typed, move onto the next letter or override if this is the last letter
				if letterElement?
					if !_isGuessable(letterTyped)
						_highlightPuzzleLetter()
						return

					if _curDir == -1
						_curDir = ~~letterElement.getAttribute('data-dir')
					_nextLetter(_curDir)

					letterElement.value = letterTyped unless isProtected or isLocked

					# if the puzzle is filled out, highlight the submit button
					_checkIfDone()

		nextletterElement = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		# highlight the next letter, if it exists and is not a space
		if nextletterElement and nextletterElement.getAttribute('data-protected') != '1'
			_highlightPuzzleLetter()
		else
			# otherwise, if it does not exist, go to the next word
			if not nextletterElement?
				keyEvent.keyCode = 13 if keyEvent.keyCode >= 48
				_curLetter = _lastLetter
			# recursively guess the next letter?
			if iteration < NEXT_RECURSE_LIMIT
				# if recursion doesn't work, try to move on to the next clue
				if iteration == (NEXT_RECURSE_LIMIT - 2) and keyEvent.keyCode >= 48
					# simulates enter being pressed after a letter typed in last slot
					keyEvent.keyCode = 13
				_boardKeyDownHandler(keyEvent, (iteration || 0)+1)
				return
			else
				# highlight the last successful letter
				_highlightPuzzleLetter()

		# highlight the word
		if nextletterElement
			# make sure the correct word is highlighted at an intersection
			location = "" + _curLetter.x + _curLetter.y
			if _wordIntersections.hasOwnProperty(location)
				i = _wordIntersections[location][~~(_prevDir == 1)] - 1
				_highlightPuzzleWord(i)
				_curDir = _questions[i].options.dir
			else
				if _curDir == ~~nextletterElement.getAttribute('data-dir') or _curDir is -1
					_highlightPuzzleWord nextletterElement.getAttribute('data-q')

			_prevDir = _curDir unless _curDir == -1

		# to shut up screenreaders
		if preventDefault then keyEvent.preventDefault()

		_updateBoardReader keyEvent.key

		nextletterElement?.focus()

	# is a letter one that can be guessed?
	_isGuessable = (character) ->
		return _allowedInput.indexOf(character) != -1

	# update the UI elements pertaining to free words
	_updateFreeWordsRemaining = ->
		sentence = ' free word' + (if _freeWordsRemaining is 1 then '' else 's') + ' remaining'
		$('#freeWordsRemaining').html _freeWordsRemaining + sentence

		# hide buttons if no free words remain
		if _freeWordsRemaining < 1
			for i of _questions
				if _qset.options.freeWords < 1
					$('#freewordbtn_'+i).css 'display', 'none'
				else
					_dom('freewordbtn_'+i).classList.add 'disabled'

	# highlight the clicked letter and set up direction
	_letterClicked = (e, animate = true) ->
		e = window.event if not e?
		target = e.target or e.srcElement

		# event bubble, or clicked on a non-editable space
		return if not target or target.getAttribute('data-protected')?

		# parse out the coordinates from the element id
		s = target.id.split '_'

		_removePuzzleLetterHighlight()
		_curLetter = { x: ~~s[1], y:~~s[2] }
		location = "" + ~~s[1] + ~~s[2]

		# keep the prior direction if at an intersection
		if _wordIntersections.hasOwnProperty(location) and _prevDir != -1
			_curDir = _prevDir
			forEveryQuestion (i, letters, x, y, dir) ->
				if _curDir == dir
					forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
						if _curLetter.x == letterLeft and _curLetter.y == letterTop
							_highlightPuzzleWord(i)
		else
			_curDir = ~~_dom("letter_#{_curLetter.x}_#{_curLetter.y}").getAttribute('data-dir')
			_prevDir = _curDir
			_highlightPuzzleWord (target).getAttribute('data-q')

		_highlightPuzzleLetter(animate)

		_updateBoardReader()

		_updateClue()

	# confirm that the user really wants to risk a penalty
	_hintConfirm = (e) ->
		return if e.target.classList.contains 'disabled'
		# only do it if the parent clue is highlighted
		if _dom('clue_' + e.target.getAttribute('data-i')).classList.contains 'highlight'
			_showAlert "Receiving a hint will result in a #{_qset.options.hintPenalty}% penalty for this question.", 'Okay', 'Nevermind', ->
				_getHint e.target.getAttribute 'data-i'

	# fired by the free word buttons
	_getFreeword = (e) ->
		return if _freeWordsRemaining < 1

		# stop if parent clue is not highlighted
		return if not _dom('clue_' + e.target.getAttribute('data-i')).classList.contains 'highlight'

		# stop if button is disabled
		return if e.target.classList.contains 'disabled'

		# get question index from button attributes
		index = parseInt(e.target.getAttribute('data-i'))

		_usedFreeWords[index] = true

		# letter array to fill
		letters = _questions[index].answers[0].text.split('')
		x       = _questions[index].options.x
		y       = _questions[index].options.y
		dir     = _questions[index].options.dir
		answer  = ''

		# fill every letter element
		forEveryLetter x,y,dir,letters, (letterLeft, letterTop, l) ->
			letter = _dom("letter_#{letterLeft}_#{letterTop}")
			letter.classList.add 'locked'
			letter.setAttribute('data-locked', '1')
			letter.value = letters[l].toUpperCase()

		_freeWordsRemaining--

		_dom('freewordbtn_' + index).classList.add 'disabled'
		_dom('hintbtn_' + index).classList.add 'disabled'

		_updateFreeWordsRemaining()
		_checkIfDone()

	# highlight a word (series of letters)
	_highlightPuzzleWord = (index) ->
		# remove highlight from every letter
		$(".letter.highlight").removeClass("highlight")
		# and add it to the ones we care about
		forEveryQuestion (i, letters, x, y, dir) ->
			if ~~i == ~~index
				forEveryLetter x,y,dir,letters, (letterLeft, letterTop) ->
					l = _dom("letter_#{letterLeft}_#{letterTop}")
					if l?
						l.classList.add 'highlight'

	# show the modal alert dialog
	_showAlert = (caption, okayCaption, cancelCaption, action) ->
		ab = $('#alertbox')
		_dom('backgroundcover').classList.add 'show'

		_dom('cancelbtn').classList.add('removed')

		$('#alertcaption').html caption
		$('#okbtn').val okayCaption
		if cancelCaption
			_dom('cancelbtn').classList.remove('removed')
			$('#cancelbtn').val cancelCaption

		ab.find('.submit').unbind('click').click ->
			_hideAlert()
			action()
		ab.focus()

	# hide it
	_hideAlert = ->
		_dom('backgroundcover').classList.remove 'show'
		_dom('clues').focus()

	# called after confirm dialog
	_getHint = (index) ->
		_usedHints[index] = true
		Materia.Score.submitInteractionForScoring _questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty

		hintSpot = _dom("hintspot_#{index}")
		hintSpot.innerHTML = "Hint. #{_questions[index].options.hint}"
		hintSpot.style.opacity = 1

		hintButton = _dom("hintbtn_#{index}")
		hintButton.style.opacity = 0

		# move freeword button to where it should be
		setTimeout ->
			hintButton.style.left = '-52px'
			_dom("freewordbtn_#{index}").style.left = '-52px'
		,190

	# highlight submit button if all letters are filled in
	_checkIfDone = ->
		_dom('submit-progress-reader').innerHTML = ''
		done = true
		unfinishedWord = null

		forEveryQuestion (i, letters, x, y, dir) ->
			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				if letters[l] != ' '
					if _dom("letter_#{letterLeft}_#{letterTop}").value == ''
						unfinishedWord = _dom("letter_#{letterLeft}_#{letterTop}").getAttribute('data-q')
						done = false
						return

		if done
			$('.arrow_box').show()
			_dom('checkBtn').classList.add 'done'
			_dom('submit-progress-reader').innerHTML = 'All characters filled.'
		else
			question = _questions[unfinishedWord]
			missing = null
			for index in Object.keys question.locations
				location = question.locations[index]
				missing = location.index + 1 if _dom("letter_#{location.x}_#{location.y}").value == ''

			_dom('submit-progress-reader').innerHTML = question.prefix + ' is missing a letter in position ' + missing + '.'

			_dom('checkBtn').classList.remove 'done'
			$('.arrow_box').hide()

	# draw a number label to identify the question
	_renderNumberLabel = (questionNumber, x, y) ->
		numberLabel = document.createElement 'div'
		numberLabel.innerHTML = questionNumber
		numberLabel.classList.add 'numberlabel'
		numberLabel.setAttribute 'aria-hidden', true
		numberLabel.style.top = y * LETTER_HEIGHT + 'px'
		numberLabel.style.left = x * LETTER_WIDTH + 'px'
		numberLabel.onclick = -> _letterClicked target: $("#letter_#{x}_#{y}")[0]
		_boardDiv.append numberLabel

	# draw the clue from template html
	_renderClue = (question, hintPrefix, i, dir) ->
		clue = document.createElement 'div'
		clue.id = 'clue_' + i

		# store the '# across/down' information in the question for later use
		_questions[i].prefix = hintPrefix

		clue.innerHTML = $('#t_hints').html()
			.replace(/{{hintPrefix}}/g, hintPrefix)
			.replace(/{{question}}/g, question)
			.replace(/{{i}}/g, i)
			.replace(/{{dir}}/g, dir)

		clue.setAttribute 'data-i', i
		clue.setAttribute 'data-dir', dir
		clue.setAttribute 'aria-hidden', true
		clue.setAttribute 'role', 'listitem'
		clue.classList.add 'clue'

		clue.onmouseover = _clueMouseOver
		clue.onmouseout  = _clueMouseOut
		clue.onmouseup   = _clueMouseUp

		$('#clues').append clue

	_clueMouseUp = (e) ->
		e = window.event if not e?

		# click on the first letter of the word
		i = e.target.getAttribute('data-i')
		x = _questions[i].options.x
		y = _questions[i].options.y
		_prevDir = _questions[i].options.dir

		firstLetter = $("#letter_#{x}_#{y}")[0]
		# if the first letter of the word is protected, try to loop through the rest
		while firstLetter? and firstLetter.getAttribute('data-protected')?
			if _prevDir == VERTICAL
				y++
			else
				x++
			firstLetter = $("#letter_#{x}_#{y}")[0]

		_letterClicked { target: firstLetter }

	# highlight words when a clue is moused over, to correspond what the user is seeing
	_clueMouseOver = (e) ->
		e = window.event if not e?
		_highlightPuzzleWord (e.target or e.srcElement).getAttribute('data-i')

	_clueMouseOut = (e) ->
		_highlightPuzzleWord -1

	# submit every question to the scoring engine
	_submitAnswers = ->
		forEveryQuestion (i, letters, x, y, dir) ->
			answer = ''
			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				letterElement = _dom("letter_#{letterLeft}_#{letterTop}")
				isProtected = letterElement.getAttribute('data-protected')?

				if isProtected
					# get the letter from the qset
					answer += letters[l]
				else
					# get the letter from the input
					answer += letterElement.value || '_'

			Materia.Score.submitQuestionForScoring _questions[i].id, answer

		Materia.Engine.end()

	# loop iteration functions to prevent redundancy
	forEveryLetter = (x, y, dir, letters, cb) ->
		for l in [0...letters.length]
			if dir == VERTICAL
				letterLeft = x
				letterTop  = y + l
			else
				letterLeft = x + l
				letterTop  = y

			cb(letterLeft, letterTop, l)

	forEveryQuestion = (callBack) ->
		for i of _questions
			letters = _questions[i].answers[0].text.toUpperCase().split ''
			x       = _questions[i].options.x
			y       = _questions[i].options.y
			dir     = _questions[i].options.dir
			callBack(i, letters, x, y, dir)

	# return public stuff for Materia

	manualResize: true
	start: start
