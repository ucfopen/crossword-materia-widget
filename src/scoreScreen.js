/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
Namespace('Crossword').ScoreScreen = (function() {
	// variables to store widget data in this scope
	let _qset                 = null;
	let _questions            = null;
	let _scoreTable           = null;
	let _puzzleGrid           = {};

	// two words can start at the same point and share a numberlabel
	// key is string of location, value is the number label to use/share at that location
	let _wordMapping          = {};
	let _labelIndexShift      = 0;
	// stores all intersections, key is location, value is list where index is direction
	let _wordIntersections    = {};

	// board drag state
	let _boardMouseDown       = false;
	let _boardMoving          = false;
	let _mouseYAnchor         = 0;
	let _mouseXAnchor         = 0;
	let _puzzleY              = 0;
	let _puzzleX              = 0;

	let _puzzleHeightOverflow = 0;
	let _puzzleWidthOverflow  = 0;
	let _puzzleLetterHeight   = 0;
	let _puzzleLetterWidth    = 0;

	let _movableEase          = 0;

	// the current typing direction
	const _curDir               = -1;
	// saved previous typing direction
	const _prevDir              = 0;
	// the current letter that is highlighted
	let _curLetter            = false;
	// the current clue that is highlighted
	let _curClue			  = -1;

	// cache DOM elements for performance
	const _domCache             = {};
	let _boardDiv             = null; // div containing the board
	let _contDiv              = null; // parent div of _boardDiv

	// these are the allowed user input
	const _allowedInput         = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','Á','À','Â','Ä','Ã','Å','Æ','Ç','É','È','Ê','Ë','Í','Ì','Î','Ï','Ñ','Ó','Ò','Ô','Ö','Õ','Ø','Œ','ß','Ú','Ù','Û','Ü'];

	let _isMobile             = false;
	let _zoomedIn             = false;

	// constants
	const MOBILE_PX             = 576; // in px., mobile breakpoint size
	const LETTER_HEIGHT         = 23;  // how many pixles high is a space?
	const LETTER_WIDTH          = 27;  // how many pixles wide is a space?
	const VERTICAL              = 1;   // used to compare dir == 1 or dir == VERTICAL
	const BOARD_WIDTH           = 560; // visible board width, minus space for
	const BOARD_HEIGHT          = 550; // visible board height, minus space for zoom button
	const BOARD_LETTER_WIDTH    = Math.floor(BOARD_WIDTH / LETTER_WIDTH);
	const BOARD_LETTER_HEIGHT   = Math.floor(BOARD_HEIGHT / LETTER_HEIGHT);

		// width of the scaled game container
	const _contWidth = () => parseFloat(_contDiv.width());

	// height of the scaled game container
	const _contHeight = () => parseFloat(_contDiv.height());

	// width of crossword map extent
	const _mapWidth = () => parseFloat(_boardDiv.width());

	// height of crossword map extent
	const _mapHeight = () => parseFloat(_boardDiv.height());

	// size of the margin centering the map in the X direction
	const _mapXMargin = () => parseFloat(_boardDiv.css("margin-left").replace("px",""));

	// size of the margin centering the map in the Y direction
	const _mapYMargin = () => parseFloat(_boardDiv.css("margin-top").replace("px",""));

	// get the map's padding, assuming it is uniform
	const _mapPadding = () => Math.abs(_boardDiv.width() - _boardDiv.innerWidth()) / 2;

	// get the map's border, assuming it is uniform
	const _mapBorder = () => (_boardDiv.outerWidth() - _boardDiv.innerWidth()) / 2;

	// Centers the board
	const _centerBoard = function() {
		_boardDiv.css('margin-left', (_contWidth() - _boardDiv.outerWidth()) / 2);
		return _boardDiv.css('margin-top', (_contHeight() - _boardDiv.outerHeight()) / 2);
	};

	const _rescaleVars = function() {
		_puzzleWidthOverflow = _boardDiv.outerWidth() - _contWidth();
		return _puzzleHeightOverflow = _boardDiv.outerHeight() - _contHeight();
	};

	const _updateIsMobile = function() {
		const newMobile = $(window).width() < MOBILE_PX;
		if (newMobile !== _isMobile) {
			_isMobile = newMobile;
			if (!newMobile) { // mobile -> desktop
				_contDiv.css("height", "calc(100%)");
				_contDiv.css("top", "0px");
				return $('#clues').css("height", "auto");
			} else { // desktop -> mobile
				_contDiv.css("height", "calc(100% - 150px)");
				_contDiv.css("top", "150px");
				return setTimeout(()=>_updateClue(true), 400);
			}
		}
	};
		

	// Called by Materia.ScoreCore when your widget ScoreCore should start the user experience.
	const start = function(instance, qset, scoreTable, isPreview, version) {
		// if we're on a mobile device, some event listening will be different
		if (version == null) { version = '1'; }
		_isMobile = $(window).width() < MOBILE_PX;
		if (_isMobile) {
			$('#movable-container').css("height", "calc(100% - 150px)");
			$('#movable-container').css("top", "150px");
			$('#clues').css("height", parseInt($('#clue_'+_curClue).outerHeight(true)));
			document.ontouchmove = e => e.preventDefault();
		}

		// store widget data
		_qset = qset;
		_scoreTable = scoreTable;

		// easy access to questions
		_questions = _qset.items[0].items;
		_boardDiv = $('#movable');
		_contDiv = $('#movable-container');

		// clean qset variables
		forEveryQuestion(function(i, letters, x, y, dir, response) {
			_questions[i].options.x = ~~_questions[i].options.x;
			_questions[i].options.y = ~~_questions[i].options.y;
			return _questions[i].options.dir = ~~_questions[i].options.dir;
		});

		const puzzleSize = _measureBoard(_questions);
		_scootWordsBy(puzzleSize.minX, puzzleSize.minY, _questions); // normalize the qset coordinates

		_puzzleLetterWidth  = puzzleSize.width;
		_puzzleLetterHeight = puzzleSize.height;
		_puzzleWidthOverflow = (_puzzleLetterWidth * LETTER_WIDTH) - _contWidth();
		_puzzleHeightOverflow = (_puzzleLetterHeight * LETTER_HEIGHT) - _contHeight();

		_curLetter = { x: _questions[0].options.x, y:_questions[0].options.y };

		// render the widget, hook listeners, update UI
		_drawBoard();
		_animateToShowBoardIfNeeded();
		_setupEventHandlers();
		setTimeout(()=>_updateClue(true), 100);
		return Materia.ScoreCore.setHeight();
	};

	// Called by Materia.ScoreCore when user switches score attempt
	const update = function(qset, scoreTable) {
		// if we're on a mobile device, some event listening will be different
		_isMobile = $(window).width() < MOBILE_PX;
		if (_isMobile) {
			$('#movable-container').css("height", "calc(100% - 150px)");
			document.ontouchmove = e => e.preventDefault();
		}
		
		if (!_qset || !isConsistentQset(qset)) {
			return redrawBoard(qset, scoreTable);
		}

		_qset = qset;
		const answersShown = $('#hide-correct')[0].checked;
		$('.letter').removeClass('correct incorrect');
		return forEveryQuestion((i, letters, x, y, dir, response) => forEveryLetter(x, y, dir, letters, response, function(left, top, l) {
            const letterElement = $(`#letter_${left}_${top}`)[0];
            const classColor = letters[l] === response[l] ? 'correct' : 'incorrect';
            const protectedSpace = _allowedInput.indexOf(letters[l].toUpperCase()) === -1;
            if (!protectedSpace) { letterElement.classList.add(classColor); }
            if (!answersShown) { return letterElement.innerHTML = response[l]; }
        }));
	};


	var isConsistentQset = newQset => newQset.id === _qset.id;

	// getElementById and cache it, for the sake of performance
	const _dom = id => _domCache[id] || (_domCache[id] = document.getElementById(id));

	// measurements are returned in letter coordinates
	// 5 is equal to 5 letters, not pixels
	var _measureBoard = function(qset) {
		let maxX, maxY, minY;
		let minX = (minY = (maxX = (maxY = 0)));

		for (var word of Array.from(qset)) {
			// compare first letter coordinates
			// store minimum values
			var wordMaxX, wordMaxY;
			var option = word.options;
			if (option.x < minX) { minX = option.x; }
			if (option.y < minY) { minY = option.y; }

			// find last letter coordinates
			if (option.dir === VERTICAL) {
				wordMaxX = option.x + 1;
				wordMaxY = option.y + word.answers[0].text.length;
			} else {
				wordMaxX = option.x + word.answers[0].text.length;
				wordMaxY = option.y + 1;
			}

			// store maximum values
			if (wordMaxY > maxY) { maxY = wordMaxY; }
			if (wordMaxX > maxX) { maxX = wordMaxX; }
		}

		const width  = maxX - minX;
		const height = maxY - minY;

		return {minX, minY, maxX, maxY, width, height};
	};

	// shift word coordinates to normalize to 0, 0
	// TODO this currently never does anything since `qset` isn't a thing
	var _scootWordsBy = function(x, y) {
		if ((x !== 0) || (y !== 0)) {
			return (() => {
				const result = [];
				for (var word of Array.from(qset)) {
					word.options.x = word.options.x - x;
					result.push(word.options.y = word.options.y - y);
				}
				return result;
			})();
		}
	};

	// set up listeners on UI elements
	var _setupEventHandlers = function() {
		// control window scaling
		$(window).on('resize', function() {
			_updateIsMobile();
			_centerBoard();
			_rescaleVars();
			return _limitBoardPosition();
		});

		// keep focus on the last letter that was highlighted whenever we move the board around
		$('#board').click(() => _highlightPuzzleLetter(false));

		$('#zoomout').click(_zoomOut);
		$('#hide-correct').change(_toggleAnswers);

		document.getElementById('board').addEventListener('mousedown', _mouseDownHandler);
		document.getElementById('board').addEventListener('mousemove', _mouseMoveHandler);
		return document.addEventListener('mouseup', _mouseUpHandler);
	};

	const _navPrevQ = function() {
		const i = (_curClue - 1) < 0 ? _questions.length - 1 : _curClue - 1;
		return _clueMouseUp({target: $('#clue_'+i)[0]});
	};

	const _navNextQ = function() {
		const i = (_curClue + 1) % _questions.length;
		return _clueMouseUp({target: $('#clue_'+i)[0]});
	};

	// start dragging
	var _mouseDownHandler = function(e) {
		const context = _isMobile ? e.pointers[0] : e;

		if ((context.clientX > 515) || !_zoomedIn) { return; }

		_boardMouseDown = true;
		_mouseYAnchor = context.clientY;
		return _mouseXAnchor = context.clientX;
	};

	// start dragging the board when the mousedown occurs
	// coordinates are relative to where we start
	var _mouseMoveHandler = function(e) {
		if (!_boardMouseDown) { return; }
		_boardMoving = true;

		const context = _isMobile ? e.pointers[0] : e;

		_puzzleY += (context.clientY - _mouseYAnchor);
		_puzzleX += (context.clientX - _mouseXAnchor);

		// if its out of range, stop panning
		_limitBoardPosition();

		_mouseYAnchor = context.clientY;
		_mouseXAnchor = context.clientX;

		const m = _dom('movable');
		m.style.top = _puzzleY + 'px';
		m.style.left = _puzzleX + 'px';

		if (_isMobile) { return false; }
	};

	// stop dragging
	var _mouseUpHandler = e => _boardMouseDown = false;

	// limits board position to prevent going off into oblivion (down and right)
	var _limitBoardPosition = function() {

		// Sign variables flip collision behavior 
		// based on if the map is larger or smaller than the screen

		// when overflow is negative, the map should be blocked by the screen edge
		// when overflow is positive, the map should be allowed to be panned past the edge
		const wSign = -Math.abs(_puzzleWidthOverflow) / _puzzleWidthOverflow;
		const hSign = -Math.abs(_puzzleHeightOverflow) / _puzzleHeightOverflow;

		if (_puzzleX < (wSign*(_puzzleWidthOverflow/2))) { _puzzleX = wSign*(_puzzleWidthOverflow/2); }
		if (_puzzleX > (-wSign*(_puzzleWidthOverflow/2))) { _puzzleX = -wSign*(_puzzleWidthOverflow/2); }

		if (_puzzleY < (hSign*(_puzzleHeightOverflow/2))) { _puzzleY = hSign*(_puzzleHeightOverflow/2); }
		if (_puzzleY > (-hSign*(_puzzleHeightOverflow/2))) { return _puzzleY = -hSign*(_puzzleHeightOverflow/2); }
	};

	// Draw the main board.
	var _drawBoard = function() {
		// used to track the maximum dimensions of the puzzle
		const _top = 0;

		// tracks horizontal and vertical extent of the puzzle
		// origin is top-left, in units of letters
		let maxLetterX = 0;
		let maxLetterY = 0;

		// generate elements for questions
		forEveryQuestion(function(i, letters, x, y, dir, response, hinted) {
			let intersection;
			const questionText   = _questions[i].questions[0].text;

			let location = "" + x + y;
			const questionNumber = (~~i + 1) - _labelIndexShift;
			if (!_wordMapping.hasOwnProperty(location)) {
				_wordMapping[location] = questionNumber;
				_renderNumberLabel(_wordMapping[location], x, y);
			} else {
				intersection = [questionNumber, _wordMapping[location]];
				if (_questions[i].options.dir) { intersection.reverse(); }
				_wordIntersections[location] = intersection;
				_labelIndexShift += 1;
			}
			const hintPrefix = _wordMapping[location] + (dir ? ' down' : ' across');
			_renderClue(questionText, letters.join(''), hintPrefix, i, dir);

			return forEveryLetter(x, y, dir, letters, response, function(letterLeft, letterTop, l) {
				// overlapping connectors should not be duplicated
				if ((_puzzleGrid[letterTop] != null) && (_puzzleGrid[letterTop][letterLeft] === letters[l])) {
					// keep track of overlaps and store in _wordIntersections
					const intersectedElement = _dom(`letter_${letterLeft}_${letterTop}`);
					if (hinted) { intersectedElement.classList.add('hinted'); }
					const intersectedQuestion = ~~intersectedElement.getAttribute("data-q") + 1;

					location = "" + letterLeft + letterTop;
					intersection = [~~i + 1, intersectedQuestion];
					if (_questions[i].options.dir) { intersection.reverse(); }
					_wordIntersections[location] = intersection;

					return;
				}

				const protectedSpace = _allowedInput.indexOf(letters[l].toUpperCase()) === -1;

				// each letter is a div with coordinates as id
				const letterElement = document.createElement('div');
				letterElement.id = `letter_${letterLeft}_${letterTop}`;
				letterElement.classList.add('letter');
				if (hinted) { letterElement.classList.add('hinted'); }
				const classColor = letters[l] === response[l] ? 'correct' : 'incorrect';
				letterElement.classList.add(classColor);
				letterElement.setAttribute('readonly', true);
				letterElement.setAttribute('data-q', i);
				letterElement.setAttribute('data-dir', dir);
				letterElement.onclick = _letterClicked;

				letterElement.style.top = (letterTop * LETTER_HEIGHT) + _mapPadding() + 'px';
				letterElement.style.left = (letterLeft * LETTER_WIDTH) + _mapPadding() + 'px';
				letterElement.innerHTML = response[l];

				// if it's not a guessable char, display the char
				if (protectedSpace) {
					letterElement.innerHTML = letters[l];
					letterElement.classList.remove(classColor);
					// Black block for spaces
					if (letters[l] === ' ') { letterElement.style.backgroundColor = '#000'; }
				}

				// init the puzzle grid for this row and letter
				if ((_puzzleGrid[letterTop] == null)) { _puzzleGrid[letterTop] = {}; }
				_puzzleGrid[letterTop][letterLeft] = letters[l];

				// track board extent
				if (letterLeft > maxLetterX) {
					maxLetterX = letterLeft;
				}

				if (letterTop > maxLetterY) {
					maxLetterY = letterTop;
				}

				return _boardDiv.append(letterElement);
			});
		});

		// update board sizing
		// +1 accounts for x/y values starting at 0
		const newWidth = (maxLetterX + 1) * LETTER_WIDTH;
		const newHeight = (maxLetterY + 1) * LETTER_HEIGHT;
		_boardDiv.css('width', newWidth);
		_boardDiv.css('height', newHeight);

		return _centerBoard();
	};

	var redrawBoard = function(qset, scoreTable) {
		_qset = qset;
		_scoreTable = scoreTable;
		_boardDiv = $("#movable");
		_questions = _qset.items[0].items;
		forEveryQuestion(function(i, letters, x, y, dir, response) {
			_questions[i].options.x = ~~_questions[i].options.x;
			_questions[i].options.y = ~~_questions[i].options.y;
			return _questions[i].options.dir = ~~_questions[i].options.dir;
		});

		const puzzleSize = _measureBoard(_questions);
		_scootWordsBy(puzzleSize.minX, puzzleSize.minY, _questions); // normalize the qset coordinates

		_puzzleLetterWidth  = puzzleSize.width;
		_puzzleLetterHeight = puzzleSize.height;
		_puzzleWidthOverflow = (_puzzleLetterWidth * LETTER_WIDTH) - BOARD_WIDTH;
		_puzzleHeightOverflow = (_puzzleLetterHeight * LETTER_HEIGHT) - BOARD_HEIGHT;

		_curLetter = { x: _questions[0].options.x, y:_questions[0].options.y };

		// reset everything
		$('#clues').empty();
		$('#movable').empty();
		_puzzleGrid = {};
		_wordMapping = {};
		_labelIndexShift = 0;
		_wordIntersections = {};

		_drawBoard();
		_animateToShowBoardIfNeeded();
		return _setupEventHandlers();
	};

	// zoom animation if dimensions are off screen
	var _animateToShowBoardIfNeeded = function() {
		if ((_puzzleLetterWidth > BOARD_LETTER_WIDTH) || (_puzzleLetterHeight > BOARD_LETTER_HEIGHT)) {
			_zoomOut();

			return setTimeout(() => _zoomIn()
			, 2500);
		}
	};

	var _zoomOut = function() {
		const puzzlePixelHeight = _puzzleLetterHeight * LETTER_HEIGHT;
		const puzzlePixelWidth  = _puzzleLetterWidth * LETTER_WIDTH;

		// x = pixelHeight / visibleDivHeight
		// 5 = 2000 / 400
		const heightScaleFactor = puzzlePixelHeight / BOARD_HEIGHT;
		const widthScaleFactor = puzzlePixelWidth / BOARD_WIDTH;

		// find the biggest scale factor
		const scaleFactor =  1 / Math.max(widthScaleFactor, heightScaleFactor);

		// translate values need to take scale into account
		const translateX = -_puzzleX / scaleFactor;
		const translateY = -_puzzleY / scaleFactor;

		const trans = `scale(${scaleFactor}) translate(${translateX}px, ${translateY}px)`;
		_boardDiv
			.css('-webkit-transform', trans)
			.css('-moz-transform', trans)
			.css('transform', trans);
		return _zoomedIn = false;
	};

	var _zoomIn = function() {
		const trans = '';
		_boardDiv.css('-webkit-transform', trans)
			.css('-moz-transform', trans)
			.css('transform', trans);
		return _zoomedIn = true;
	};

	// remove letter focus class from the current letter
	const _removePuzzleLetterHighlight = function() {
		const g = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);
		if (g != null) { return g.classList.remove('focus'); }
	};

	// apply highlight class
	var _highlightPuzzleLetter = function(animate) {
		if (animate == null) { animate = true; }
		const highlightedLetter = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);

		if (!_zoomedIn) { _zoomIn(); }

		if (highlightedLetter) {
			highlightedLetter.classList.add('focus');
			highlightedLetter.focus();

			// figure out if the _curLetter is on the screen
			const letterX = _curLetter.x * LETTER_WIDTH;
			const letterY = _curLetter.y * LETTER_HEIGHT;

			const isOffBoardX = (letterX > _puzzleX) || (letterX < (_puzzleX + BOARD_WIDTH));
			const isOffBoardY = (letterY > _puzzleY) || (letterY < (_puzzleY + BOARD_HEIGHT));

			const m = _dom('movable');

			if (!_boardMoving && (isOffBoardX || isOffBoardY)) {
				if (isOffBoardX) {
					_puzzleX = (-_curLetter.x * LETTER_WIDTH) + 100;
				}

				if (isOffBoardY) {
					_puzzleY = (-_curLetter.y * LETTER_HEIGHT) + 100;
				}

				if (animate) {
					m.classList.add('animateall');
				}

				clearTimeout(_movableEase);

				_movableEase = setTimeout(() => m.classList.remove('animateall')

				, 1000);
			}

			_limitBoardPosition();
			_boardMoving = false;

			m.style.top  = _puzzleY + 'px';
			return m.style.left = _puzzleX + 'px';
		}
	};

	// update which clue is highlighted and scrolled to on the side list
	var _updateClue = function(animate) {
		if (animate == null) { animate = true; }
		const highlightedLetter = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);

		if (highlightedLetter) {
			const clue = _dom('clue_'+highlightedLetter.getAttribute('data-q'));
			_curClue = parseInt(highlightedLetter.getAttribute('data-q'));
			// if it's already highlighted, do not try to scroll to it
			if (!_isMobile && clue.classList.contains('highlight')) {
				console.log("highlight return");
				return;
			}

			// remove the highlight from all others
			for (var j in _questions) {
				_dom('clue_'+j).classList.remove('highlight');
			}

			const scrolly = clue.offsetTop;
			clue.classList.add('highlight');

			$('#clues').stop(true);
			if (animate) {
				$('#clues').animate({scrollTop: scrolly}, _isMobile ? 0 : 150);
			}

			if (_isMobile) {
				console.log(_curClue, parseInt($('#clue_'+_curClue).outerHeight(true)) + "px");
				return $('#clues').css("height", parseInt($('#clue_'+_curClue).outerHeight(true)) + "px");
			}
		}
	};

	// highlight the clicked letter and set up direction
	var _letterClicked = function(e, animate) {
		if (animate == null) { animate = true; }
		if ((e == null)) { e = window.event; }
		const target = e.target || e.srcElement;

		// event bubble, or clicked on a non-editable space
		if (!target || (target.getAttribute('data-protected') != null)) { return; }

		// parse out the coordinates from the element id
		const s = target.id.split('_');

		_removePuzzleLetterHighlight();
		_curLetter = { x: ~~s[1], y:~~s[2] };
		const location = "" + ~~s[1] + ~~s[2];

		_highlightPuzzleWord((target).getAttribute('data-q'));

		_highlightPuzzleLetter(true);

		return _updateClue(animate);
	};

	// highlight a word (series of letters)
	var _highlightPuzzleWord = function(index) {
		// remove highlights
		$(".highlight").removeClass("highlight");
		// and add it to the ones we care about
		return forEveryQuestion(function(i, letters, x, y, dir, response) {
			if (~~i === ~~index) {
				return forEveryLetter(x,y,dir,letters,response, function(letterLeft, letterTop) {
					const l = _dom(`letter_${letterLeft}_${letterTop}`);
					if (l != null) {
						return l.classList.add('highlight');
					}
				});
			}
		});
	};

	var _toggleAnswers = function(e) {
		if ((e == null)) { e = window.event; }
		if (e.target.checked) {
			$('.letter').addClass('neutral');
			return forEveryQuestion((i, letters, x, y, dir, response) => forEveryLetter(x, y, dir, letters, response, (left, top, l) => $(`#letter_${left}_${top}`)[0].innerHTML = letters[l]));
		} else {
			$('.letter').removeClass('neutral');
			return forEveryQuestion((i, letters, x, y, dir, response) => forEveryLetter(x, y, dir, letters, response, (left, top, l) => $(`#letter_${left}_${top}`)[0].innerHTML = response[l]));
		}
	};

	// hide it
	const _hideAlert = function() {
		_dom('alertbox').classList.remove('show');
		return _dom('backgroundcover').classList.remove('show');
	};

	// draw a number label to identify the question
	var _renderNumberLabel = function(questionNumber, x, y) {
		const numberLabel = document.createElement('div');
		numberLabel.innerHTML = questionNumber;
		numberLabel.classList.add('numberlabel');
		numberLabel.style.top = (y * LETTER_HEIGHT) + _mapPadding() + 'px';
		numberLabel.style.left = (x * LETTER_WIDTH) + _mapPadding() + 'px';
		numberLabel.onclick = () => _letterClicked({target: $(`#letter_${x}_${y}`)[0]});
		return _boardDiv.append(numberLabel);
	};

	// draw the clue from template html
	var _renderClue = function(question, answer, hintPrefix, i, dir) {
		const clue = document.createElement('div');
		clue.id = 'clue_' + i;

		clue.innerHTML = $('#t_hints').html()
			.replace(/{{hintPrefix}}/g, hintPrefix)
			.replace(/{{question}}/g, question)
			.replace(/{{answer}}/g, answer)
			.replace(/{{i}}/g, i)
			.replace(/{{dir}}/g, dir);

		clue.setAttribute('data-i', i);
		clue.setAttribute('data-dir', dir);
		clue.classList.add('clue');

		clue.onmouseover = _clueMouseOver;
		clue.onmouseout  = _clueMouseOut;
		clue.onmouseup   = _clueMouseUp;
		
		$('#clues').append(clue);

		_dom('prevQ_' + i).addEventListener('click', _navPrevQ);
		return _dom('nextQ_' + i).addEventListener('click', _navNextQ);
	};

	var _clueMouseUp = function(e) {
		if ((e == null)) { e = window.event; }

		// click on the first letter of the word
		const i = e.target.getAttribute('data-i');
		let {
            x
        } = _questions[i].options;
		let {
            y
        } = _questions[i].options;
		const {
            dir
        } = _questions[i].options;
		const len = _questions[i].answers[0].text.length;
		const last = (len + ( dir ? y : x )) - 1;

		// if the first letter of the word is at an intersection, use the second letter
		let location = "" + x + y;
		while (_wordIntersections.hasOwnProperty(location)) {
			if (dir) {
				if (y < last) { y++; } else { break; }
			} else {
				if (x < last) { x++; } else { break; }
			}
			location = "" + x + y;
		}

		const firstLetter = $(`#letter_${x}_${y}`)[0];
		return _letterClicked({ target: firstLetter }, true);
	};

	// highlight words when a clue is moused over, to correspond what the user is seeing
	var _clueMouseOver = function(e) {
		if ((e == null)) { e = window.event; }
		return _highlightPuzzleWord((e.target || e.srcElement).getAttribute('data-i'));
	};

	var _clueMouseOut = e => _highlightPuzzleWord(-1);

	// loop iteration functions to prevent redundancy
	var forEveryLetter = (x, y, dir, letters, response, cb) => (() => {
        const result = [];
        for (let l = 0, end = letters.length, asc = 0 <= end; asc ? l < end : l > end; asc ? l++ : l--) {
            var letterLeft, letterTop;
            if (dir === VERTICAL) {
                letterLeft = x;
                letterTop  = y + l;
            } else {
                letterLeft = x + l;
                letterTop  = y;
            }
            result.push(cb(letterLeft, letterTop, l));
        }
        return result;
    })();

	var forEveryQuestion = callBack => (() => {
        const result = [];
        for (var i in _questions) {
            var letters  = _questions[i].answers[0].text.toUpperCase().split('');
            var {
                x
            } = _questions[i].options;
            var {
                y
            } = _questions[i].options;
            var {
                dir
            } = _questions[i].options;
            var response = _scoreTable[i].data[1].toUpperCase();
            var hinted   = _scoreTable[i].feedback === "Hint Received";
            result.push(callBack(i, letters, x, y, dir, response, hinted));
        }
        return result;
    })();

	// return public stuff for Materia

	return {
		manualResize: true,
		start,
		update
	};
})();
