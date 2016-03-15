Namespace('Crossword').Engine = do ->
	# variables to store widget data in this scope
	_qset                 = null
	_questions            = null
	_freeWordsRemaining   = 0
	_puzzleGrid           = {}
	_instance             = {}

	# board drag state
	_boardMouseDown       = false
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
	# the current letter that is highlighted
	_curLetter            = false

	# cache DOM elements for performance
	_domCache             = {}
	_boardDiv             = null # div containing the board

	# these are the allowed user input
	_allowedInput         = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','Á','À','Â','Ä','Ã','Å','Æ','Ç','É','È','Ê','Ë','Í','Ì','Î','Ï','Ñ','Ó','Ò','Ô','Ö','Õ','Ø','Œ','ß','Ú','Ù','Û','Ü']
	_allowedKeys          = null # generated below

	# constants
	LETTER_HEIGHT         = 23 # how many pixles high is a space?
	LETTER_WIDTH          = 27 # how many pixles wide is a space?
	VERTICAL              = 1 # used to compare dir == 1 or dir == VERTICAL
	BOARD_WIDTH           = 494 # visible board width
	BOARD_HEIGHT          = 494 # visible board height
	BOARD_LETTER_WIDTH    = Math.floor(BOARD_WIDTH / LETTER_WIDTH)
	BOARD_LETTER_HEIGHT   = Math.floor(BOARD_HEIGHT / LETTER_HEIGHT)
	NEXT_RECURSE_LIMIT    = 8 # number of characters in a row we'll try to jump forward before dying

	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->

		# build allowed key list from allowed chars
		_allowedKeys = (char.charCodeAt(0) for char in _allowedInput)

		# store widget data
		_instance = instance
		_qset = qset

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

		# focus the input listener
		$('#boardinput').focus()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()

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
	_scootWordsBy = (x, y) ->
		if x != 0 or y != 0
			for word in qset
				word.options.x = word.options.x - x
				word.options.y = word.options.y - y

	# set up listeners on UI elements
	_setupEventHandlers = ->
		# make sure the hidden input listener stays in focus
		$('#board').click ->
			$('#boardinput').focus()

		$('#boardinput').keyup _keyupHandler
		$('#printbtn').click (e) ->
			Crossword.Print.printBoard(_instance, _questions)
		$('#alertbox .button.cancel').click _hideAlert
		$('#checkBtn').click ->
			_showAlert "Are you sure you're done?", 'Yep, Submit', 'No, Cancel', _submitAnswers

		$('#boardinput').on 'input', _inputHandler

		# start dragging the board when the mousedown occurs
		# coordinates are relative to where we start
		document.addEventListener 'mousedown', (e) ->
			return if e.clientX > 515

			_boardMouseDown = true
			_mouseYAnchor = e.clientY
			_mouseXAnchor = e.clientX

			_curDir = -1

		# stop dragging
		document.addEventListener 'mouseup', -> _boardMouseDown = false

		document.addEventListener 'mousemove', (e) ->
			return if not _boardMouseDown

			_puzzleY += (e.clientY - _mouseYAnchor)
			_puzzleX += (e.clientX - _mouseXAnchor)

			# if its out of range, stop panning
			_limitBoardPosition()

			_mouseYAnchor = e.clientY
			_mouseXAnchor = e.clientX

			m = _dom('movable')
			m.style.top = _puzzleY + 'px'
			m.style.left = _puzzleX + 'px'

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
		title = title.substring(0, 42) + '...' if title.length > 45
		$('#title').html title
		$('#title').css 'font-size', 25 - (title.length / 8) + 'px'

		# used to track the maximum dimensions of the puzzle
		_top     = 0

		# generate elements for questions
		forEveryQuestion (i, letters, x, y, dir) ->
			questionText   = _questions[i].questions[0].text
			questionNumber = ~~i + 1
			hintPrefix     = questionNumber + (if dir then ' down' else ' across')

			_renderNumberLabel questionNumber, x, y
			_renderClue questionText, hintPrefix, i, dir

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#freewordbtn_'+i).css('display', 'none') if not _freeWordsRemaining
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword

			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				# overlapping connectors should not be duplicated
				return if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]

				# each letter is a div with coordinates as id
				letterDiv = document.createElement 'div'
				letterDiv.id = "letter_#{letterLeft}_#{letterTop}"
				letterDiv.classList.add 'letter'
				letterDiv.setAttribute 'data-q', i
				letterDiv.setAttribute 'data-dir', dir
				letterDiv.onclick = _letterClicked

				letterDiv.style.top = letterTop * LETTER_HEIGHT + 'px'
				letterDiv.style.left = letterLeft * LETTER_WIDTH + 'px'

				# if it's not a guessable char, display the char
				if _allowedInput.indexOf(letters[l].toUpperCase()) == -1
					letterDiv.setAttribute 'data-protected', '1'
					letterDiv.innerHTML = letters[l]
						# Black block for spaces
					letterDiv.style.backgroundColor = '#000' if letters[l] == ' '

				# init the puzzle grid for this row and letter
				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]
				_boardDiv.append letterDiv


	# zoom animation if dimensions are off screen
	_animateToShowBoardIfNeeded = ->
		# zoom out?
		if _puzzleLetterWidth > BOARD_LETTER_WIDTH or _puzzleLetterHeight > BOARD_LETTER_HEIGHT
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

			setTimeout ->
				trans = ''
				_boardDiv.css('-webkit-transform', trans)
					.css('-moz-transform', trans)
					.css('transform', trans)
			, 2500

		else # no zooming, just highlight first letter
			_letterClicked { target: _dom("letter_#{_curLetter.x}_#{_curLetter.y}") }

	# remove letter focus class from the current letter
	_removePuzzleLetterHighlight = ->
		g = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		g.classList.remove('focus') if g?

	# apply highlight class
	_highlightPuzzleLetter = (animate = true) ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		if highlightedLetter
			highlightedLetter.classList.add 'focus'

			# move the board input closer to the letter,
			# in the event the user has zoomed on a mobile device
			bi = _dom('boardinput')
			bi.style.top = highlightedLetter.style.top
			bi.style.left = highlightedLetter.style.left

			# figure out if the _curLetter is on the screen
			letterX = _curLetter.x * LETTER_WIDTH
			letterY = _curLetter.y * LETTER_HEIGHT

			isOffBoardX = letterX < _puzzleX or letterX > _puzzleX + BOARD_WIDTH
			isOffBoardY = letterY < _puzzleY or letterY > _puzzleY + BOARD_HEIGHT

			m = _dom('movable')

			if isOffBoardX or isOffBoardY
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

			m.style.top  = _puzzleY + 'px'
			m.style.left = _puzzleX + 'px'

	# update which clue is highlighted and scrolled to on the side list
	_updateClue = ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		if highlightedLetter
			clue = _dom('clue_'+highlightedLetter.getAttribute('data-q'))

			# if it's already highlighted, do not try to scroll to it
			if clue.classList.contains 'highlight'
				return

			# remove the highlight from all others
			for j of _questions
				_dom('clue_'+j).classList.remove 'highlight'

			scrolly = clue.offsetTop
			clue.classList.add 'highlight'

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

	_moveToNextLetter = (_lastLetter) ->
		nextLetterDiv = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		# highlight the next letter, if it exists and is not a space
		if nextLetterDiv and nextLetterDiv.getAttribute('data-protected') != '1'
			_highlightPuzzleLetter()
		else
			# otherwise, if it does not exist, check if we can move in another direction
			if not nextLetterDiv?
				_curDir = if _curDir == VERTICAL then 0 else -1
				_curLetter = _lastLetter

				_highlightPuzzleLetter()
		if nextLetterDiv and (_curDir == ~~nextLetterDiv.getAttribute('data-dir') or _curDir is -1)
			_highlightPuzzleWord nextLetterDiv.getAttribute('data-q')

	_keyupHandler = (keyEvent, iteration = 0) ->
		_lastLetter = {}

		_lastLetter.x = _curLetter.x
		_lastLetter.y = _curLetter.y

		_removePuzzleLetterHighlight()

		letterDiv = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		isProtected = letterDiv.getAttribute('data-protected')?

		switch keyEvent.keyCode
			when 37 #left
				_curLetter.x--
				_curDir = -1
				_updateClue()
			when 38 #up
				_curLetter.y--
				_curDir = -1
				_updateClue()
			when 39 #right
				_curLetter.x++
				_curDir = -1
				_updateClue()
			when 40 #down
				_curDir = -1
				_curLetter.y++
				_updateClue()
			when 46 #delete
				letterDiv.innerHTML = '' if !isProtected
			when 16
				_highlightPuzzleLetter()
				return
			when 8 #backspace
				# dont let the page back navigate
				keyEvent.preventDefault()

				if letterDiv?
					# if the current direction is unknown
					if _curDir == -1
						# set to the one stored on the letter element from the qset
						_curDir = ~~letterDiv.getAttribute('data-dir')

					# move selection back
					_prevLetter(_curDir)

					# Clear value
					letterDiv.innerHTML = '' if !isProtected

				_checkIfDone()

		_moveToNextLetter _lastLetter

	# triggered by a keydown on the main input
	_inputHandler = (inputEvent) ->
		_lastLetter = {}

		_lastLetter.x = _curLetter.x
		_lastLetter.y = _curLetter.y

		_removePuzzleLetterHighlight()

		letterDiv = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		isProtected = letterDiv.getAttribute('data-protected')?

		newCharacter = $('#boardinput').val().slice(-1).toUpperCase()

		# all else, input the character and advance cursor position
		if letterDiv?
			if !_isGuessable(newCharacter)
				_highlightPuzzleLetter()
				return

			if _curDir == -1
				_curDir = ~~letterDiv.getAttribute('data-dir')

			_nextLetter(_curDir)

			if !isProtected
				# letterDiv.innerHTML = String.fromCharCode(keyEvent.keyCode)
				letterDiv.innerHTML = newCharacter

			# if the puzzle is filled out, highlight the submit button
			_checkIfDone()

		$('#boardinput').val ''

		_moveToNextLetter _lastLetter

	# is a letter one that can be guessed?
	# _isGuessable = (keyEvent) ->
	# 	return keyEvent? and _allowedKeys.indexOf(keyEvent.keyCode) != -1
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

		# just a bubble
		return if not target

		# parse out the coordinates from the element id
		s = target.id.split '_'

		_removePuzzleLetterHighlight()
		_curLetter = { x: ~~s[1], y:~~s[2] }

		_curDir = ~~_dom("letter_#{_curLetter.x}_#{_curLetter.y}").getAttribute('data-dir')

		_highlightPuzzleLetter(animate)
		_highlightPuzzleWord (e.target or e.srcElement).getAttribute('data-q')

		_updateClue()

	# confirm that the user really wants to risk a penalty
	_hintConfirm = (e) ->
		return if e.target.classList.contains 'disabled'
		# only do it if the parent clue is highlighted
		if _dom('clue_' + e.target.getAttribute('data-i')).classList.contains 'highlight'
			_showAlert "Receiving a hint will result in a #{_qset.options.hintPenalty}% penalty for this question", 'Okay', 'Nevermind', ->
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

		# letter array to fill
		letters = _questions[index].answers[0].text.split('')
		x       = _questions[index].options.x
		y       = _questions[index].options.y
		dir     = _questions[index].options.dir
		answer  = ''

		# fill every letter element
		forEveryLetter x,y,dir,letters, (letterLeft, letterTop, l) ->
			_dom("letter_#{letterLeft}_#{letterTop}").innerHTML = letters[l].toUpperCase()

		_freeWordsRemaining--

		_dom('freewordbtn_' + index).classList.add 'disabled'
		_dom('hintbtn_' + index).classList.add 'disabled'

		_updateFreeWordsRemaining()
		_checkIfDone()

	# highlight a word (series of letters)
	_highlightPuzzleWord = (index) ->
		# remove highlight from every letter
		forEveryQuestion (i, letters, x, y, dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft, letterTop) ->
				if i != index
					l = _dom("letter_#{letterLeft}_#{letterTop}")
					if l?
						l.classList.remove 'highlight'
		# and add it to the ones we care about
		forEveryQuestion (i, letters, x, y, dir) ->
			if i == index
				forEveryLetter x,y,dir,letters, (letterLeft, letterTop) ->
					l = _dom("letter_#{letterLeft}_#{letterTop}")
					if l?
						l.classList.add 'highlight'

	# show the modal alert dialog
	_showAlert = (caption, okayCaption, cancelCaption, action) ->
		ab = $('#alertbox')
		ab.addClass 'show'
		_dom('backgroundcover').classList.add 'show'

		$('#alertcaption').html caption
		$('#okbtn').val okayCaption
		$('#cancelbtn').val cancelCaption

		ab.find('.submit').unbind('click').click ->
			_hideAlert()
			action()

	# hide it
	_hideAlert = ->
		_dom('alertbox').classList.remove 'show'
		_dom('backgroundcover').classList.remove 'show'

	# called after confirm dialog
	_getHint = (index) ->
		Materia.Score.submitInteractionForScoring _questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty

		hintSpot = _dom("hintspot_#{index}")
		hintSpot.innerHTML = "Hint: #{_questions[index].options.hint}"
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
		done = true

		forEveryQuestion (i, letters, x, y, dir) ->
			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				if letters[l] != ' '
					if _dom("letter_#{letterLeft}_#{letterTop}").innerHTML == ''
						done = false
						return
		if done
			$('.arrow_box').show()
			_dom('checkBtn').classList.add 'done'
		else
			_dom('checkBtn').classList.remove 'done'
			$('.arrow_box').hide()

	# draw a number label to identify the question
	_renderNumberLabel = (questionNumber, x, y) ->
		numberLabel = document.createElement 'div'
		numberLabel.innerHTML = questionNumber
		numberLabel.classList.add 'numberlabel'
		numberLabel.style.top = y * LETTER_HEIGHT + 'px'
		numberLabel.style.left = x * LETTER_WIDTH + 'px'
		numberLabel.onclick = -> _letterClicked target: $("#letter_#{x}_#{y}")[0]
		_boardDiv.append numberLabel

	# draw the clue from template html
	_renderClue = (question, hintPrefix, i, dir) ->
		clue = document.createElement 'div'
		clue.id = 'clue_' + i

		clue.innerHTML = $('#t_hints').html()
			.replace(/{{hintPrefix}}/g, hintPrefix)
			.replace(/{{question}}/g, question)
			.replace(/{{i}}/g, i)
			.replace(/{{dir}}/g, dir)

		clue.setAttribute 'data-i', i
		clue.setAttribute 'data-dir', dir
		clue.classList.add 'clue'

		clue.onmouseover = _clueMouseOver
		clue.onmouseout  = _clueMouseOut
		clue.onmouseup   = _clueMouseUp

		$('#clues').append clue

	_clueMouseUp = (e) ->
		e = window.event if not e?

		# click on the first letter of the word
		i = e.target.getAttribute('data-i')
		dir = e.target.getAttribute('data-dir')

		_letterClicked { target: $('.letter[data-q="'+i+'"][data-dir="'+dir+'"]').first().get()[0] }

	# highlight words when a clue is moused over, to correspond what the user is seeing
	_clueMouseOver = (e) ->
		e = window.event if not e?
		_highlightPuzzleWord (e.target or e.srcElement).getAttribute('data-i')

	_clueMouseOut = (e) ->
		_highlightPuzzleWord false

	# submit every question to the scoring engine
	_submitAnswers = ->

		forEveryQuestion (i, letters, x, y, dir) ->
			answer = ''
			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				letterDiv = _dom("letter_#{letterLeft}_#{letterTop}")
				isProtected = letterDiv.getAttribute('data-protected')?

				if isProtected
					# get the letter from the qset
					answer += letters[l]
				else
					# get the letter from the input
					answer += letterDiv.innerHTML || '_'

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
