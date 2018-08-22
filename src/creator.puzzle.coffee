Namespace('Crossword').Puzzle = do ->

	# Initialize class variables

	loopCount = 0
	loopLimit = 20
	maxPossible = 50
	attemptCount = 0
	letterIndex = []
	puzzleGrid = {}
	possibleItems = []
	iterationCount = 0
	randomIndex = Math.random()
	BOARD_SPAN_X = 17
	BOARD_SPAN_Y = 21

	# Private methods

	# Letters is an array of letters (all caps)
	# (x,y) is the location of the first letter
	_placeOnGrid = (letters, x, y, dir) ->
		xi = 0
		yi = 0

		for i in [0...letters.length] by 1
			puzzleGrid[x+xi] = {} if !puzzleGrid[x+xi]?
			if !puzzleGrid[x+xi][y+yi]?
				_indexLetter(letters[i], x+xi, y+yi)
				puzzleGrid[x+i] = {} if !puzzleGrid[x+i]?
				puzzleGrid[x+xi][y+yi] = letters[i]

			if dir
				xi++
			else
				yi++

		return

	_indexLetter = (letter, x, y) ->
		charCode = letter.charCodeAt(0)

		if !letterIndex[charCode]?
			letterIndex[charCode] = []

		letterIndex[charCode].push({x:x, y:y})

	_testFitWord = (word) ->
		match = []
		if word.length > 1
			# for each letter in the word
			for i in [0...word.length] by 1
				continue if word[i] == " "
				# locations where this word can intersect at this letter
				matchArray = _randArray(letterIndex[word[i].charCodeAt(0)])
				if matchArray?
					for n in [0...matchArray.length] by 1
						# test across
						if _testFitWordAt(word, matchArray[n].x-i, matchArray[n].y, true)
							match = matchArray.splice(n,1)
							return { word: word, x: match[0].x-i, y: match[0].y, dir: true }
						# test down
						if _testFitWordAt(word, matchArray[n].x, matchArray[n].y-i, false)
							match = matchArray.splice(n,1)
							return { word: word, x: match[0].x, y: match[0].y-i, dir: false }
		false

	# test to see if word fits if it starts at (tx, ty)
	_testFitWordAt = (word, tx, ty, across) ->
		# check the spaces right before and after the word
		puzzleGrid[tx-1] = {} if !puzzleGrid[tx-1]?
		if across
			puzzleGrid[tx+word.length] = {} if !puzzleGrid[tx + word.length]?
			return false if puzzleGrid[tx - 1][ty]? or puzzleGrid[tx+word.length][ty]?
		else
			return false if puzzleGrid[tx][ty-1]? or puzzleGrid[tx][ty+word.length]?

		# check spaces for existing words
		for letter in word
			puzzleGrid[tx] = {} if !puzzleGrid[tx]?

			if !puzzleGrid[tx][ty]?
				# if there's not already a letter in that location
				# don't allow there to be a letter adjacent to this word in the other direction
				if across
					return false if puzzleGrid[tx][ty-1] or puzzleGrid[tx][ty+1]
				else
					return false if puzzleGrid[tx-1][ty]? or puzzleGrid[tx+1][ty]?
			else
				# if there is already a letter in that location
				# make sure it is the right letter
				return false if puzzleGrid[tx][ty] != letter
				# and make sure the letter there is an intersection, not an inline collision
				if across
					return false if !puzzleGrid[tx][ty-1]? and !puzzleGrid[tx][ty+1]?
				else
					return false if !puzzleGrid[tx-1][ty]? and !puzzleGrid[tx+1][ty]?

			if (across)
				tx++
			else
				ty++
		return true

	_randArray = (t) ->
		return null if not t?

		w = []
		for item in t
			w.push(item)

		w2 = []
		while w.length > 0
			i = Math.floor(_fakeRandom() * 10000) % w.length
			w2.push(w[i])
			w.splice(i,1)

		w2

	_fakeRandom = ->
		return randomIndex

	_generatePuzzle = (_items, force) ->
		letterIndex = []
		puzzleGrid = {}
		results = []
		loopCount = 0

		items = _randArray(_items).slice(0)

		while !firstword? and items.length > 0
			item = items.pop()
			firstword = (item.answers[0].text)
			if !firstword? or firstword.length < 2
				firstword = null
			else
				item.options.dir = 1
				item.options.x = 0
				item.options.y = 0
				results.push item
				break

		if !firstword
			return false

		_placeOnGrid(firstword.toUpperCase().split(''), 0, 0, false)

		while (items.length > 0 and loopLimit > loopCount++)
			item = items.pop()

			if item.answers[0].text.length < 1
				continue

			result = _testFitWord(item.answers[0].text.toUpperCase().split(''))

			if result
				_placeOnGrid(result.word, result.x, result.y, result.dir)
				loopCount = 0
				item.options.x = result.x
				item.options.y = result.y
				if result.dir
					item.options.dir = 0
				else
					item.options.dir = 1
				results.push item

			else
				items.splice(0,0,item)

		results = normalizeQSET results

		# keep trying to find new ones, unless it fails 50 times, in which case
		# we assume there is no possible spot for every letter, and cut our losses
		if items.length == 0 || attemptCount++ > 50
			iterationCount++
			possibleItems.push results
			# quickly return if this is a valid solution
			if not force and items.length == 0
				return centerPuzzle(results)

		if iterationCount < maxPossible
			resetRandom()
			return _generatePuzzle(_items, force)


		minArea = 9999
		maxWords = 0
		bestList = [] # stringify'ed version of the best boards

		# for each board
		for board in possibleItems
			maxX = 1
			maxY = 1
			area = 0
			# loop through all the words, and find the maxX and maxY
			for n in [0...board.length] by 1
				if board[n].options.dir == 0
					width = board[n].options.x + board[n].answers[0].text.length
					maxX = width if width > maxX
				else
					height = board[n].options.y + board[n].answers[0].text.length
					maxY = height if height > maxY

			# maximize the number of words on the board
			if board.length > maxWords
				maxWords = board.length
				minArea = 9999
			if board.length == maxWords
				# update the best if it has a smaller area, or it has the same
				# area where the board is taller than it is wide
				area = maxX * maxY
				if area < minArea or (area == minArea and maxX < maxY)
					bestList.push(JSON.stringify(board))
					minArea = area

		# the `bestList` progressively gets better, so pick the first (from the
		# back) that isn't the same as the current board (_items)
		bestList.reverse()
		best = bestList[0]
		_itemsString = JSON.stringify(_items)
		for b in bestList
			if _itemsString != b
				best = b

		centerPuzzle(JSON.parse(best))

	# Public methods

	generatePuzzle = (_items, force) ->
		possibleItems = []
		attemptCount = 0
		iterationCount = 0
		maxPossible = (_items.length * _items.length) + 10
		_generatePuzzle _items, force

	resetRandom = ->
		randomIndex = Math.random()

	normalizeQSET = (qset) ->
		minX = minY = 0

		for i in [0...qset.length] by 1
			qset[i].options.x = ~~qset[i].options.x
			qset[i].options.y = ~~qset[i].options.y

			minX = qset[i].options.x if qset[i].options.x < minX
			minY = qset[i].options.y if qset[i].options.y < minY

		for i in [0...qset.length] by 1
			qset[i].options.x -= minX
			qset[i].options.y -= minY

		# return a deep copy of the object
		JSON.parse(JSON.stringify(qset))

	centerPuzzle = (qset) ->
		maxX = maxY = 0

		# find the letters furthest away from the origin
		for i in [0...qset.length] by 1
			dir = qset[i].options.dir
			endX = qset[i].options.x + ( qset[i].answers[0].text.length * ~~(!dir) )
			endY = qset[i].options.y + ( qset[i].answers[0].text.length * ~~(dir) )
			maxX = endX if endX > maxX
			maxY = endY if endY > maxY

		xShift = Math.floor((BOARD_SPAN_X - maxX) / 2)
		yShift = Math.floor((BOARD_SPAN_Y - maxY) / 2)

		xShift = 0 if xShift < 0
		yShift = 0 if yShift < 0

		for i in [0...qset.length] by 1
			qset[i].options.x += xShift
			qset[i].options.y += yShift

		qset

	# Return public methods
	generatePuzzle: generatePuzzle
	normalizeQSET: normalizeQSET
	resetRandom: resetRandom
