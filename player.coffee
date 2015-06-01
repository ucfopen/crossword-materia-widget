Namespace('Crossword').Engine = do ->
	# variables to store widget data in this scope
	_qset               = null
	_questions          = null
	_freeWordsRemaining = 0
	_puzzleGrid         = {}
	_instance           = {}

	# board drag state
	_boardDown          = false
	_boardY             = 0
	_boardTop           = 0
	_boardX             = 0
	_boardLeft          = 0

	_boardHeight        = 0
	_boardWidth         = 0
	_boardYOverflow     = 0
	_boardXOverflow     = 0
	_boardLetterHeight  = 0
	_boardLetterWidth   = 0

	_movableEase        = 0

	# the current typing direction
	_curDir             = -1
	# the current letter that is highlighted
	_curLetter          = false

	# cache DOM elements for performance
	_domCache           = {}

	# these are the input
	_allowedInput       = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']
	_allowedKeys        = null

	# constants
	NEXT_RECURSE_LIMIT  = 8 # number of characters in a row we'll try to jump forward before dying
	LETTER_HEIGHT       = 23
	LETTER_WIDTH        = 27
	VERTICAL            = 1
	BOARD_WIDTH         = 400
	BOARD_HEIGHT        = 400


	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->

		# build allowed key list from allowed chars
		_allowedKeys = (char.charCodeAt(0) for char in _allowedInput)

		# store widget data
		_instance = instance
		_qset = qset

		# easy access to questions
		_questions = _qset.items[0].items

		# clean qset variables
		forEveryQuestion (i, letters, x, y, dir) ->
			_questions[i].options.x = ~~_questions[i].options.x
			_questions[i].options.y = ~~_questions[i].options.y
			_questions[i].options.dir = ~~_questions[i].options.dir

		pSize = _measureBoard(_questions)

		_boardLetterWidth = pSize.maxX - pSize.minX
		_boardLetterHeight = pSize.maxY - pSize.minY

		_scootWordsBy(pSize.minX, pSize.minY)

		# render the widget, hook listeners, update UI
		_drawBoard instance.name
		_animateToShowBoardIfNeeded()
		_setupClickHandlers()
		_updateFreeWordsRemaining()

		# focus the input listener
		$('#boardinput').focus()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()

	# getElementById and cache it, for the sake of performance
	_dom = (id) -> _domCache[id] || (_domCache[id] = document.getElementById(id))

	_measureBoard = (qset) ->
		minX = minY = maxX = maxY = 0

		for word in qset
			# compare first letter coordinates
			# store minimum values
			option = word.options
			minX = option.x if option.x < minX
			minY = option.y if option.y < minY

			# find last letter coordinates
			wordMaxX = wordMaxY = 0
			if option.dir == VERTICAL
				wordMaxY = option.y + word.answers[0].text.length
			else
				wordMaxX = option.x + word.answers[0].text.length

			# store maximum values
			maxY = wordMaxY if wordMaxY > maxY
			maxX = wordMaxX if wordMaxX > maxX

		{minX: minX, minY: minY, maxX: maxX, maxY: maxY}

	# shift word coordinates to normalize to 0, 0
	_scootWordsBy = (x, y) ->
		if x != 0 or y != 0
			for word in qset
				word.options.x = word.options.x - x
				word.options.y = word.options.y - y

	# set up listeners on UI elements
	_setupClickHandlers = ->
		# make sure the hidden input listener stays in focus
		$('#board').click ->
			$('#boardinput').focus()

		$('#boardinput').keydown _inputLetter
		$('#printbtn').click (e) ->
			Crossword.Print.printBoard(_instance, _questions)
		$('#alertbox .button.cancel').click _hideAlert
		$('#checkBtn').click ->
			_showAlert "Are you sure you're done?", 'Yep, Submit', 'No, Cancel', _submitAnswers

		# start dragging the board when the mousedown occurs
		# coordinates are relative to where we start
		document.addEventListener 'mousedown', (e) ->
			return if e.clientX > 515

			_boardDown = true
			_boardY = e.clientY
			_boardX = e.clientX

			_curDir = -1

		# stop dragging
		document.addEventListener 'mouseup', -> _boardDown = false

		document.addEventListener 'mousemove', (e) ->
			return if not _boardDown

			_boardTop += (e.clientY - _boardY)
			_boardLeft += (e.clientX - _boardX)

			# if its out of range, stop panning
			_limitBoardPosition()

			_boardY = e.clientY
			_boardX = e.clientX

			m = _dom('movable')
			m.style.top = _boardTop + 'px'
			m.style.left = _boardLeft + 'px'

	# limits board position to prevent going off into oblivion (down and right)
	_limitBoardPosition = ->
		_boardTop = -_boardHeight if _boardTop < -_boardHeight
		_boardTop = -_boardYOverflow if _boardTop > -_boardYOverflow
		_boardLeft = -_boardWidth if _boardLeft < -_boardWidth
		_boardLeft = -_boardXOverflow if _boardLeft > -_boardXOverflow

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
		_left    = 0
		_top     = 0
		_minLeft = Number.MAX_VALUE
		_minTop  = Number.MAX_VALUE

		# generate elements for questions
		forEveryQuestion (i, letters, x, y, dir) ->
			questionText = _questions[i].questions[0].text


			questionNumber = ~~i + 1
			hintPrefix = questionNumber + (if dir then ' down' else ' across')

			_renderNumberLabel questionNumber, x, y
			_renderClue questionText, hintPrefix, i, dir

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#freewordbtn_'+i).css('display', 'none') if not _freeWordsRemaining
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword
			boardDiv = $('#movable')

			forEveryLetter x, y, dir, letters, (letterLeft, letterTop, l) ->
				# overlapping connectors should not be duplicated
				return if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]

				# keep track of the largest dimension of the puzzle
				# for zooming
				_left    = letterLeft if letterLeft > _left
				_top     = letterTop if letterTop > _top
				_minLeft = letterLeft if letterLeft < _minLeft
				_minTop  = letterTop if letterTop < _minTop

				# each letter is a div with coordinates as id
				letterDiv = document.createElement 'div'
				letterDiv.id = "letter_#{letterLeft}_#{letterTop}"
				letterDiv.className = 'letter'
				letterDiv.setAttribute 'data-q', i
				letterDiv.setAttribute 'data-dir', dir
				letterDiv.onclick = _letterClicked

				letterDiv.style.top = 120 + letterTop * LETTER_HEIGHT + 'px'
				letterDiv.style.left = 10 + letterLeft * LETTER_WIDTH + 'px'

				# if it's not a guessable char, display the char
				if _allowedInput.indexOf(letters[l].toUpperCase()) == -1
					letterDiv.setAttribute 'data-protected', '1'
					letterDiv.innerHTML = letters[l]
						# Black block for spaces
					letterDiv.style.backgroundColor = '#000' if letters[l] == ' '

				# init the puzzle grid for this row and letter
				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				boardDiv.append letterDiv

		_boardWidth = _left * LETTER_WIDTH - BOARD_WIDTH
		_boardHeight = _top * LETTER_HEIGHT - BOARD_HEIGHT
		_boardXOverflow = _minLeft * LETTER_WIDTH
		_boardYOverflow = _minTop * LETTER_HEIGHT

	# zoom animation if dimensions are off screen
	_animateToShowBoardIfNeeded = ->
		console.log _boardLetterWidth, _boardLetterHeight
		if _boardLetterWidth > 18 or _boardLetterHeight > 20
			_letterClicked { target: _dom("letter_#{_curLetter.x}_#{_curLetter.y}") }, false

			valx = (515) / (Math.abs(_boardWidth) + Math.abs(_boardXOverflow) + 515)
			valy = (515) / (Math.abs(_boardHeight) + Math.abs(_boardYOverflow) + 515)

			val = if valx > valy then valy else valx

			translateX = (-_boardXOverflow - _boardLeft / val) / (valx / val)
			translateY = (-_boardYOverflow - _boardTop / val) / (valy / val)

			if valx > valy
				translateX += BOARD_WIDTH
			else
				translateY += BOARD_HEIGHT

			trans = 'scale(' + val + ') translate(' + translateX + 'px, ' + translateY + 'px)'
			$('#movable')
				.css('-webkit-transform', trans)
				.css('-moz-transform', trans)
				.css('transform', trans)
			setTimeout ->
				trans = ''
				$('#movable').css('-webkit-transform', trans)
					.css('-moz-transform', trans)
					.css('transform', trans)
			, 2500
		else
			# highlight first letter
			_letterClicked { target: _dom("letter_#{_curLetter.x}_#{_curLetter.y}") }

	# remove letter focus class from the current letter
	_removePuzzleLetterHighlight = ->
		g = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")
		g.className = g.className.replace(/focus/g,'') if g?

	# apply highlight class
	_highlightPuzzleLetter = (animate = true) ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		if highlightedLetter
			highlightedLetter.className += ' focus'

			# move the board input closer to the letter,
			# in the event the user has zoomed on a mobile device
			bi = _dom('boardinput')
			bi.style.top = highlightedLetter.style.top
			bi.style.left = highlightedLetter.style.left

			left = _curLetter.x * LETTER_WIDTH + _boardLeft
			top = _curLetter.y * LETTER_HEIGHT + _boardTop

			leftOut = left < 0 or left > 480
			topOut = top < 0 or top > 420

			m = _dom('movable')

			if leftOut or topOut
				if leftOut
					_boardLeft = -_curLetter.x * LETTER_WIDTH + 100
				if topOut
					_boardTop = -_curLetter.y * LETTER_HEIGHT + 100

				if animate
					m.className = 'animateall'
				clearTimeout _movableEase
				_movableEase = setTimeout ->
					m.className = m.className.replace /animateall/g, ''
				, 1000

			_limitBoardPosition()

			m.style.top = _boardTop + 'px'
			m.style.left = _boardLeft + 'px'

	# update which clue is highlighted and scrolled to on the side list
	_updateClue = ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		if highlightedLetter
			clue = _dom('clue_'+highlightedLetter.getAttribute('data-q'))

			# if it's already highlighted, do not try to scroll to it
			if clue.className.indexOf('highlight') != -1
				return

			# remove the highlight from all others
			for j of _questions
				_dom('clue_'+j).className = 'clue'

			scrolly = clue.offsetTop
			clue.className = 'clue highlight'

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

	# triggered by a keydown on the main input
	_inputLetter = (keyEvent, iteration = 0) ->
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
			else
				# all else, input the character and advance cursor position
				if letterDiv?
					if !_isGuessable(keyEvent)
						_highlightPuzzleLetter()
						return

					if _curDir == -1
						_curDir = ~~letterDiv.getAttribute('data-dir')

					_nextLetter(_curDir)

					if !isProtected
						letterDiv.innerHTML = String.fromCharCode(keyEvent.keyCode)

					# if the puzzle is filled out, highlight the submit button
					_checkIfDone()


		nextLetterDiv = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		# highlight the next letter, if it exists and is not a space
		if nextLetterDiv and nextLetterDiv.getAttribute('data-protected') != '1'
			_highlightPuzzleLetter()
		else
			# otherwise, if it does not exist, check if we can move in another direction
			if not nextLetterDiv?
				_curDir = if _curDir == VERTICAL then 0 else -1
				_curLetter = _lastLetter
			# recursively guess the next letter?
			if iteration < NEXT_RECURSE_LIMIT
				_inputLetter(keyEvent, (iteration || 0)+1)
			else
				# highlight the last successful letter
				_highlightPuzzleLetter()
		if nextLetterDiv and (_curDir == ~~nextLetterDiv.getAttribute('data-dir') or _curDir is -1)
			_highlightPuzzleWord nextLetterDiv.getAttribute('data-q')


	# is a letter one that can be guessed?
	_isGuessable = (keyEvent) ->
		return keyEvent? and _allowedKeys.indexOf(keyEvent.keyCode) != -1

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
					_dom('freewordbtn_'+i).className = 'button disabled'

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
		# only do it if the parent clue is highlighted
		if $('#clue_'+e.target.getAttribute('data-i')).hasClass('highlight')
			_showAlert "Receiving a hint will result in a #{_qset.options.hintPenalty}% penalty for this question", 'Okay', 'Nevermind', ->
				_getHint e.target.getAttribute 'data-i'

	# fired by the free word buttons
	_getFreeword = (e) ->
		return if _freeWordsRemaining < 1

		# stop if parent clue is not highlighted
		return if not $('#clue_'+e.target.getAttribute('data-i')).hasClass('highlight')

		# stop if button is hidden
		return if e.target.className is "button hidden"

		# get question index from button attributes
		index = parseInt(e.target.getAttribute('data-i'))

		# letter array to fill
		letters = _questions[index].answers[0].text.split('')
		x = ~~_questions[index].options.x
		y = ~~_questions[index].options.y
		dir = ~~_questions[index].options.dir

		answer = ''

		# fill every letter element
		forEveryLetter x,y,dir,letters, (letterLeft, letterTop, l) ->
			_dom("letter_#{letterLeft}_#{letterTop}").innerHTML = letters[l].toUpperCase()

		_freeWordsRemaining--

		_dom('freewordbtn_' + index).className = "button hidden"

		hb = _dom('hintbtn_' + index)
		hb.style.opacity = 0

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
						l.className = l.className.replace(/highlight/g, '')
		# and add it to the ones we care about
		forEveryQuestion (i, letters, x, y, dir) ->
			if i == index
				forEveryLetter x,y,dir,letters, (letterLeft, letterTop) ->
					l = _dom("letter_#{letterLeft}_#{letterTop}")
					if l?
						l.className += ' highlight'

	# show the modal alert dialog
	_showAlert = (caption, okayCaption, cancelCaption, action) ->
		ab = $('#alertbox')
		ab.addClass 'show'
		$('#backgroundcover').addClass 'show'

		$('#alertcaption').html caption
		$('#okbtn').val okayCaption
		$('#cancelbtn').val cancelCaption

		ab.find('.submit').unbind('click').click ->
			_hideAlert()
			action()

	# hide it
	_hideAlert = ->
		$('#alertbox').removeClass 'show'
		$('#backgroundcover').removeClass 'show'

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
			$('#checkBtn').addClass 'done'
		else
			$('#checkBtn').removeClass 'done'
			$('.arrow_box').hide()

	# draw a number label to identify the question
	_renderNumberLabel = (questionNumber, x, y) ->
		numberLabel = document.createElement 'div'
		numberLabel.innerHTML = questionNumber
		numberLabel.className = 'numberlabel'
		numberLabel.style.top = 129 + y * LETTER_HEIGHT + 'px'
		numberLabel.style.left = x * LETTER_WIDTH + 'px'
		numberLabel.onclick = ->
			_letterClicked target: $('#letter_' + x + '_' + y)[0]
		$('#movable').append numberLabel

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
		clue.className = 'clue'

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
			console.log _questions[i].id, answer

		debugger
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
