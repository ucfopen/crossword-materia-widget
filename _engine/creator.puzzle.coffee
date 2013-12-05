Namespace('Crossword').Puzzle = do ->
	placeOnGrid = (letters, x, y, dir) ->
		xi = 0
		yi = 0

		len = letters.length

		for i in [0..len-1] by 1
			puzzleGrid[x+xi] = {} if !puzzleGrid[x+xi]?
			if !puzzleGrid[x+xi][y+yi]?
				indexLetter(letters[i], x+xi, y+yi)
				puzzleGrid[x+i] = {} if !puzzleGrid[x+i]?
				puzzleGrid[x+xi][y+yi] = letters[i]

			if dir
				xi++
			else
				yi++

	indexLetter = (letter, x, y) ->
		charCode = letter.charCodeAt(0)

		if !letterIndex[charCode]?
			letterIndex[charCode] = []

		letterIndex[charCode].push({x:x,y:y})

	testFitWord = (word) ->
		match = []
		if word.length > 1
			letters = randArray(word)

			for i in [0..letters.length-1] by 1
				if (letters[i] != " ")
					matchArray = randArray(letterIndex[letters[i].charCodeAt(0)])
					if matchArray?
						for n in [0..matchArray.length-1] by 1
							# test across
							if (testFitWordAt(word, matchArray[n].x-i, matchArray[n].y, true))
								match = matchArray.splice(n,1)
								return { word: word, x: match[0].x-i, y: match[0].y, dir: true }
							# test down
							if (testFitWordAt(word, matchArray[n].x, matchArray[n].y-i, false))
								match = matchArray.splice(n,1)
								return { word: word, x: match[0].x, y: match[0].y-i, dir: false }
		false

	testFitWordAt = (word, tx, ty, across) ->
		if (across)
			puzzleGrid[tx-1] = {} if !puzzleGrid[tx-1]?
			puzzleGrid[tx+word.length] = {} if !puzzleGrid[tx + word.length]?
			return false if puzzleGrid[tx - 1][ty]? or puzzleGrid[tx+word.length][ty]?
		else
			puzzleGrid[tx-1] = {} if !puzzleGrid[tx-1]?
			return false if puzzleGrid[tx][ty-1]? or puzzleGrid[tx][ty+word.length]?
		
		# check spaces for existing words
		for curword in word
			puzzleGrid[tx] = {} if !puzzleGrid[tx]?

			if !puzzleGrid[tx][ty]?
				if across
					puzzleGrid[tx-1] = {} if !puzzleGrid[tx]?
					return false if puzzleGrid[tx][ty-1] or puzzleGrid[tx][ty+1]
				else
					puzzleGrid[tx-1] = {} if !puzzleGrid[tx-1]?
					puzzleGrid[tx+1] = {} if !puzzleGrid[tx+1]?
					return false if puzzleGrid[tx-1][ty]? or puzzleGrid[tx+1][ty]?
			else
				puzzleGrid[tx] = {} if !puzzleGrid[tx]?

				return false if puzzleGrid[tx][ty] != curword

				if across
					puzzleGrid[tx-1] = {} if !puzzleGrid[tx]?
					return false if !puzzleGrid[tx][ty-1]? and !puzzleGrid[tx][ty+1]?
				else
					puzzleGrid[tx-1] = {} if !puzzleGrid[tx-1]?
					puzzleGrid[tx+1] = {} if !puzzleGrid[tx+1]?
					return false if !puzzleGrid[tx-1][ty]? and !puzzleGrid[tx+1][ty]?

			if (across)
				tx++
			else
				ty++
		return true

	randArray = (t) ->
		return null if not t?

		w = []
		
		for item in t
			w.push(item)

		w2 = []
		while w.length > 0
			i = Math.floor(Math.random()*w.length)
			w2.push(w[i])
			w.splice(i,1)
		
		w2

	normalizeQSET = (qset) ->
		minX = 0
		minY = 0
		for i in [0..qset.length-1]
			minX = qset[i].options.x if qset[i].options.x < minX
			minY = qset[i].options.y if qset[i].options.y < minY

		for i in [0..qset.length-1]
			qset[i].options.x -= minX
			qset[i].options.y -= minY

	loopCount = 0
	loopLimit = 20
	attemptCount = 0
	letterIndex = []
	puzzleGrid = {}

	possibleItems = []
	iterationCount = 0

	generatePuzzle = (_items) ->
		possibleItems = []
		attemptCount = 0
		_generatePuzzle _items


	_generatePuzzle = (_items) ->
		letterIndex = []
		puzzleGrid = {}
		results = []
		loopCount = 0

		items = randArray(_items).slice(0)
		i = 0

		while !firstword? and items.length > 0
			item = items.pop()
			firstword = (item.answers[0].text)
			if !firstword? or firstword.length < 1
				firstword = null
			else
				item.options.dir = 1
				item.options.x = 0
				item.options.y = 0
				results.push item
				break

		if !firstword
			return

		placeOnGrid(firstword.toUpperCase().split(''), 0, 0, false)
		c = 1

		i = 1

		while (items.length > 0 and loopLimit > loopCount++)
			item = items.pop()

			if item.answers[0].text.length < 1
				continue

			result = testFitWord(item.answers[0].text.toUpperCase().split(''))
			
			if result
				placeOnGrid(result.word, result.x, result.y, result.dir)
				loopCount = 0
				item.options.x = result.x
				item.options.y = result.y
				if result.dir
					item.options.dir = 0
				else
					item.options.dir = 1
				c++
				results.push item
				
			else
				items.splice(0,0,item)
			i++

		normalizeQSET results

		# keep trying to find new ones, unless it fails 50 times, in which case
		# we assume there is no possible spot for every letter, and cut our losses
		if items.length == 0 || attemptCount++ > 50
			iterationCount++
			possibleItems.push results
		else
			puzzleGrid = {}
			_generatePuzzle(_items)

		if iterationCount < 9
			puzzleGrid = {}
			_generatePuzzle(_items)

		minDist = 9999
		best = null

		for i in [0..possibleItems.length-1]
			maxX = 0
			maxY = 0
			dist = 0
			for n in [0..possibleItems[i].length-1]
				letters = possibleItems[i][n].answers[0].text.split ''
				width = 0
				height = 0
				for j in [0..letters.length-1]
					if possibleItems[i][n].options.dir == 0
						width++
					else
						height++

				width += possibleItems[i][n].options.x
				height += possibleItems[i][n].options.y

				if possibleItems[i][n].options.dir == 0
					if width > dist
						dist = width
				else
					if height > dist
						dist = height
					
			if dist < minDist
				best = possibleItems[i]
				minDist = dist

		return best

	generatePuzzle: generatePuzzle
	normalizeQSET: normalizeQSET
