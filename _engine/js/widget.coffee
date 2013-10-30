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
	_curLetter				= {x:1,y:3}

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

		# once everything is drawn, set the height of the player
		#Materia.Engine.setHeight()
	
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
				_boardTop = -500 if _boardTop < -500
				_boardTop = 500 if _boardTop > 500
				_boardLeft = -500 if _boardLeft < -500
				_boardLeft = 500 if _boardLeft > 500

				_boardY = e.screenY
				_boardX = e.screenX

				m = $('#movable')
				m.css 'top', _boardTop + 'px'
				m.css 'left', _boardLeft + 'px'

	_removeHighlight = (id) ->
		g = document.getElementById('letter_' + _curLetter.x + '_' + _curLetter.y)
		if g
			if g.className.indexOf('space') == -1
				g.className = 'letter'

	_addHighlight = (id) ->
		g = document.getElementById('letter_' + _curLetter.x + '_' + _curLetter.y)
		if g
			g.className = 'letter focus'
			document.getElementById('boardinput').style.top = g.style.top
			document.getElementById('boardinput').style.left = g.style.left
		clue = $('#clue_'+g.getAttribute('data-q'))
		if clue.hasClass 'highlight'
			return

		for j of _questions
			$('#clue_'+j).removeClass 'highlight'

		scrolly = clue.position().top + $('#clues').scrollTop()

		clue.addClass 'highlight'

		$('#clues').animate scrollTop: scrolly, 150

	_inputLetter = (e,iteration) ->
		iteration = iteration || 0

		_lastLetter = _curLetter
		
		_removeHighlight()
		g = document.getElementById('letter_' + _curLetter.x + '_' + _curLetter.y)
			
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
				if _curDir == '1'
					_curLetter.y--
				else
					_curLetter.x--
				if g
					g.innerHTML = ''
			else
				if g
					if _curDir == -1
						_curDir = g.getAttribute('dir')
					if _curDir == '1'
						_curLetter.y++
					else
						_curLetter.x++
					g.innerHTML = String.fromCharCode(e.keyCode)

		next = document.getElementById('letter_' + _curLetter.x + '_' + _curLetter.y)

		if next and next.className.indexOf('space') == -1
			_addHighlight()
		else
			if not next
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
					$('#freewordbtn_'+i).attr 'disabled', true

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

			questionNumber = parseInt(i) + 1
			hintPrefix = questionNumber + if dir then ' down' else ' across'

			#_renderNumberLabel questionNumber, x, y
			_renderClue question, hintPrefix, i

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#freewordbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword

			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					return
				if letterLeft > _left
					_left = letterLeft
				if letterTop > _top
					_top = letterTop
				
				letter = document.createElement 'div'
				letter.id = 'letter_' + letterLeft + '_' + letterTop
				letter.className = 'letter'
				letter.type = 'text'
				letter.setAttribute 'data-q', i
				letter.setAttribute 'maxlength', 1
				letter.setAttribute 'dir', dir
				letter.onclick = _letterClicked

				letter.style.top = 120 + letterTop * LETTER_HEIGHT + 'px'
				letter.style.left = 10 + letterLeft * LETTER_WIDTH + 'px'

				if letters[l] == ' '
					# if it's a space, make it a black block
					letter.className += ' space'

				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				$('#movable').append letter

		# zoom animation
		if _left > 17 or _top > 20
			$('#movable').addClass 'pannedout'
			setTimeout ->
				$('#movable').removeClass 'pannedout'
			,2500

		$('#letter_'+_left+'_'+_top).focus()

	_letterClicked = (e) ->
		s = e.target.id.split '_'
		_removeHighlight()
		_curLetter = { x: parseInt(s[1]), y: parseInt(s[2]) }
		_addHighlight()

	_letterFocus = (e) ->
		if !e?
			e = window.event
		clue = $('#clue_'+(e.target or e.srcElement).getAttribute('data-q'))
		if clue.hasClass 'highlight'
			return

		for j of _questions
			$('#clue_'+j).removeClass 'highlight'

		scrolly = clue.position().top + $('#clues').scrollTop()

		clue.addClass 'highlight'

		$('#clues').animate scrollTop: scrolly, 150

	_letterKeydown = (e) ->
		# LEFT OFF
		if not e?
			e = window.event

		currentLetter = e.target or e.srcElement
		cur = currentLetter.id.split '_'
		x = parseInt cur[1]
		y = parseInt cur[2]

		deltaX = 1
		deltaY = 0

		if _curDir == -1
			_curDir = currentLetter.getAttribute 'dir'
		if _curDir == '1'
			deltaY = 1
			deltaX = 0
		switch e.keyCode
			when 37 #left
				deltaX = -1
				deltaY = 0
				_curDir = -1
			when 38 #up
				deltaY = -1
				deltaX = 0
				_curDir = -1
			when 39 #right
				deltaX = 1
				deltaY = 0
				_curDir = -1
			when 40 #down
				deltaX = 0
				deltaY = 1
				_curDir = -1
			when 8 #backspace
				if currentLetter.value == '' or currentLetter.value == ' '
					if _curDir == '1'
						deltaX = 0
						deltaY = -1
					else
						deltaX = -1
						deltaY = 0
				else
					return
			else
				if currentLetter.value == ''
					return

		next = $('#letter_' + (x + deltaX) + '_' + (y + deltaY))

		if next.length
			if next.hasClass 'space'
				next.val ' '
				_letterKeydown
					target: next.get(0),
					keyCode: e.keyCode
			else
				next.focus()
				setTimeout ->
					if next.get(0).setSelectionRange
						next.get(0).setSelectionRange 0, 1
				,10
		else
			if e.stackCount and e.stackCount > 4
				return

			_curDir = if _curDir == '1' then 0 else -1

			_letterKeydown
				target: currentLetter,
				keyCode: e.keyCode,
				stackCount: (e.stackCount || 0) + 1

	_hintConfirm = (e) ->
		_showAlert 'Receiving a hint will result in a ' + _qset.options.hintPenalty + '% penalty for this question', ->
			_getHint e.target.getAttribute 'data-i'

	_getFreeword = (e) ->
		_freeWord e.target.getAttribute 'data-i'

	_highlight = (index) ->
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop) ->
				if i != index
					$('#letter_' + letterLeft + '_' + letterTop).removeClass 'highlight'
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop) ->
				if i == index
					$('#letter_' + letterLeft + '_' + letterTop).addClass 'highlight'

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
			$('#letter_' + letterLeft + '_' + letterTop).html letters[l].toUpperCase()

		_freeWordsRemaining--

		$('#freewordbtn_' + index).css 'opacity', 0
		hb = $('#hintbtn_' + index)
		hb.css 'opacity', 0
		hb.attr 'disabled', 1

		_captionUpdate()

	_getHint = (index) ->
		Materia.Score.submitInteractionForScoring _questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty

		hs = $('#hintspot_' + index)
		hs.html 'Hint: ' + _questions[index].options.hint
		hs.css 'opacity', 1

		hb = $('#hintbtn_' + index)
		hb.css 'opacity', 0

		setTimeout ->
			hb.css 'left', '-43px'
			$('#freewordbtn_' + index).css 'left', '-43px'
		,190

	_checkIfDone = ->
		done = true
		
		forEveryQuestion (i,letters,x,y,dir) ->
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				if letters[l] != ' '
					if $('#letter_' + letterLeft + '_' + letterTop).val() == ''
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

	_submitAnswers = ->
		forEveryQuestion (i,letters,x,y,dir) ->
			answer = ''
			forEveryLetter x,y,dir,letters, (letterLeft,letterTop,l) ->
				if letters[l] != ' '
					answer += $('#letter_' + letterLeft + '_' + letterTop).html() || '_'
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

	#public
	manualResize: true
	start: start
