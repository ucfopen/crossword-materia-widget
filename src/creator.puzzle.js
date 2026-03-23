/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
Namespace('Crossword').Puzzle = (function() {

	// Initialize class variables

	let loopCount = 0;
	const loopLimit = 20;
	let maxPossible = 50;
	let attemptCount = 0;
	let letterIndex = [];
	let puzzleGrid = {};
	let possibleItems = [];
	let iterationCount = 0;
	let randomIndex = Math.random();
	const BOARD_SPAN_X = 17;
	const BOARD_SPAN_Y = 21;

	// Private methods

	// Letters is an array of letters (all caps)
	// (x,y) is the location of the first letter
	const _placeOnGrid = function(letters, x, y, dir) {
		let xi = 0;
		let yi = 0;

		for (let i = 0, end = letters.length; i < end; i++) {
			if ((puzzleGrid[x+xi] == null)) { puzzleGrid[x+xi] = {}; }
			if ((puzzleGrid[x+xi][y+yi] == null)) {
				_indexLetter(letters[i], x+xi, y+yi);
				if ((puzzleGrid[x+i] == null)) { puzzleGrid[x+i] = {}; }
				puzzleGrid[x+xi][y+yi] = letters[i];
			}

			if (dir) {
				xi++;
			} else {
				yi++;
			}
		}

	};

	var _indexLetter = function(letter, x, y) {
		const charCode = letter.charCodeAt(0);

		if ((letterIndex[charCode] == null)) {
			letterIndex[charCode] = [];
		}

		return letterIndex[charCode].push({x, y});
	};

	const _testFitWord = function(word) {
		let match = [];
		if (word.length > 1) {
			// for each letter in the word
			for (let i = 0, end = word.length; i < end; i++) {
				if (word[i] === " ") { continue; }
				// locations where this word can intersect at this letter
				var matchArray = _randArray(letterIndex[word[i].charCodeAt(0)]);
				if (matchArray != null) {
					for (var n = 0, end1 = matchArray.length; n < end1; n++) {
						// test across
						if (_testFitWordAt(word, matchArray[n].x-i, matchArray[n].y, true)) {
							match = matchArray.splice(n,1);
							return { word, x: match[0].x-i, y: match[0].y, dir: true };
						}
						// test down
						if (_testFitWordAt(word, matchArray[n].x, matchArray[n].y-i, false)) {
							match = matchArray.splice(n,1);
							return { word, x: match[0].x, y: match[0].y-i, dir: false };
						}
					}
				}
			}
		}
		return false;
	};

	// test to see if word fits if it starts at (tx, ty)
	var _testFitWordAt = function(word, tx, ty, across) {
		// check the spaces right before and after the word
		if ((puzzleGrid[tx-1] == null)) { puzzleGrid[tx-1] = {}; }
		if (across) {
			if ((puzzleGrid[tx + word.length] == null)) { puzzleGrid[tx+word.length] = {}; }
			if ((puzzleGrid[tx - 1][ty] != null) || (puzzleGrid[tx+word.length][ty] != null)) { return false; }
		} else {
			if ((puzzleGrid[tx][ty-1] != null) || (puzzleGrid[tx][ty+word.length] != null)) { return false; }
		}

		// check spaces for existing words
		for (var letter of Array.from(word)) {
			if ((puzzleGrid[tx] == null)) { puzzleGrid[tx] = {}; }

			if ((puzzleGrid[tx][ty] == null)) {
				// if there's not already a letter in that location
				// don't allow there to be a letter adjacent to this word in the other direction
				if (across) {
					if (puzzleGrid[tx][ty-1] || puzzleGrid[tx][ty+1]) { return false; }
				} else {
					if ((puzzleGrid[tx-1][ty] != null) || (puzzleGrid[tx+1][ty] != null)) { return false; }
				}
			} else {
				// if there is already a letter in that location
				// make sure it is the right letter
				if (puzzleGrid[tx][ty] !== letter) { return false; }
				// and make sure the letter there is an intersection, not an inline collision
				if (across) {
					if ((puzzleGrid[tx][ty-1] == null) && (puzzleGrid[tx][ty+1] == null)) { return false; }
				} else {
					if ((puzzleGrid[tx-1][ty] == null) && (puzzleGrid[tx+1][ty] == null)) { return false; }
				}
			}

			if (across) {
				tx++;
			} else {
				ty++;
			}
		}
		return true;
	};

	var _randArray = function(t) {
		if ((t == null)) { return null; }

		const w = [];
		for (var item of Array.from(t)) {
			w.push(item);
		}

		const w2 = [];
		while (w.length > 0) {
			var i = Math.floor(_fakeRandom() * 10000) % w.length;
			w2.push(w[i]);
			w.splice(i,1);
		}

		return w2;
	};

	var _fakeRandom = () => randomIndex;

	var _generatePuzzle = function(_items, force) {
		let firstword, item;
		letterIndex = [];
		puzzleGrid = {};
		let results = [];
		loopCount = 0;

		const items = _randArray(_items).slice(0);

		while ((firstword == null) && (items.length > 0)) {
			item = items.pop();
			firstword = (item.answers[0].text);
			if ((firstword == null) || (firstword.length < 2)) {
				firstword = null;
			} else {
				item.options.dir = 1;
				item.options.x = 0;
				item.options.y = 0;
				results.push(item);
				break;
			}
		}

		if (!firstword) {
			return false;
		}

		_placeOnGrid(firstword.toUpperCase().split(''), 0, 0, false);

		while ((items.length > 0) && (loopLimit > loopCount++)) {
			item = items.pop();

			if (item.answers[0].text.length < 1) {
				continue;
			}

			var result = _testFitWord(item.answers[0].text.toUpperCase().split(''));

			if (result) {
				_placeOnGrid(result.word, result.x, result.y, result.dir);
				loopCount = 0;
				item.options.x = result.x;
				item.options.y = result.y;
				if (result.dir) {
					item.options.dir = 0;
				} else {
					item.options.dir = 1;
				}
				results.push(item);

			} else {
				items.splice(0,0,item);
			}
		}

		results = normalizeQSET(results);

		// keep trying to find new ones, unless it fails 50 times, in which case
		// we assume there is no possible spot for every letter, and cut our losses
		if ((items.length === 0) || (attemptCount++ > 50)) {
			iterationCount++;
			possibleItems.push(results);
			// quickly return if this is a valid solution
			if (!force && (items.length === 0)) {
				return centerPuzzle(results);
			}
		}

		if (iterationCount < maxPossible) {
			resetRandom();
			return _generatePuzzle(_items, force);
		}


		let minArea = 9999;
		let maxWords = 0;
		const bestList = []; // stringify'ed version of the best boards

		// for each board
		for (var board of Array.from(possibleItems)) {
			var maxX = 1;
			var maxY = 1;
			var area = 0;
			// loop through all the words, and find the maxX and maxY
			for (var n = 0, end = board.length; n < end; n++) {
				if (board[n].options.dir === 0) {
					var width = board[n].options.x + board[n].answers[0].text.length;
					if (width > maxX) { maxX = width; }
				} else {
					var height = board[n].options.y + board[n].answers[0].text.length;
					if (height > maxY) { maxY = height; }
				}
			}

			// maximize the number of words on the board
			if (board.length > maxWords) {
				maxWords = board.length;
				minArea = 9999;
			}
			if (board.length === maxWords) {
				// update the best if it has a smaller area, or it has the same
				// area where the board is taller than it is wide
				area = maxX * maxY;
				if ((area < minArea) || ((area === minArea) && (maxX < maxY))) {
					bestList.push(JSON.stringify(board));
					minArea = area;
				}
			}
		}

		// the `bestList` progressively gets better, so pick the first (from the
		// back) that isn't the same as the current board (_items)
		bestList.reverse();
		let best = bestList[0];
		const _itemsString = JSON.stringify(_items);
		for (var b of Array.from(bestList)) {
			if (_itemsString !== b) {
				best = b;
			}
		}

		return centerPuzzle(JSON.parse(best));
	};

	// Public methods

	const generatePuzzle = function(_items, force) {
		possibleItems = [];
		attemptCount = 0;
		iterationCount = 0;
		maxPossible = (_items.length * _items.length) + 10;
		return _generatePuzzle(_items, force);
	};

	var resetRandom = () => randomIndex = Math.random();

	var normalizeQSET = function(qset) {
		let i, minY;
		let end;
		let end1;
		let minX = (minY = 0);

		for (i = 0, end = qset.length; i < end; i++) {
			qset[i].options.x = ~~qset[i].options.x;
			qset[i].options.y = ~~qset[i].options.y;

			if (qset[i].options.x < minX) { minX = qset[i].options.x; }
			if (qset[i].options.y < minY) { minY = qset[i].options.y; }
		}

		for (i = 0, end1 = qset.length; i < end1; i++) {
			qset[i].options.x -= minX;
			qset[i].options.y -= minY;
		}

		// return a deep copy of the object
		return JSON.parse(JSON.stringify(qset));
	};

	var centerPuzzle = function(qset) {
		let i, maxY;
		let end;
		let end1;
		let maxX = (maxY = 0);

		// find the letters furthest away from the origin
		for (i = 0, end = qset.length; i < end; i++) {
			var {
                dir
            } = qset[i].options;
			var endX = qset[i].options.x + ( qset[i].answers[0].text.length * ~~(!dir) );
			var endY = qset[i].options.y + ( qset[i].answers[0].text.length * ~~(dir) );
			if (endX > maxX) { maxX = endX; }
			if (endY > maxY) { maxY = endY; }
		}

		let xShift = Math.floor((BOARD_SPAN_X - maxX) / 2);
		let yShift = Math.floor((BOARD_SPAN_Y - maxY) / 2);

		if (xShift < 0) { xShift = 0; }
		if (yShift < 0) { yShift = 0; }

		for (i = 0, end1 = qset.length; i < end1; i++) {
			qset[i].options.x += xShift;
			qset[i].options.y += yShift;
		}

		return qset;
	};

	// Return public methods
	return {
		generatePuzzle,
		normalizeQSET,
		resetRandom
	};
})();
