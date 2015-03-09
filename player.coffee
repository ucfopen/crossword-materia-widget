###

Materia
It's a thing

Widget	: Crossword
Authors	: Jonathan Warner
Updated	: 7/14

###

Namespace('Crossword').Engine = do ->
	# variables to store widget data in this scope
	_qset                   = null
	_questions				= null
	_freeWordsRemaining		= 0
	_puzzleGrid				= {}
	_instance				= {}

	# board drag state
	_boardDown				= false
	_boardY					= 0
	_boardTop				= 0
	_boardX					= 0
	_boardLeft				= 0

	_boardHeight			= 0
	_boardWidth				= 0
	_boardYOverflow			= 0
	_boardXOverflow			= 0

	_movableEase			= 0

	# the current typing direction
	_curDir					= -1
	# the current letter that is highlighted
	_curLetter				= false

	# cache DOM elements for performance
	_domCache				= {}

	# constants
	LETTER_HEIGHT			= 23
	LETTER_WIDTH			= 27


	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->
		_normalizeForPlayer qset.items[0].items

		# store widget data
		_instance = instance
		_qset = qset

		# easy access to questions
		_questions = _qset.items[0].items

		# render the widget, hook listeners, update UI
		_drawBoard instance.name
		_setupClickHandlers()
		_updateFreeWordsRemaining()

		# focus the input listener
		$('#boardinput').focus()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()
	
	# getElementById and cache it, for the sake of performance
	_dom = (id) -> _domCache[id] || (_domCache[id] = document.getElementById(id))

	_normalizeForPlayer = (qset) ->
		minX = 0
		minY = 0
		maxX = 0
		maxY = 0

		for i in [0...qset.length]
			qset[i].options.x = ~~qset[i].options.x
			qset[i].options.y = ~~qset[i].options.y

			minX = qset[i].options.x if qset[i].options.x < minX
			minY = qset[i].options.y if qset[i].options.y < minY

		for i in [0...qset.length]
			qset[i].options.x -= minX
			qset[i].options.y -= minY

		for i in [0...qset.length]
			maxX = qset[i].options.x if qset[i].options.x > maxX
			maxY = qset[i].options.y if qset[i].options.y > maxY

		xShift = Math.ceil((11 / 2 - maxX / 2))
		yShift = Math.ceil((11 / 2 - maxY / 2))

		for i in [0...qset.length]
			qset[i].options.x += xShift
			qset[i].options.y += yShift

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
		document.addEventListener 'mouseup', (e) -> _boardDown = false

		document.addEventListener 'mousemove', (e) ->
			return if not _boardDown

			_boardTop += (e.clientY - _boardY)
			_boardLeft += (e.clientX - _boardX)

			# if its out of range, stop panning
			_boundBoardPosition()

			_boardY = e.clientY
			_boardX = e.clientX

			m = _dom('movable')
			m.style.top = _boardTop + 'px'
			m.style.left = _boardLeft + 'px'
	
	_boundBoardPosition = ->
		_boardTop = -_boardHeight if _boardTop < -_boardHeight
		_boardTop = -_boardYOverflow if _boardTop > -_boardYOverflow
		_boardLeft = -_boardWidth if _boardLeft < -_boardWidth
		_boardLeft = -_boardXOverflow if _boardLeft > -_boardXOverflow

	# Draw the main board.
	_drawBoard = (title) ->
		# Disable right click
		# document.oncontextmenu = -> false
		# document.addEventListener 'mousedown', (e) ->
			# if e.button is 2 then false else true

		# hide freewords label if the widget has none
		_freeWordsRemaining = _qset.options.freeWords
		$('.remaining').css('display','none') if _freeWordsRemaining < 1

		# ellipse the title if too long
		title = title.substring(0,42) + '...' if title.length > 45
		$('#title').html title
		$('#title').css 'font-size', 25 - (title.length / 8) + 'px'

		# used to track the maximum dimensions of the puzzle
		_left = 0
		_top = 0
		_minLeft = Number.MAX_VALUE
		_minTop = Number.MAX_VALUE

		# generate elements for questions
		forEveryQuestion (i,letters,x,y,dir) ->
			question = _questions[i].questions[0].text

			if not _curLetter
				_curLetter = { x: x, y: y }

			questionNumber = parseInt(i) + 1
			hintPrefix = questionNumber + if dir then ' down' else ' across'

			_renderNumberLabel questionNumber, x, y
			_renderClue question, hintPrefix, i, dir

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#freewordbtn_'+i).css('display', 'none') if not _freeWordsRemaining
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword

			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					return
				
				# keep track of the largest dimension of the puzzle
				# for zooming
				_left = letterLeft if letterLeft > _left
				_top = letterTop if letterTop > _top
				_minLeft = letterLeft if letterLeft < _minLeft
				_minTop = letterTop if letterTop < _minTop
				
				# each letter is a div with coordinates as id
				letter = document.createElement 'div'
				letter.id = 'letter_' + letterLeft + '_' + letterTop
				letter.className = 'letter'
				letter.setAttribute 'data-q', i
				letter.setAttribute 'data-dir', dir
				letter.onclick = _letterClicked

				letter.style.top = 120 + letterTop * LETTER_HEIGHT + 'px'
				letter.style.left = 10 + letterLeft * LETTER_WIDTH + 'px'

				# if it's a space, make it a black block
				if letters[l] == ' '
					letter.style.backgroundColor = '#000'
					letter.setAttribute 'data-space', '1'

				# init the puzzle grid for this row and letter
				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				$('#movable').append letter

		SCREEN_WIDTH = 400
		SCREEN_HEIGHT = 400

		_boardWidth = _left * LETTER_WIDTH - SCREEN_WIDTH
		_boardHeight = _top * LETTER_HEIGHT - SCREEN_HEIGHT
		_boardXOverflow = _minLeft * LETTER_WIDTH
		_boardYOverflow = _minTop * LETTER_HEIGHT

		# zoom animation if dimensions are off screen
		if _left > 17 or _top > 20
			_letterClicked { target: _dom('letter_' + _curLetter.x + '_' + _curLetter.y) }, false

			valx = (515) / (Math.abs(_boardWidth) + Math.abs(_boardXOverflow) + 515)
			valy = (515) / (Math.abs(_boardHeight) + Math.abs(_boardYOverflow) + 515)

			val = if valx > valy then valy else valx

			translateX = (-_boardXOverflow - _boardLeft / val) / (valx / val)
			translateY = (-_boardYOverflow - _boardTop / val) / (valy / val)

			if valx > valy
				translateX += SCREEN_WIDTH
			else
				translateY += SCREEN_HEIGHT

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
			_letterClicked { target: _dom('letter_' + _curLetter.x + '_' + _curLetter.y) }

	# remove letter focus class from the current letter
	_removePuzzleLetterHighlight = ->
		g = _dom('letter_' + _curLetter.x + '_' + _curLetter.y)
		g.className = g.className.replace(/focus/g,'') if g?

	# apply highlight class
	_highlightPuzzleLetter = (animate = true) ->
		highlightedLetter = _dom('letter_' + _curLetter.x + '_' + _curLetter.y)

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

			_boundBoardPosition()

			m.style.top = _boardTop + 'px'
			m.style.left = _boardLeft + 'px'

			#_boardTop = -_boardYOverflow if _boardTop > -_boardYOverflow
			#_boardTop = -_boardHeight if _boardTop < -_boardHeight
			#_boardLeft = -_boardXOverflow if _boardLeft > -_boardXOverflow
			#_boardLeft = -_boardWidth if _boardLeft < -_boardWidth

	# update which clue is highlighted and scrolled to on the side list
	_updateClue = ->
		highlightedLetter = _dom('letter_' + _curLetter.x + '_' + _curLetter.y)

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

	# triggered by a keydown on the main input
	_inputLetter = (e,iteration) ->
		iteration = iteration || 0

		_lastLetter = {}

		# ensure that the coordinates are integers with '+'
		_lastLetter.x = +_curLetter.x
		_lastLetter.y = +_curLetter.y
		
		# unhighlight current letter
		_removePuzzleLetterHighlight()

		letter = _dom('letter_' + _curLetter.x + '_' + _curLetter.y)

		switch e.keyCode
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
			when 8 #backspace
				# dont make the page back navigate
				e.preventDefault()

				if letter?
					# if the current direction is unknown
					if _curDir == -1
						# set to the one stored on the letter element from the qset
						_curDir = letter.getAttribute('data-dir')

					# '1' is down, since the attributes are stored as strings
					if _curDir == '1'
						_curLetter.y--
					else
						_curLetter.x--
					letter.innerHTML = ''
				_checkIfDone()
			else
				# all else, input the character and advance cursor position
				if letter?
					isValid = (e.keyCode > 47 && e.keyCode < 58)		|| # number keys
								(e.keyCode == 32 || e.keyCode == 13)	|| # spacebar and enter	
								(e.keyCode > 64 && e.keyCode < 91)		# alphabet keys
					if isValid
						if _curDir == -1
							_curDir = letter.getAttribute('data-dir')
						if _curDir == '1'
							_curLetter.y++
						else
							_curLetter.x++

						letter.innerHTML = String.fromCharCode(e.keyCode)

					# if the puzzle is filled out, highlight the submit button
					_checkIfDone()

		next = _dom('letter_' + _curLetter.x + '_' + _curLetter.y)

		# highlight the next letter, if it exists and is not a space
		if next and next.getAttribute('data-space') != '1'
			_highlightPuzzleLetter()
		else
			# otherwise, if it does not exist, check if we can move in another direction
			if not next?
				_curDir = if _curDir == '1' then 0 else -1
				_curLetter = _lastLetter
			# recursively guess
			if iteration < 5
				_inputLetter e, (iteration || 0)+1
			else
				# highlight the last successful letter
				_highlightPuzzleLetter()
		if next and (_curDir is next.getAttribute('data-dir') or _curDir is -1)
			_highlightPuzzleWord next.getAttribute('data-q')
		
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
		_curLetter = { x: parseInt(s[1]), y: parseInt(s[2]) }

		_curDir = _dom('letter_' + _curLetter.x + '_' + _curLetter.y).getAttribute('data-dir')

		_highlightPuzzleLetter(animate)
		_highlightPuzzleWord (e.target or e.srcElement).getAttribute('data-q')

		_updateClue()

	# confirm that the user really wants to risk a penalty
	_hintConfirm = (e) ->
		# only do it if the parent clue is highlighted
		if $('#clue_'+e.target.getAttribute('data-i')).hasClass('highlight')
			_showAlert 'Receiving a hint will result in a ' + _qset.options.hintPenalty + '% penalty for this question', 'Okay', 'Nevermind', ->
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
		forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
			_dom('letter_' + letterLeft + '_' + letterTop).innerHTML = letters[l].toUpperCase()

		_freeWordsRemaining--

		_dom('freewordbtn_' + index).className = "button hidden"

		hb = _dom('hintbtn_' + index)
		hb.style.opacity = 0

		_updateFreeWordsRemaining()
		_checkIfDone()

	# highlight a word (series of letters)
	_highlightPuzzleWord = (index) ->
		# remove highlight from every letter
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop) ->
				if i != index
					l = _dom('letter_' + letterLeft + '_' + letterTop)
					if l?
						l.className = l.className.replace(/highlight/g, '')
		# and add it to the ones we care about
		forEveryQuestion (i,letters,x,y,dir) ->
			if i == index
				forEveryLetter x,y,dir,letters, (letterLeft,letterTop) ->
					l = _dom('letter_' + letterLeft + '_' + letterTop)
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

		hs = _dom('hintspot_' + index)
		hs.innerHTML = 'Hint: ' + _questions[index].options.hint
		hs.style.opacity = 1

		hb = _dom('hintbtn_' + index)
		hb.style.opacity = 0

		# move freeword button to where it should be
		setTimeout ->
			hb.style.left = '-52px'
			_dom('freewordbtn_' + index).style.left = '-52px'
		,190

	# highlight submit button if all letters are filled in
	_checkIfDone = ->
		done = true

		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				if letters[l] != ' '
					if _dom('letter_' + letterLeft + '_' + letterTop).innerHTML == ''
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
		clue.onmouseout = _clueMouseOut
		clue.onmouseup = _clueMouseUp

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
		forEveryQuestion (i,letters,x,y,dir) ->
			answer = ''
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				# make a word from the letters, 
				# as a whole word gets compared by the scoring module
				if letters[l] != ' '
					answer += _dom('letter_' + letterLeft + '_' + letterTop).innerHTML || '_'
				else
					answer += ' '

			Materia.Score.submitQuestionForScoring _questions[i].id, answer

		Materia.Engine.end()

	# loop iteration functions to prevent redundancy
	forEveryLetter = (x,y,dir,letters,cb) ->
		for l in [0...letters.length]
			if dir == 0
				letterLeft = x + l
				letterTop = y
			else
				letterLeft = x
				letterTop = y + l
			cb(letterLeft,letterTop,l)

	forEveryQuestion = (cb) ->
		for i of _questions
			letters = _questions[i].answers[0].text.toUpperCase().split ''
			x = ~~_questions[i].options.x
			y = ~~_questions[i].options.y
			dir = ~~_questions[i].options.dir
			cb i, letters, x, y, dir

	#public
	manualResize: true
	start: start
