Namespace('Crossword').Engine = do ->
	_qset                   = null
	_hintsRemaining			= 0
	_freeWordsRemaining		= 0
	_puzzleGrid				= {}
	_instance				= {}
	_hints					= []

	_boardDown				= false
	_boardY					= 0
	_boardTop				= 0
	_boardX					= 0
	_boardLeft				= 0

	_caption = (id,caption) ->
		document.getElementById(id).innerHTML = caption

	curDir					= -1


	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->
		_qset = qset
		_drawBoard(instance.name)
		_instance = instance

		_captionUpdate()

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()

	_captionUpdate = () ->
		_caption('title', _instance.name)
		_caption('freeWordsRemaining', _freeWordsRemaining)
		_caption('hintsRemaining', _hintsRemaining)

	# Draw the main board.
	_drawBoard = (title) ->
		# special place in hell below
		# disabled for development because inspect element
		#document.oncontextmenu = -> false                  # Disables right click.
		#document.addEventListener 'mousedown', (e) ->
		#	if e.button is 2 then false else true          # Disables right click.

		_freeWordsRemaining = _qset.options.freeWords

		questions = _qset.items[0].items

		# generate elements for questions
		for i of questions
			
			if questions[i].options.hint
				_hintsRemaining++
			_hints.push(questions[i].options.hint)

			letters = questions[i].answers[0].text.toUpperCase().split('')
			x = questions[i].options.x
			y = questions[i].options.y
			dir = questions[i].options.dir

			numberLabel = document.createElement('div')

			if dir
				questionNumber = (parseInt(i) + 1)
				hintPrefix = questionNumber + " down"
			else
				questionNumber = (parseInt(i) + 1)
				hintPrefix = questionNumber + " across"

			numberLabel.innerHTML = questionNumber
			numberLabel.className = 'numberlabel'
			numberLabel.style.top = 129 + (y * 23) + "px"
			numberLabel.style.left = 29 + (x * 27) + "px"

			hint = document.createElement 'div'

			hint.innerHTML = "<em>" + hintPrefix + ":</em> " + questions[i].questions[0].text + "<br><input type='button' data-i='"+i+"' id='hintbtn_"+i+"' value='Hint'> <input type='button' data-i='" + i + "' id='freewordbtn_"+i+"' value='Free word'><br><span id='hintspot_" + i + "'></span>"
			hint.setAttribute 'data-i', i
			hint.onmouseover = (e) ->
				if !e?
					e = window.event
				_highlight(e.target.getAttribute('data-i'))
			hint.onmouseout = (e) ->
				if !e?
					e = window.event
				_highlight(false)

			$('#hints').append hint
			$('#movable').append numberLabel

			$('#hintbtn_'+i).click (e) ->
				if !e?
					e = window.event
				_showAlert 'Receiving a hint will result in a ' + _qset.options.hintPenalty + '% penalty for this question', () ->
					_getHint(e.target.getAttribute('data-i'))
			
			$('#freewordbtn_'+i).click (e) ->
				if !e?
					e = window.event
				_freeWord(e.target.getAttribute('data-i'))

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
				letter.setAttribute('maxlength', 1)
				letter.setAttribute('dir', dir)
				letter.className = 'letter'
				letter.id = "letter_" + letterLeft + "_" + letterTop
#				letter.value = letters[l]

				if letters[l] == " "
					# if it's a space, make it a black block
					letter.className += " space"

				letter.onkeydown = _letterKeydown

				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				letter.style.top = 120 + (letterTop) * 23 + "px"
				letter.style.left = 10 + (letterLeft) * 27 + "px"
				
				$('#movable').append letter
				letter.focus()

		$('#checkBtn').click () ->
			_showAlert "Are you sure you're done?<br>This is your last chance!", _submitAnswers

		$('#board').mousedown (e) ->
			if !e?
				e = window.event

			_boardDown = true
			_boardY = e.screenY
			_boardX = e.screenX

			curDir = -1

		$('#board').mouseup (e) ->
			_boardDown = false

		$('#board').mousemove (e) ->
			if !e?
				e = window.event

			if _boardDown
				_boardTop += (e.screenY - _boardY)
				_boardLeft += (e.screenX - _boardX)
				_boardY = e.screenY
				_boardX = e.screenX

				$('#movable').css('top', _boardTop + "px")
				$('#movable').css('left', _boardLeft + "px")
	
	_letterKeydown = (e) ->
		if !e?
			e = window.event

		currentLetter = e.target
		cur = e.target.id.split("_")

		deltaX = 1
		deltaY = 0

		if curDir == -1
			curDir = currentLetter.getAttribute("dir")
		else if curDir == "1" #and !document.getElementById("letter_" + (parseInt(cur[1]) + deltaX) + "_" + cur[2])?
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
		else if e.keyCode == 40
			deltaX = 0
			deltaY = 1
			curDir = -1
		else if e.keyCode == 8
			if e.target.value == ""
				# backspace
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

	_highlight = (index) ->
		questions = _qset.items[0].items

		for i of questions
			letters = questions[i].answers[0].text.split('')
			x = questions[i].options.x
			y = questions[i].options.y
			dir = questions[i].options.dir

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l
					
				e = document.getElementById("letter_" + letterLeft + "_" + letterTop)

				if i != index
					e.className = e.className.replace("highlight","")

		for i of questions
			letters = questions[i].answers[0].text.split('')
			x = questions[i].options.x
			y = questions[i].options.y
			dir = questions[i].options.dir

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l
					
				e = document.getElementById("letter_" + letterLeft + "_" + letterTop)

				if i == index
					e.className += " highlight"

	_showAlert = (caption, action) ->
		document.getElementById('alertbox').style.display = "block"
		_caption 'alertcaption', caption
		document.getElementById('confirmbtn').onclick = () ->
			_hideAlert()
			action()
		document.getElementById('cancelbtn').onclick = _hideAlert

	_hideAlert = () ->
		document.getElementById('alertbox').style.display = "none"

	_freeWord = (index) ->
		if _freeWordsRemaining < 1
			return

		index = parseInt(index)
		questions = _qset.items[0].items

		letters = questions[index].answers[0].text.split('')
		x = questions[index].options.x
		y = questions[index].options.y
		dir = questions[index].options.dir

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
		_caption("freeWordsRemaining", _freeWordsRemaining)

		if _freeWordsRemaining < 1
			for i of questions
				document.getElementById("freewordbtn_" + i).style.opacity = 0
		return


	_getHint = (index) ->
		_hintsRemaining--
		_captionUpdate()

		questions = _qset.items[0].items
		Materia.Score.submitInteractionForScoring(questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty)
		_caption "hintspot_" + index, questions[index].options.hint
		document.getElementById("hintbtn_" + index).style.display = 'none'

	_submitAnswers = ->
		questions = _qset.items[0].items

		for i of questions
			letters = questions[i].answers[0].text.split('')
			x = questions[i].options.x
			y = questions[i].options.y
			dir = questions[i].options.dir

			answer = ""

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l

				if letters[l] != " "
					answer += document.getElementById("letter_" + letterLeft + "_" + letterTop).value || "_"
				else
					answer += " "

				console.log answer

			Materia.Score.submitQuestionForScoring questions[i].id, answer

		Materia.Engine.end()

	#public
	manualResize: true
	start: start
