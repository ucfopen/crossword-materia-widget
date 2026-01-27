Namespace('Crossword').ScoreScreen = do ->
	# variables to store widget data in this scope
	_qset                 = null
	_questions            = null
	_scoreTable           = null
	_puzzleGrid           = {}

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
	# the current clue that is highlighted
	_curClue			  = -1

	# cache DOM elements for performance
	_domCache             = {}
	_boardDiv             = null # div containing the board
	_contDiv              = null # parent div of _boardDiv

	# these are the allowed user input
	_allowedInput         = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','Á','À','Â','Ä','Ã','Å','Æ','Ç','É','È','Ê','Ë','Í','Ì','Î','Ï','Ñ','Ó','Ò','Ô','Ö','Õ','Ø','Œ','ß','Ú','Ù','Û','Ü']

	_isMobile             = false
	_zoomedIn             = false

	# constants
	MOBILE_PX             = 576 # in px., mobile breakpoint size
	LETTER_HEIGHT         = 23  # how many pixles high is a space?
	LETTER_WIDTH          = 27  # how many pixles wide is a space?
	VERTICAL              = 1   # used to compare dir == 1 or dir == VERTICAL
	BOARD_WIDTH           = 560 # visible board width, minus space for
	BOARD_HEIGHT          = 550 # visible board height, minus space for zoom button
	BOARD_LETTER_WIDTH    = Math.floor(BOARD_WIDTH / LETTER_WIDTH)
	BOARD_LETTER_HEIGHT   = Math.floor(BOARD_HEIGHT / LETTER_HEIGHT)

		# width of the scaled game container
	_contWidth = () ->
		return parseFloat(_contDiv.width())

	# height of the scaled game container
	_contHeight = () ->
		return parseFloat(_contDiv.height())

	# width of crossword map extent
	_mapWidth = () ->
		return parseFloat(_boardDiv.width())

	# height of crossword map extent
	_mapHeight = () ->
		return parseFloat(_boardDiv.height())

	# size of the margin centering the map in the X direction
	_mapXMargin = () ->
		return parseFloat(_boardDiv.css("margin-left").replace("px",""))

	# size of the margin centering the map in the Y direction
	_mapYMargin = () ->
		return parseFloat(_boardDiv.css("margin-top").replace("px",""))

	# get the map's padding, assuming it is uniform
	_mapPadding = () ->
		return Math.abs(_boardDiv.width() - _boardDiv.innerWidth()) / 2

	# get the map's border, assuming it is uniform
	_mapBorder = () ->
		return (_boardDiv.outerWidth() - _boardDiv.innerWidth()) / 2

	# Centers the board
	_centerBoard = () ->
		_boardDiv.css('margin-left', (_contWidth() - _boardDiv.outerWidth()) / 2)
		_boardDiv.css('margin-top', (_contHeight() - _boardDiv.outerHeight()) / 2)

	_rescaleVars = () ->
		_puzzleWidthOverflow = _boardDiv.outerWidth() - _contWidth()
		_puzzleHeightOverflow = _boardDiv.outerHeight() - _contHeight()

	_updateIsMobile = () ->
		newMobile = $(window).width() < MOBILE_PX;
		if newMobile != _isMobile
			if !newMobile # mobile -> desktop
				_contDiv.css("height", "calc(100%)")
				_contDiv.css("top", "0px")
				$('#clues').css("height", "auto")
			else # desktop -> mobile
				_contDiv.css("height", "calc(100% - 150px)")
				_contDiv.css("top", "150px")
				$('#clues').css("height", $('#clue_'+_curClue).outerHeight())
				
		_isMobile = newMobile

	# Called by Materia.ScoreCore when your widget ScoreCore should start the user experience.
	start = (instance, qset, scoreTable, isPreview, version = '1') ->
		# if we're on a mobile device, some event listening will be different
		_isMobile = $(window).width() < MOBILE_PX;
		if _isMobile
			$('#movable-container').css("height", "calc(100% - 150px)")
			$('#movable-container').css("top", "150px")
			$('#clues').css("height", parseInt($('#clue_'+_curClue).outerHeight()))
			document.ontouchmove = (e) ->
					e.preventDefault()

		# store widget data
		_qset = qset
		_scoreTable = scoreTable

		# easy access to questions
		_questions = _qset.items[0].items
		_boardDiv = $('#movable')
		_contDiv = $('#movable-container')

		# clean qset variables
		forEveryQuestion (i, letters, x, y, dir, response) ->
			_questions[i].options.x = ~~_questions[i].options.x
			_questions[i].options.y = ~~_questions[i].options.y
			_questions[i].options.dir = ~~_questions[i].options.dir

		puzzleSize = _measureBoard(_questions)
		_scootWordsBy(puzzleSize.minX, puzzleSize.minY, _questions) # normalize the qset coordinates

		_puzzleLetterWidth  = puzzleSize.width
		_puzzleLetterHeight = puzzleSize.height
		_puzzleWidthOverflow = (_puzzleLetterWidth * LETTER_WIDTH) - _contWidth()
		_puzzleHeightOverflow = (_puzzleLetterHeight * LETTER_HEIGHT) - _contHeight()

		_curLetter = { x: _questions[0].options.x, y:_questions[0].options.y }

		# render the widget, hook listeners, update UI
		_drawBoard()
		_animateToShowBoardIfNeeded()
		_setupEventHandlers()
		Materia.ScoreCore.setHeight()

		_updateClue()

	# Called by Materia.ScoreCore when user switches score attempt
	update = (qset, scoreTable) ->
		# if we're on a mobile device, some event listening will be different
		_isMobile = $(window).width() < MOBILE_PX;
		if _isMobile
			$('#movable-container').css("height", "calc(100% - 150px)")
			document.ontouchmove = (e) ->
					e.preventDefault()
		
		if not _qset or not isConsistentQset(qset)
			return redrawBoard(qset, scoreTable)

		_qset = qset
		answersShown = $('#hide-correct')[0].checked
		$('.letter').removeClass('correct incorrect')
		forEveryQuestion (i, letters, x, y, dir, response) ->
			forEveryLetter x, y, dir, letters, response, (left, top, l) ->
				letterElement = $("#letter_#{left}_#{top}")[0]
				classColor = if letters[l] == response[l] then 'correct' else 'incorrect'
				protectedSpace = _allowedInput.indexOf(letters[l].toUpperCase()) == -1
				letterElement.classList.add classColor if not protectedSpace
				letterElement.innerHTML = response[l] if not answersShown

	isConsistentQset = (newQset) ->
		return newQset.id == _qset.id

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
		# control window scaling
		$(window).on 'resize', () ->
			_updateIsMobile()
			_centerBoard()
			_rescaleVars()
			_limitBoardPosition()

		# keep focus on the last letter that was highlighted whenever we move the board around
		$('#board').click -> _highlightPuzzleLetter false

		$('#zoomout').click _zoomOut
		$('#hide-correct').change _toggleAnswers

		document.getElementById('board').addEventListener 'mousedown', _mouseDownHandler
		document.getElementById('board').addEventListener 'mousemove', _mouseMoveHandler
		document.addEventListener 'mouseup', _mouseUpHandler

	_navPrevQ = ->
		i = if (_curClue - 1) < 0 then _questions.length - 1 else _curClue - 1
		_clueMouseUp {target: $('#clue_'+i)[0]}

	_navNextQ = ->
		i = (_curClue + 1) % _questions.length
		_clueMouseUp {target: $('#clue_'+i)[0]}

	# start dragging
	_mouseDownHandler = (e) ->
		context = if _isMobile then e.pointers[0] else e

		return if context.clientX > 515 or not _zoomedIn

		_boardMouseDown = true
		_mouseYAnchor = context.clientY
		_mouseXAnchor = context.clientX

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

		# Sign variables flip collision behavior 
		# based on if the map is larger or smaller than the screen

		# when overflow is negative, the map should be blocked by the screen edge
		# when overflow is positive, the map should be allowed to be panned past the edge
		wSign = -Math.abs(_puzzleWidthOverflow) / _puzzleWidthOverflow
		hSign = -Math.abs(_puzzleHeightOverflow) / _puzzleHeightOverflow

		_puzzleX = wSign*(_puzzleWidthOverflow/2) if _puzzleX < wSign*(_puzzleWidthOverflow/2)
		_puzzleX = -wSign*(_puzzleWidthOverflow/2) if _puzzleX > -wSign*(_puzzleWidthOverflow/2)

		_puzzleY = hSign*(_puzzleHeightOverflow/2) if _puzzleY < hSign*(_puzzleHeightOverflow/2)
		_puzzleY = -hSign*(_puzzleHeightOverflow/2) if _puzzleY > -hSign*(_puzzleHeightOverflow/2)

	# Draw the main board.
	_drawBoard = ->
		# used to track the maximum dimensions of the puzzle
		_top = 0

		# tracks horizontal and vertical extent of the puzzle
		# origin is top-left, in units of letters
		maxLetterX = 0
		maxLetterY = 0

		# generate elements for questions
		forEveryQuestion (i, letters, x, y, dir, response, hinted) ->
			questionText   = _questions[i].questions[0].text

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
			_renderClue questionText, letters.join(''), hintPrefix, i, dir

			forEveryLetter x, y, dir, letters, response, (letterLeft, letterTop, l) ->
				# overlapping connectors should not be duplicated
				if _puzzleGrid[letterTop]? and _puzzleGrid[letterTop][letterLeft] == letters[l]
					# keep track of overlaps and store in _wordIntersections
					intersectedElement = _dom("letter_#{letterLeft}_#{letterTop}")
					if hinted then intersectedElement.classList.add 'hinted'
					intersectedQuestion = ~~intersectedElement.getAttribute("data-q") + 1

					location = "" + letterLeft + letterTop
					intersection = [~~i + 1, intersectedQuestion]
					intersection.reverse() if _questions[i].options.dir
					_wordIntersections[location] = intersection

					return

				protectedSpace = _allowedInput.indexOf(letters[l].toUpperCase()) == -1

				# each letter is a div with coordinates as id
				letterElement = document.createElement 'div'
				letterElement.id = "letter_#{letterLeft}_#{letterTop}"
				letterElement.classList.add 'letter'
				if hinted then letterElement.classList.add 'hinted'
				classColor = if letters[l] == response[l] then 'correct' else 'incorrect'
				letterElement.classList.add classColor
				letterElement.setAttribute 'readonly', true
				letterElement.setAttribute 'data-q', i
				letterElement.setAttribute 'data-dir', dir
				letterElement.onclick = _letterClicked

				letterElement.style.top = letterTop * LETTER_HEIGHT + _mapPadding() + 'px'
				letterElement.style.left = letterLeft * LETTER_WIDTH + _mapPadding() + 'px'
				letterElement.innerHTML = response[l]

				# if it's not a guessable char, display the char
				if protectedSpace
					letterElement.innerHTML = letters[l]
					letterElement.classList.remove classColor
					# Black block for spaces
					letterElement.style.backgroundColor = '#000' if letters[l] == ' '

				# init the puzzle grid for this row and letter
				_puzzleGrid[letterTop] = {} if !_puzzleGrid[letterTop]?
				_puzzleGrid[letterTop][letterLeft] = letters[l]

				# track board extent
				if letterLeft > maxLetterX
					maxLetterX = letterLeft

				if letterTop > maxLetterY
					maxLetterY = letterTop

				_boardDiv.append letterElement

		# update board sizing
		# +1 accounts for x/y values starting at 0
		newWidth = (maxLetterX + 1) * LETTER_WIDTH
		newHeight = (maxLetterY + 1) * LETTER_HEIGHT
		_boardDiv.css('width', newWidth)
		_boardDiv.css('height', newHeight)

		_centerBoard()

	redrawBoard = (qset, scoreTable) ->
		_qset = qset
		_scoreTable = scoreTable
		_boardDiv = $("#movable")
		_questions = _qset.items[0].items
		forEveryQuestion (i, letters, x, y, dir, response) ->
			_questions[i].options.x = ~~_questions[i].options.x
			_questions[i].options.y = ~~_questions[i].options.y
			_questions[i].options.dir = ~~_questions[i].options.dir

		puzzleSize = _measureBoard(_questions)
		_scootWordsBy(puzzleSize.minX, puzzleSize.minY, _questions) # normalize the qset coordinates

		_puzzleLetterWidth  = puzzleSize.width
		_puzzleLetterHeight = puzzleSize.height
		_puzzleWidthOverflow = (_puzzleLetterWidth * LETTER_WIDTH) - BOARD_WIDTH
		_puzzleHeightOverflow = (_puzzleLetterHeight * LETTER_HEIGHT) - BOARD_HEIGHT

		_curLetter = { x: _questions[0].options.x, y:_questions[0].options.y }

		# reset everything
		$('#clues').empty();
		$('#movable').empty()
		_puzzleGrid = {}
		_wordMapping = {}
		_labelIndexShift = 0
		_wordIntersections = {}

		_drawBoard()
		_animateToShowBoardIfNeeded()
		_setupEventHandlers()

	# zoom animation if dimensions are off screen
	_animateToShowBoardIfNeeded = ->
		if _puzzleLetterWidth > BOARD_LETTER_WIDTH or _puzzleLetterHeight > BOARD_LETTER_HEIGHT
			_zoomOut()

			setTimeout ->
				_zoomIn()
			, 2500

	_zoomOut = ->
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
	_updateClue = (animate = true) ->
		highlightedLetter = _dom("letter_#{_curLetter.x}_#{_curLetter.y}")

		if highlightedLetter
			clue = _dom('clue_'+highlightedLetter.getAttribute('data-q'))
			_curClue = parseInt highlightedLetter.getAttribute('data-q')

			# if it's already highlighted, do not try to scroll to it
			if clue.classList.contains 'highlight'
				return

			# remove the highlight from all others
			for j of _questions
				_dom('clue_'+j).classList.remove 'highlight'

			scrolly = clue.offsetTop
			clue.classList.add 'highlight'

			$('#clues').stop true
			if animate
				$('#clues').animate scrollTop: scrolly, if _isMobile then 0 else 150

			if _isMobile
				$('#clues').css("height", parseInt($('#clue_'+_curClue).outerHeight()))

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

		_highlightPuzzleWord (target).getAttribute('data-q')

		_highlightPuzzleLetter true

		_updateClue animate

	# highlight a word (series of letters)
	_highlightPuzzleWord = (index) ->
		# remove highlights
		$(".highlight").removeClass("highlight")
		# and add it to the ones we care about
		forEveryQuestion (i, letters, x, y, dir, response) ->
			if ~~i == ~~index
				forEveryLetter x,y,dir,letters,response, (letterLeft, letterTop) ->
					l = _dom("letter_#{letterLeft}_#{letterTop}")
					if l?
						l.classList.add 'highlight'

	_toggleAnswers = (e) ->
		e = window.event if not e?
		if (e.target.checked)
			$('.letter').addClass 'neutral'
			forEveryQuestion (i, letters, x, y, dir, response) ->
				forEveryLetter x, y, dir, letters, response, (left, top, l) ->
					$("#letter_#{left}_#{top}")[0].innerHTML = letters[l]
		else
			$('.letter').removeClass 'neutral'
			forEveryQuestion (i, letters, x, y, dir, response) ->
				forEveryLetter x, y, dir, letters, response, (left, top, l) ->
					$("#letter_#{left}_#{top}")[0].innerHTML = response[l]

	# hide it
	_hideAlert = ->
		_dom('alertbox').classList.remove 'show'
		_dom('backgroundcover').classList.remove 'show'

	# draw a number label to identify the question
	_renderNumberLabel = (questionNumber, x, y) ->
		numberLabel = document.createElement 'div'
		numberLabel.innerHTML = questionNumber
		numberLabel.classList.add 'numberlabel'
		numberLabel.style.top = y * LETTER_HEIGHT + _mapPadding() + 'px'
		numberLabel.style.left = x * LETTER_WIDTH + _mapPadding() + 'px'
		numberLabel.onclick = -> _letterClicked target: $("#letter_#{x}_#{y}")[0]
		_boardDiv.append numberLabel

	# draw the clue from template html
	_renderClue = (question, answer, hintPrefix, i, dir) ->
		clue = document.createElement 'div'
		clue.id = 'clue_' + i

		clue.innerHTML = $('#t_hints').html()
			.replace(/{{hintPrefix}}/g, hintPrefix)
			.replace(/{{question}}/g, question)
			.replace(/{{answer}}/g, answer)
			.replace(/{{i}}/g, i)
			.replace(/{{dir}}/g, dir)

		clue.setAttribute 'data-i', i
		clue.setAttribute 'data-dir', dir
		clue.classList.add 'clue'

		clue.onmouseover = _clueMouseOver
		clue.onmouseout  = _clueMouseOut
		clue.onmouseup   = _clueMouseUp
		
		$('#clues').append clue

		_dom('prevQ_' + i).addEventListener 'click', _navPrevQ
		_dom('nextQ_' + i).addEventListener 'click', _navNextQ

	_clueMouseUp = (e) ->
		e = window.event if not e?

		# click on the first letter of the word
		i = e.target.getAttribute('data-i')
		x = _questions[i].options.x
		y = _questions[i].options.y
		dir = _questions[i].options.dir
		len = _questions[i].answers[0].text.length
		last = len + ( if dir then y else x ) - 1

		# if the first letter of the word is at an intersection, use the second letter
		location = "" + x + y
		while _wordIntersections.hasOwnProperty(location)
			if dir
				if y < last then y++ else break
			else
				if x < last then x++ else break
			location = "" + x + y

		firstLetter = $("#letter_#{x}_#{y}")[0]
		_letterClicked { target: firstLetter }, true

	# highlight words when a clue is moused over, to correspond what the user is seeing
	_clueMouseOver = (e) ->
		e = window.event if not e?
		_highlightPuzzleWord (e.target or e.srcElement).getAttribute('data-i')

	_clueMouseOut = (e) ->
		_highlightPuzzleWord -1

	# loop iteration functions to prevent redundancy
	forEveryLetter = (x, y, dir, letters, response, cb) ->
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
			letters  = _questions[i].answers[0].text.toUpperCase().split ''
			x        = _questions[i].options.x
			y        = _questions[i].options.y
			dir      = _questions[i].options.dir
			response = _scoreTable[i].data[1].toUpperCase()
			hinted   = _scoreTable[i].feedback == "Hint Received"
			callBack(i, letters, x, y, dir, response, hinted)

	# return public stuff for Materia

	manualResize: true
	start: start
	update:update
