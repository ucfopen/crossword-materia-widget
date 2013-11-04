###

Materia
It's a thing

Widget	: Crossword
Authors	: Jonathan Warner
Updated	: 11/13

###

Namespace('Crossword').Engine = do ->
	_qset                   = null
	_questions				= null
	_freeWordsRemaining		= 0
	_puzzleGrid				= {}
	_instance				= {}

	_boardDown				= false
	_boardY					= 0
	_boardTop				= 0
	_boardX					= 0
	_boardLeft				= 0

	_curDir					= -1
	_curLetter				= false

	_domCache				= {}

	LETTER_HEIGHT			= 23
	LETTER_WIDTH			= 27


	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->
		_qset = qset
		_questions = _qset.items[0].items
		_instance = instance

		_drawBoard instance.name

		_captionUpdate()
		_setupClickHandlers()

		_letterClicked { target: _g('letter_' + _curLetter.x + '_' + _curLetter.y) }

		$('#boardinput').focus()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()
	
	# getElementById and cache it, for the sake of performance
	_g = (id) -> _domCache[id] || (_domCache[id] = document.getElementById(id))

	_setupClickHandlers = ->
		$('#board').click ->
			$('#boardinput').focus()
		$('#boardinput').keydown _inputLetter
		$('#printbtn').click _printBoard
		$('#cancelbtn').click _hideAlert
		$('#checkBtn').click ->
			_showAlert "Are you sure you're done?<br>This is your last chance!", _submitAnswers

		$('#board').mousedown (e) ->
			_boardDown = true
			_boardY = e.screenY
			_boardX = e.screenX

			_curDir = -1

		$('#board').mouseup (e) ->
			_boardDown = false

		$('#board').mousemove (e) ->
			if _boardDown
				_boardTop += (e.screenY - _boardY)
				_boardLeft += (e.screenX - _boardX)

				# if its out of range, stop panning
				_boardTop = -600 if _boardTop < -600
				_boardTop = 600 if _boardTop > 600
				_boardLeft = -600 if _boardLeft < -600
				_boardLeft = 600 if _boardLeft > 600

				_boardY = e.screenY
				_boardX = e.screenX

				m = _g('movable')
				m.style.top = _boardTop + 'px'
				m.style.left = _boardLeft + 'px'

	# Draw the main board.
	_drawBoard = (title) ->
		# Disable right click
		#document.oncontextmenu = -> false
		#document.addEventListener 'mousedown', (e) ->
		#	if e.button is 2 then false else true

		# hide freewords label if the widget has none
		_freeWordsRemaining = _qset.options.freeWords
		$('.remaining').css('display','none') if _freeWordsRemaining < 1

		# ellipse the title if too long
		title = title.substring(0,42) + '...' if title.length > 45
		$('#title').html title
		$('#title').css 'font-size', 25 - (title.length / 8) + 'px'

		_left = 0
		_top = 0

		# generate elements for questions
		forEveryQuestion (i,letters,x,y,dir) ->
			question = _questions[i].questions[0].text

			if not _curLetter
				_curLetter = { x: x, y: y }

			questionNumber = parseInt(i) + 1
			hintPrefix = questionNumber + if dir then ' down' else ' across'

			_renderNumberLabel questionNumber, x, y
			_renderClue question, hintPrefix, i

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#freewordbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword

			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					return
				
				# keep track of the largest dimension of the puzzle
				# for zooming
				if letterLeft > _left
					_left = letterLeft
				if letterTop > _top
					_top = letterTop
				
				letter = document.createElement 'div'
				letter.id = 'letter_' + letterLeft + '_' + letterTop
				letter.className = 'letter'
				letter.setAttribute 'data-q', i
				letter.setAttribute 'data-dir', dir
				letter.onclick = _letterClicked

				letter.style.top = 120 + letterTop * LETTER_HEIGHT + 'px'
				letter.style.left = 10 + letterLeft * LETTER_WIDTH + 'px'

				if letters[l] == ' '
					# if it's a space, make it a black block
					letter.style.backgroundColor = '#000'
					letter.setAttribute 'data-space', '1'

				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				$('#movable').append letter

		# zoom animation
		if _left > 17 or _top > 20
			$('#movable').addClass 'pannedout'
			setTimeout ->
				$('#movable').removeClass 'pannedout'
			, 2500

	_removeHighlight = (id) ->
		g = _g('letter_' + _curLetter.x + '_' + _curLetter.y)
		if g?
			g.className = 'letter'

	_addHighlight = (id) ->
		highlightedLetter = _g('letter_' + _curLetter.x + '_' + _curLetter.y)

		if highlightedLetter
			highlightedLetter.className = 'letter focus'

			# move the board input closer to the letter,
			# in the event the user has zoomed on a mobile device
			bi = _g('boardinput')
			bi.style.top = highlightedLetter.style.top
			bi.style.left = highlightedLetter.style.left

		clue = _g('clue_'+highlightedLetter.getAttribute('data-q'))

		if clue.className.indexOf('highlight') != -1
			return

		for j of _questions
			_g('clue_'+j).className = ''

		scrolly = clue.offsetTop
		clue.className = 'highlight'

		$('#clues').animate scrollTop: scrolly, 150

	_inputLetter = (e,iteration) ->
		iteration = iteration || 0

		_lastLetter = {}
		_lastLetter.x = +_curLetter.x
		_lastLetter.y = +_curLetter.y
		
		_removeHighlight()

		letter = _g('letter_' + _curLetter.x + '_' + _curLetter.y)
			
		switch e.keyCode
			when 37 #left
				_curLetter.x--
				_curDir = -1
			when 38 #up
				_curLetter.y--
				_curDir = -1
			when 39 #right
				_curLetter.x++
				_curDir = -1
			when 40 #down
				_curDir = -1
				_curLetter.y++
			when 8
				# dont make the page back navigate
				e.preventDefault()

				if letter?
					if _curDir == -1
						_curDir = letter.getAttribute('data-dir')
					if _curDir == '1'
						_curLetter.y--
					else
						_curLetter.x--
					letter.innerHTML = ''
			else
				if letter?
					if _curDir == -1
						_curDir = letter.getAttribute('data-dir')
					if _curDir == '1'
						_curLetter.y++
					else
						_curLetter.x++

					isValid = (e.keyCode > 47 && e.keyCode < 58)		|| # number keys
								(e.keyCode == 32 || e.keyCode == 13)	|| # spacebar and enter	
								(e.keyCode > 64 && e.keyCode < 91)	# alphabet keys
					if isValid
						letter.innerHTML = String.fromCharCode(e.keyCode)
					_checkIfDone()

		next = _g('letter_' + _curLetter.x + '_' + _curLetter.y)

		if next and next.getAttribute('data-space') != '1'
			_addHighlight()
		else
			if not next?
				_curDir = if _curDir == '1' then 0 else -1
				_curLetter = _lastLetter
			if iteration < 5
				_inputLetter e, (iteration || 0)+1
		
	_captionUpdate = ->
		sentence = ' free word' + (if _freeWordsRemaining is 1 then '' else 's') + ' remaining'
		$('#freeWordsRemaining').html _freeWordsRemaining + sentence

		if _freeWordsRemaining < 1
			for i of _questions
				if _qset.options.freeWords < 1
					$('#freewordbtn_'+i).css 'display', 'none'
				else
					_g('freewordbtn_'+i).className = 'button disabled'

	_letterClicked = (e) ->
		if !e?
			e = window.event
		s = (e.target or e.srcElement).id.split '_'
		_removeHighlight()
		_curLetter = { x: parseInt(s[1]), y: parseInt(s[2]) }
		_curDir = _g('letter_' + _curLetter.x + '_' + _curLetter.y).getAttribute('data-dir')
		_addHighlight()

	_hintConfirm = (e) ->
		_showAlert 'Receiving a hint will result in a ' + _qset.options.hintPenalty + '% penalty for this question', ->
			_getHint e.target.getAttribute 'data-i'

	_getFreeword = (e) ->
		_freeWord e.target.getAttribute 'data-i'

	_highlight = (index) ->
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop) ->
				if i != index
					_g('letter_' + letterLeft + '_' + letterTop).className = 'letter'
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop) ->
				if i == index
					_g('letter_' + letterLeft + '_' + letterTop).className = 'letter highlight'

	_showAlert = (caption, action) ->
		ab = $('#alertbox')
		ab.css 'display', 'block'
		ab.addClass 'fadein'
		$('#alertcaption').html caption

		$('#confirmbtn').unbind('click').click ->
			_hideAlert()
			action()

	_hideAlert = ->
		ab = $('#alertbox')
		ab.addClass 'fadeout'
		
		setTimeout ->
			ab.css 'display', 'none'
			ab.removeClass 'fadein'
			ab.removeClass 'fadeout'
		,190

	_freeWord = (index) ->
		if _freeWordsRemaining < 1
			return

		index = parseInt(index)

		letters = _questions[index].answers[0].text.split('')
		x = _questions[index].options.x
		y = _questions[index].options.y
		dir = _questions[index].options.dir

		answer = ''

		forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
			_g('letter_' + letterLeft + '_' + letterTop).innerHTML = letters[l].toUpperCase()

		_freeWordsRemaining--

		_g('freewordbtn_' + index).style.opacity = 0
		hb = _g('hintbtn_' + index)
		hb.style.opacity = 0

		_captionUpdate()

	_getHint = (index) ->
		Materia.Score.submitInteractionForScoring _questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty

		hs = _g('hintspot_' + index)
		hs.innerHTML = 'Hint: ' + _questions[index].options.hint
		hs.style.opacity = 1

		hb = _g('hintbtn_' + index)
		hb.style.opacity = 0

		setTimeout ->
			hb.style.left = '-43px'
			_g('freewordbtn_' + index).style.left = '-43px'
		,190

	_checkIfDone = ->
		done = true
		
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				if letters[l] != ' '
					if _g('letter_' + letterLeft + '_' + letterTop).innerHTML == ''
						done = false
						return
		if done
			$('#checkBtn').addClass 'done'
		else
			$('#checkBtn').removeClass 'done'

	_renderNumberLabel = (questionNumber, x, y) ->
		numberLabel = document.createElement 'div'
		numberLabel.innerHTML = questionNumber
		numberLabel.className = 'numberlabel'
		numberLabel.style.top = 129 + y * LETTER_HEIGHT + 'px'
		numberLabel.style.left = 31 + x * LETTER_WIDTH + 'px'
		$('#movable').append numberLabel

	_renderClue = (question, hintPrefix, i) ->
		clue = document.createElement 'div'
		clue.id = 'clue_' + i

		clue.innerHTML = $('#t_hints').html()
			.replace(/{{hintPrefix}}/g, hintPrefix)
			.replace(/{{question}}/g, question)
			.replace(/{{i}}/g, i)

		clue.setAttribute 'data-i', i

		clue.onmouseover = _clueMouseOver
		clue.onmouseout = _clueMouseOut

		$('#clues').append clue

	_clueMouseOver = (e) ->
		if !e?
			e = window.event
		_highlight (e.target or e.srcElement).getAttribute('data-i')

	_clueMouseOut = (e) ->
		_highlight false

	_submitAnswers = ->
		forEveryQuestion (i,letters,x,y,dir) ->
			answer = ''
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				if letters[l] != ' '
					answer += _g('letter_' + letterLeft + '_' + letterTop).innerHTML || '_'
				else
					answer += ' '

			Materia.Score.submitQuestionForScoring _questions[i].id, answer

		Materia.Engine.end()

	# loop iteration functions to prevent redundancy
	forEveryLetter = (x,y,dir,letters,cb) ->
		for l in [0..letters.length-1]
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
			x = _questions[i].options.x
			y = _questions[i].options.y
			dir = _questions[i].options.dir
			cb i, letters, x, y, dir

	# move this elsewhere?
	_printBoard = (e) ->
		frame = document.createElement 'iframe'
		$('body').append frame
		wnd = frame.contentWindow
		frame.style.display = 'none'
		
		wnd.document.write '<h1>' + _instance.name + '</h1>'
		wnd.document.write "<h1 style='page-break-before:always'>" + _instance.name + '</h1>'

		downClues = document.createElement 'div'
		downClues.innerHTML = '<strong>Down</strong>'

		acrossClues = document.createElement 'div'
		acrossClues.innerHTML = '<strong>Across</strong>'

		wnd.document.body.appendChild downClues
		wnd.document.body.appendChild acrossClues

		forEveryQuestion (i,letters,x,y,dir) ->
			question = _questions[i].questions[0].text
			questionNumber = parseInt(i) + 1
			
			clue = '<p><strong>' + questionNumber + '</strong>: ' + question + '</p>'

			if dir
				downClues.innerHTML += clue
			else
				acrossClues.innerHTML += clue
				
			_puzzleGrid = {}

			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				numberLabel = document.createElement 'div'
				numberLabel.innerHTML = questionNumber
				numberLabel.style.position = 'absolute'
				numberLabel.style.top = 129 + y * LETTER_HEIGHT + 'px'
				numberLabel.style.left = 80 + x * LETTER_WIDTH + 'px'
				numberLabel.style.fontSize = 10 + 'px'
				numberLabel.style.zIndex = '1000'

				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					return

				letter = wnd.document.createElement 'input'
				letter.type = 'text'
				letter.setAttribute 'maxlength', 1
				letter.style.position = 'absolute'
				letter.style.top = 120 + letterTop * LETTER_HEIGHT + 'px'
				letter.style.left = 60 + letterLeft * LETTER_WIDTH + 'px'
				letter.style.border = 'solid 1px #333'
				letter.style.width = '28px'
				letter.style.height = '24px'

				if letters[l] == ' '
					# if it's a space, make it a black block
					letter.style.backgroundColor = '#000'

				wnd.document.body.appendChild letter
				wnd.document.body.appendChild numberLabel

		wnd.print()

	#public
	manualResize: true
	start: start
