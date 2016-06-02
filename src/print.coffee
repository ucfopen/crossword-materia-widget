Namespace('Crossword').Print = do ->
	# constants
	LETTER_HEIGHT			= 23
	LETTER_WIDTH			= 27

	# mess of rendering HTML to build a printable crossword from the qset
	_printBoard = (_instance, _questions) ->
		frame = document.createElement 'iframe'
		$('body').append frame
		wnd = frame.contentWindow
		frame.style.display = 'none'
		
		wnd.document.write '<h1>' + _instance.name + '</h1>'
		wnd.document.write "<h1 style='page-break-before:always'>" + _instance.name + '</h1>'

		downClues = document.createElement 'div'
		downClues.innerHTML = '<strong>Down</strong>'

		acrossClues = document.createElement 'div'
		acrossClues.innerHTML = '<br><strong>Across</strong>'

		wnd.document.body.appendChild downClues
		wnd.document.body.appendChild acrossClues

		for i of _questions
			letters = _questions[i].answers[0].text.toUpperCase().split ''
			x = ~~_questions[i].options.x
			y = ~~_questions[i].options.y
			dir = ~~_questions[i].options.dir

			question = _questions[i].questions[0].text
			questionNumber = parseInt(i) + 1
			
			clue = '<p><strong>' + questionNumber + '</strong>: ' + question + '</p>'

			_puzzleGrid = {}

			for l in [0..letters.length-1]
				if dir == 0
					letterLeft = x + l
					letterTop = y
				else
					letterLeft = x
					letterTop = y + l

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

				clue += '<div style="border: solid 1px #333; width: 28px; height: 24px; display: inline-block;"> </div>';

				if letters[l] == ' '
					# if it's a space, make it a black block
					letter.style.backgroundColor = '#000'

				wnd.document.body.appendChild letter
				wnd.document.body.appendChild numberLabel

			if dir
				downClues.innerHTML += clue
			else
				acrossClues.innerHTML += clue
				

		wnd.print()
	
	printBoard: _printBoard

