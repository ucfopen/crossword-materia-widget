Namespace('Crossword').Engine = do ->
	_qset                   = null
	_questions				= null
	_hintsRemaining			= 0
	_freeWordsRemaining		= 0
	_puzzleGrid				= {}
	_instance				= {}

	_boardDown				= false
	_boardY					= 0
	_boardTop				= 0
	_boardX					= 0
	_boardLeft				= 0

	curDir					= -1


	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->
		_qset = qset
		_questions = _qset.items[0].items
		_drawBoard(instance.name)
		_instance = instance

		_captionUpdate()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()

	_caption = (id,caption) ->
		$('#'+id).html(caption)

	_captionUpdate = () ->
		_caption('title', _instance.name)
		_caption('freeWordsRemaining', _freeWordsRemaining)
		_caption('hintsRemaining', _hintsRemaining)

		if _freeWordsRemaining < 1
			for i of _questions
				$('#freewordbtn_'+i).css('opacity',0)

	# Draw the main board.
	_drawBoard = (title) ->
		# special place in hell below
		# disabled for development because inspect element
		#document.oncontextmenu = -> false                  # Disables right click.
		#document.addEventListener 'mousedown', (e) ->
		#	if e.button is 2 then false else true          # Disables right click.

		_freeWordsRemaining = _qset.options.freeWords

		# generate elements for questions
		for i of _questions
			
			# increment the hints counter
			if _questions[i].options.hint
				_hintsRemaining++

			# split the word into a letter array for the second loop
			letters = _questions[i].answers[0].text.toUpperCase().split('')

			x = _questions[i].options.x
			y = _questions[i].options.y
			dir = _questions[i].options.dir
			question = _questions[i].questions[0].text

			if dir
				questionNumber = (parseInt(i) + 1)
				hintPrefix = questionNumber + " down"
			else
				questionNumber = (parseInt(i) + 1)
				hintPrefix = questionNumber + " across"

			_renderNumberLabel questionNumber, x, y
			_renderClue question, hintPrefix, i

			$('#hintbtn_'+i).css('display', 'none') if not _questions[i].options.hint
			$('#hintbtn_'+i).click _hintConfirm
			$('#freewordbtn_'+i).click _getFreeword

			# generate inputs for each letter in answer
			for l in [0..letters.length-1]
				if dir			# vertical
					letterLeft = x
					letterTop = y + l
				else			# horizontal
					letterLeft = x + l
					letterTop = y

				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					continue

				letter = document.createElement('input')
				letter.type = 'text'
				letter.setAttribute('data-q', i)
				letter.setAttribute('maxlength', 1)
				letter.setAttribute('dir', dir)
				letter.className = 'letter'
				letter.id = "letter_" + letterLeft + "_" + letterTop

				if letters[l] == " "
					# if it's a space, make it a black block
					letter.className += " space"

				letter.onkeydown = _letterKeydown
				letter.onkeyup = _checkIfDone
				letter.onfocus = _letterFocus
				letter.style.top = 120 + (letterTop) * 23 + "px"
				letter.style.left = 10 + (letterLeft) * 27 + "px"

				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				$('#movable').append letter
				letter.focus()

		$('#cancelbtn').click _hideAlert

		$('#checkBtn').click () ->
			_showAlert "Are you sure you're done?<br>This is your last chance!", _submitAnswers

		$('#board').mousedown (e) ->
			_boardDown = true
			_boardY = e.screenY
			_boardX = e.screenX

			curDir = -1

		$('#board').mouseup (e) ->
			_boardDown = false

		$('#board').mousemove (e) ->
			if _boardDown
				_boardTop += (e.screenY - _boardY)
				_boardLeft += (e.screenX - _boardX)
				_boardY = e.screenY
				_boardX = e.screenX

				$('#movable').css('top', _boardTop + "px")
				$('#movable').css('left', _boardLeft + "px")

	_letterFocus = (e) ->
		if $('#clue_'+e.target.getAttribute('data-q')).hasClass('highlight')
			return

		for j of _questions
			$('#clue_'+j).removeClass('highlight')

		scrolly = $('#clue_'+e.target.getAttribute('data-q')).position().top + $('#clues').scrollTop()

		$('#clue_'+e.target.getAttribute('data-q')).addClass('highlight')
		$('#clues').animate({
			scrollTop: scrolly
		}, 150)

	
	_letterKeydown = (e) ->
		currentLetter = e.target
		cur = e.target.id.split("_")

		deltaX = 1
		deltaY = 0

		if curDir == -1
			curDir = currentLetter.getAttribute("dir")
		else if curDir == "1"
			deltaY = 1
			deltaX = 0

		if e.keyCode == 37
			deltaX = -1
			deltaY = 0
			curDir = -1
		else if e.keyCode == 38
			deltaY = -1
			deltaX = 0
			curDir = -1
		else if e.keyCode == 39
			deltaX = 1
			deltaY = 0
			curDir = -1
		else if e.keyCode == 40
			deltaX = 0
			deltaY = 1
			curDir = -1
		else if e.keyCode == 8
			if e.target.value == ""
				# backspace
				if curDir == "1"
					deltaX = 0
					deltaY = -1
				else
					deltaX = -1
					deltaY = 0
				curDir = -1
			else
				return
		else
			if e.target.value == ""
				return


		if next = document.getElementById("letter_" + (parseInt(cur[1]) + deltaX) + "_" + (parseInt(cur[2]) + deltaY))
			if next.className.indexOf('space') != -1
				next.value = ' '
				_letterKeydown({ target: next, keyCode: e.keyCode })
			else
				next.setSelectionRange(0,1)
				next.focus()
				next.setSelectionRange(0,1)
		else
			curDir = -1


	_hintConfirm = (e) ->
		_showAlert 'Receiving a hint will result in a ' + _qset.options.hintPenalty + '% penalty for this question', () ->
			_getHint(e.target.getAttribute('data-i'))

	_getFreeword = (e) ->
		_freeWord(e.target.getAttribute('data-i'))
			
	_highlight = (index) ->
		_questions = _qset.items[0].items

		for i of _questions
			letters = _questions[i].answers[0].text.split('')
			x = _questions[i].options.x
			y = _questions[i].options.y
			dir = _questions[i].options.dir

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l

				if i != index
					$('#letter_' + letterLeft + '_' + letterTop).removeClass('highlight')

		for i of _questions
			letters = _questions[i].answers[0].text.split('')
			x = _questions[i].options.x
			y = _questions[i].options.y
			dir = _questions[i].options.dir

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l

				if i == index
					$('#letter_' + letterLeft + '_' + letterTop).addClass 'highlight'

	_showAlert = (caption, action) ->
		ab = $('#alertbox')
		ab.css 'display', 'block'
		ab.addClass 'fadein'
		_caption 'alertcaption', caption

		$('#confirmbtn').unbind('click').click () ->
			_hideAlert()
			action()

	_hideAlert = () ->
		ab = $('#alertbox')
		ab.addClass 'fadeout'
		
		setTimeout(() ->
			ab.css 'display', 'none'
			ab.removeClass 'fadein'
			ab.removeClass 'fadeout'
		,190)

	_freeWord = (index) ->
		if _freeWordsRemaining < 1
			return

		index = parseInt(index)
		_questions = _qset.items[0].items

		letters = _questions[index].answers[0].text.split('')
		x = _questions[index].options.x
		y = _questions[index].options.y
		dir = _questions[index].options.dir

		answer = ""

		for l in [0..letters.length-1]
			if dir == 0
				letterLeft = x + l
				letterTop = y
			else
				letterLeft = x
				letterTop = y + l

			document.getElementById("letter_" + letterLeft + "_" + letterTop).value = letters[l]

		_freeWordsRemaining--

		document.getElementById("freewordbtn_" + index).style.opacity = 0
		_captionUpdate()

		return


	_getHint = (index) ->
		_hintsRemaining--
		_captionUpdate()

		_questions = _qset.items[0].items

		Materia.Score.submitInteractionForScoring _questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty

		_caption 'hintspot_' + index, _questions[index].options.hint

		$('#hintspot_' + index).css('opacity', 1)
		$('#hintbtn_' + index).css('opacity', 0)

		setTimeout(() ->
			$('#hintbtn_' + index).css('left', '-43px')
			$('#freewordbtn_' + index).css('left', '-43px')
		,190)

	_checkIfDone = ->
		_questions = _qset.items[0].items

		done = true

		for i of _questions
			letters = _questions[i].answers[0].text.split('')
			x = _questions[i].options.x
			y = _questions[i].options.y
			dir = _questions[i].options.dir

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l

				if letters[l] != " "
					if $("#letter_" + letterLeft + "_" + letterTop).val() == ""
						done = false
						break
		if done
			$('#checkBtn').addClass('done')
		else
			$('#checkBtn').removeClass('done')

	_renderNumberLabel = (questionNumber, x, y) ->
		numberLabel = document.createElement('div')
		numberLabel.innerHTML = questionNumber
		numberLabel.className = 'numberlabel'
		numberLabel.style.top = 129 + (y * 23) + "px"
		numberLabel.style.left = 31 + (x * 27) + "px"
		$('#movable').append numberLabel

	_renderClue = (question, hintPrefix, i) ->
		clue = document.createElement 'div'
		clue.id = 'clue_' + i

		clue.innerHTML = $('#t_hints').html().
							replace(/{{hintPrefix}}/g, hintPrefix).
							replace(/{{question}}/g, question).
							replace(/{{i}}/g, i)

		clue.setAttribute 'data-i', i

		clue.onmouseover = _clueMouseOver
		clue.onmouseout = _clueMouseOut

		$('#clues').append clue

	_clueMouseOver = (e) ->
		_highlight(e.target.getAttribute('data-i'))

	_clueMouseOut = (e) ->
		_highlight(false)

	_submitAnswers = ->
		_questions = _qset.items[0].items

		for i of _questions
			letters = _questions[i].answers[0].text.split('')
			x = _questions[i].options.x
			y = _questions[i].options.y
			dir = _questions[i].options.dir

			answer = ''

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l

				if letters[l] != " "
					answer += $("#letter_" + letterLeft + "_" + letterTop).val() || "_"
				else
					answer += " "

			Materia.Score.submitQuestionForScoring _questions[i].id, answer

		Materia.Engine.end()

	#public
	manualResize: true
	start: start
