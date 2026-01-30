/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
Namespace('Crossword').Engine = (function() {
	// variables to store widget data in this scope
	let _qset                 = null;
	let _questions            = null;
	const _usedHints            = [];
	const _usedFreeWords        = [];
	let _freeWordsRemaining   = 0;
	const _puzzleGrid           = {};
	let _instance             = {};

	// two words can start at the same point and share a numberlabel
	// key is string of location, value is the number label to use/share at that location
	const _wordMapping          = {};
	let _labelIndexShift      = 0;
	// stores all intersections, key is location, value is list where index is direction
	const _wordIntersections    = {};

	// board drag state
	let _boardMouseDown       = false;
	let _boardMoving          = false;
	let _mouseYAnchor         = 0;
	let _mouseXAnchor         = 0;
	let _puzzleY              = 0;
	let _puzzleX              = 0;

	// amount in pixels that the board overflows the window by
	// negative means the window is larger than the board
	let _puzzleHeightOverflow = 0;
	let _puzzleWidthOverflow  = 0;

	let _puzzleLetterHeight   = 0;
	let _puzzleLetterWidth    = 0;

	let _movableEase          = 0;

	// the current typing direction
	let _curDir               = -1;
	// saved previous typing direction
	let _prevDir              = 0;
	// the current letter that is highlighted
	let _curLetter            = false;
	// the current clue that is selected
	let _curClue              = 0;
	// tracks the cursor state associated with the down arrow key when the board is focused
	// 0 = board selected, 1 = hint button selected, 2 = free word button selected
	let _curClueFocusDepth    = 0;

	// tracks the cursor state associated with the up arrow key when the board is focused
	// -1 = board selected, >= 0, special character index position
	let _specialCharacterFocusDepth = -1;

	// only auto-display the dialog prompt to submit the first time the student completes
	let _submitPromptReady = true;

	// track number of questions complete - and which
	// used to report status to assistive elements
	const _questionsComplete = new Map();
	let _completeCount = 0;

	// cache DOM elements for performance
	const _domCache             = {};
	let _boardDiv             = null; // div containing the board
	let _contDiv              = null; // parent div of _boardDiv

	// these are the allowed user input
	const _allowedInput         = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','Á','À','Â','Ä','Ã','Å','Æ','Ç','É','È','Ê','Ë','Í','Ì','Î','Ï','Ñ','Ó','Ò','Ô','Ö','Õ','Ø','Œ','ß','Ú','Ù','Û','Ü'];
	let _allowedKeys          = null; // generated below

	let _isMobile             = false;
	const _zoomedIn             = false;

	// used for letter scale focusing
	let _doZoomIn             = false;

	// constants
	// NOTE: now that the player is responsive, these values
	// should be used as a psuedo base scale for the game
	const LETTER_HEIGHT         = 23; // how many pixels high is a space?
	const LETTER_WIDTH          = 27; // how many pixels wide is a space?

	const MOBILE_PX             = 576; // in px., mobile breakpoint size
	const VERTICAL              = 1; // used to compare dir == 1 or dir == VERTICAL
	const NEXT_RECURSE_LIMIT    = 8; // number of characters in a row we'll try to jump forward before dying

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

	// update isMobile variable depending on if the screen was scaled
	// mainly so the widget doesnt break if someone rescales a bunch
	const _updateIsMobile = function() {
		const newMobile = $(window).width() < MOBILE_PX;
		if (newMobile !== _isMobile) {
			if (!newMobile) { // mobile -> desktop
				$('#clues').css("height", "auto");
			} else { // desktop -> mobile
				$('#clues').animate({scrollTop: _dom('clue_'+_curClue).offsetTop}, 0);
				$('#clues').css("height", $('#clue_'+_curClue).height());

				// reset view on transition back to mobile
				_resetView();
				$('#focus-letter').attr('class', 'icon-zoomin');
				$('#movable').attr('class', 'crossword-board');
				$('#focus-text').text('');
			}
		}
		return _isMobile = newMobile;
	};

	// Called by Materia.Engine when your widget Engine should start the user experience.
	const start = function(instance, qset, version) {
		// if we're on a mobile device, some event listening will be different
		if (version == null) { version = '1'; }
		_isMobile = $(window).width() < MOBILE_PX;
		if (_isMobile) {
			$('#clues').css("height", parseInt($('#clue_'+_curClue).css('height')));
			document.ontouchmove = e => e.preventDefault();
		}

		// build allowed key list from allowed chars
		_allowedKeys = (Array.from(_allowedInput).map((char) => char.charCodeAt(0)));

		// store widget data
		_instance = instance;
		_qset = qset;

		// easy access to questions
		_questions = _qset.items[0].items;
		_boardDiv = $('#movable');
		_contDiv = $('#movable-container');

		// clean qset variables
		forEveryQuestion(function(i, letters, x, y, dir) {
			_questions[i].options.x = ~~_questions[i].options.x;
			_questions[i].options.y = ~~_questions[i].options.y;
			return _questions[i].options.dir = ~~_questions[i].options.dir;
		});

		const puzzleSize = _measureBoard(_questions);
		_scootWordsBy(puzzleSize.minX, puzzleSize.minY); // normalize the qset coordinates

		_puzzleLetterWidth  = puzzleSize.width;
		_puzzleLetterHeight = puzzleSize.height;
	
		_puzzleWidthOverflow = (_puzzleLetterWidth * LETTER_WIDTH) - _contWidth();
		_puzzleHeightOverflow = (_puzzleLetterHeight * LETTER_HEIGHT) - _contHeight();

		_curLetter = { x: _questions[0].options.x, y:_questions[0].options.y };
		
		// render the widget, hook listeners, update UI
		_drawBoard(instance.name);
		_animateToShowBoardIfNeeded();
		_setupEventHandlers();
		_updateFreeWordsRemaining();

		// once everything is drawn, set the height of the player
		Materia.Engine.setHeight();

		_centerBoard();
		_showIntroDialog();
		_updateClue();

		return _rescaleVars();
	};

	// getElementById and cache it, for the sake of performance
	var _dom = id => _domCache[id] || (_domCache[id] = document.getElementById(id));

	const _setActiveDescendant = id => _dom('board').setAttribute('aria-activedescendant', id);

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

		$('#board').keydown(_boardKeyDownHandler);
		$('#kbhelp').click(() => _showKeyboardDialog());
		$('#introbtn').click(() => _showIntroDialog());
		$('#printbtn').click(e => Crossword.Print.printBoard(_instance, _questions));
		$('#printbtn').keyup(function(e) {
			if (e.keyCode === 13) { return Crossword.Print.printBoard(_instance, _questions); }
		});
		
		$('#focus-letter').click(function(e) {
			if (!_doZoomIn) {
				_centerLetter();
				$('#focus-letter').attr('class', 'icon-zoomout');
				$('#movable').attr('class', 'crossword-board focused');
				return $('#focus-text').text('focused');
			} else {
				_resetView();
				$('#focus-letter').attr('class', 'icon-zoomin');
				$('#movable').attr('class', 'crossword-board');
				return $('#focus-text').text('');
			}
		});

		$('#specialInputBody li').click(function() {
			const spoof = $.Event('keydown');
			spoof.which = this.innerText.charCodeAt(0);
			spoof.keyCode = this.innerText.charCodeAt(0);
			const currentLetter = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);
			return $(currentLetter).trigger(spoof);
		});
		$('#specialInputHead').click(() => $('#specialInput').toggleClass('down up'));

		_dom('movable').addEventListener('focus', _boardFocusHandler);

		_dom('submit').addEventListener('click', () => _showAlert("Are you sure you're done?", 'Yep, Submit', 'No, Cancel', _dom('moveable'), _submitAnswers));

		document.getElementById('board').addEventListener('mousedown', _mouseDownHandler);
		document.getElementById('board').addEventListener('mousemove', _mouseMoveHandler);
		document.addEventListener('mouseup', _mouseUpHandler);

		return $('#clues').keydown(_clueKeyDownHandler);
	};

	const _assistiveNotification = text => _dom('assistive-notification').innerHTML = text;

	const _assistiveAlert = text => _dom('assistive-alert').innerHTML = text;

	var _boardFocusHandler = function(e) {
		_highlightPuzzleWord(_curClue);
		return _highlightPuzzleLetter(true, false);
	};

	// start dragging
	var _mouseDownHandler = function(e) {
		const context = _isMobile ? e.pointers[0] : e;

		if ((context.clientX > _contWidth()) || _doZoomIn) { return; }

		_boardMouseDown = true;
		_mouseYAnchor = context.clientY;
		_mouseXAnchor = context.clientX;

		if (_curDir !== -1) { _prevDir = _curDir; }
		return _curDir = -1;
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
	var _drawBoard = function(title) {
		// hide freewords label if the widget has none
		_freeWordsRemaining = _qset.options.freeWords;
		if (_freeWordsRemaining < 1) { $('.remaining').css('display','none'); }

		// ellipse the title if too long
		if ((title === undefined) || null) {
			title = "Widget Title Goes Here";
		}
		if (title.length > 45) { title = title.substring(0, 42) + '...'; }
		$('#title').html(title);
		$('#title').css('font-size', (25 - (title.length / 8)) + 'px');

		document.title = 'Crossword Materia widget: ' + title;

		// tracks horizontal and vertical extent of the puzzle
		// origin is top-left, in units of letters
		let maxLetterX = 0;
		let maxLetterY = 0;

		// generate elements for questions
		forEveryQuestion(function(i, letters, x, y, dir) {
			let intersection;
			const questionText = _questions[i].questions[0].text;
			const locationList = {};

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

			_renderClue(questionText, hintPrefix, i, dir);

			if (~~i === 0) { _prevDir = dir; }

			if (!_questions[i].options.hint) { $('#hintbtn_'+i).css('display', 'none'); }
			if (!_freeWordsRemaining) { $('#freewordbtn_'+i).css('display', 'none'); }
			$('#hintbtn_'+i).click(_hintConfirm);
			$('#freewordbtn_'+i).click(_getFreeword);

			forEveryLetter(x, y, dir, letters, function(letterLeft, letterTop, l) {
				locationList['' + letterLeft + letterTop] = {
					index: Object.keys(locationList).length,
					x: letterLeft,
					y: letterTop
				};

				// overlapping connectors should not be duplicated
				if ((_puzzleGrid[letterTop] != null) && (_puzzleGrid[letterTop][letterLeft] === letters[l])) {
					// keep track of overlaps and store in _wordIntersections
					const intersectedElement = _dom(`letter_${letterLeft}_${letterTop}`);
					const intersectedQuestion = ~~intersectedElement.getAttribute("data-q") + 1;

					location = "" + letterLeft + letterTop;
					intersection = [~~i + 1, intersectedQuestion];
					if (_questions[i].options.dir) { intersection.reverse(); }
					_wordIntersections[location] = intersection;

					return;
				}

				const protectedSpace = _allowedInput.indexOf(letters[l].toUpperCase()) === -1;

				// each letter is a div with coordinates as id
				const letterElement = document.createElement(protectedSpace ? 'div' : 'input');
				letterElement.id = `letter_${letterLeft}_${letterTop}`;
				letterElement.classList.add('letter');
				letterElement.setAttribute('tabindex', '-1');
				letterElement.setAttribute('autocomplete', 'off');
				if (protectedSpace) { letterElement.setAttribute('aria-label', 'Reserved space representing a special character or white space. Input is not allowed for this character.');
				} else { letterElement.setAttribute('aria-label', 'Character position ' + (l + 1) + ' of ' + _getInteractiveLetterCount(letters)); }
				letterElement.setAttribute('aria-describedby', 'cluetext_' + i);
				letterElement.setAttribute('data-q', i);
				letterElement.setAttribute('data-dir', dir);
				letterElement.onclick = _letterClicked;

				letterElement.style.top = (letterTop * LETTER_HEIGHT) + _mapPadding() + 'px';
				letterElement.style.left = (letterLeft * LETTER_WIDTH) + _mapPadding() + 'px';

				// if it's not a guessable char, display the char
				if (protectedSpace) {
					letterElement.setAttribute('data-protected', '1');
					letterElement.innerHTML = letters[l];
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

			_questionsComplete.set(~~i, false);
			_dom('submit-status').innerHTML = '' + _completeCount + ' of ' + _questions.length + ' completed.'; 

			return _questions[i].locations = locationList;
		});
		
		// update board sizing
		// +1 accounts for x/y values starting at 0
		const newWidth = (maxLetterX + 1) * LETTER_WIDTH;
		const newHeight = (maxLetterY + 1) * LETTER_HEIGHT;
		_boardDiv.css('width', newWidth);
		_boardDiv.css('height', newHeight);

		// set offset to center board
		return _centerBoard();
	};

	var _getInteractiveLetterCount = function(word) {
		const interactive = word.map(function(letter) {
			if ((letter !== '-') && (letter !== ' ')) { return letter; }
		});
		
		return interactive.length;
	};

	// select first letter, in-bounds checks are handled by the click handler
	var _animateToShowBoardIfNeeded = () => _letterClicked({ target: _dom(`letter_${_curLetter.x}_${_curLetter.y}`) });


	var _resetView = function(animate) {
		if (animate == null) { animate = true; }
		const m = _dom('movable');
		if (animate) {
			m.classList.add('animateall');
		}

		clearTimeout(_movableEase);

		_movableEase = setTimeout(() => m.classList.remove('animateall')

		, 1000);

		const trans = '';
		_boardDiv.css('-webkit-transform', trans)
			.css('-moz-transform', trans)
			.css('transform', trans);
		_doZoomIn = false;

		_puzzleX = 0;
		_puzzleY = 0;

		m.style.top  = _puzzleY + 'px';
		return m.style.left = _puzzleX + 'px';
	};

	// centers puzzleX/Y on the current letter, zooms
	var _centerLetter = function(animate) {
		if (animate == null) { animate = true; }
		const letterX = _curLetter.x * LETTER_WIDTH;
		const letterY = _curLetter.y * LETTER_HEIGHT;

		// don't add extra zoom on mobile
		const scaleFactor = _isMobile ? 1 : 2;

		// we want to translate letterX/Y to the centerpoint
		_puzzleX = (_mapWidth()/2) - ((letterX+(LETTER_WIDTH/2))*scaleFactor);
		_puzzleY = (_mapHeight()/2) - ((letterY+(LETTER_HEIGHT/2))*scaleFactor);

		const m = _dom('movable');
		if (animate) {
			m.classList.add('animateall');
		}

		clearTimeout(_movableEase);

		_movableEase = setTimeout(() => m.classList.remove('animateall')

		, 1000);

		const trans = `scale(${scaleFactor})`;
		_boardDiv
			.css('-webkit-transform', trans)
			.css('-moz-transform', trans)
			.css('transform', trans);
		_doZoomIn = true;

		m.style.top  = _puzzleY + 'px';
		return m.style.left = _puzzleX + 'px';
	};

	// remove letter focus class from the current letter
	const _removePuzzleLetterHighlight = function() {
		const g = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);
		if (g != null) { return g.classList.remove('focus'); }
	};

	// apply highlight class
	var _highlightPuzzleLetter = function(animate, autofocus) {
		if (animate == null) { animate = true; }
		if (autofocus == null) { autofocus = true; }
		const highlightedLetter = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);

		if (highlightedLetter) {
			highlightedLetter.classList.add('focus');
			if (autofocus) { highlightedLetter.focus(); }

			// figure out if the _curLetter is on the screen
			const letterX = ((_curLetter.x * LETTER_WIDTH) + _mapXMargin()) - _mapPadding() - _mapBorder();
			const letterY = ((_curLetter.y * LETTER_HEIGHT) + _mapYMargin()) - _mapPadding() - _mapBorder();

			const isOffBoardX = (letterX > (_contWidth() - _puzzleX)) || (letterX < (0 -_puzzleX)); 
			const isOffBoardY = (letterY > (_contHeight() - _puzzleY)) || (letterY < (0 -_puzzleY));

			const m = _dom('movable');
			if (!_boardMoving && (isOffBoardX || isOffBoardY)) {
				if (isOffBoardX) {
					_puzzleX = ((-_curLetter.x * LETTER_WIDTH) - _mapXMargin()) + _mapPadding() + _mapBorder();
				}

				if (isOffBoardY) {
					_puzzleY = ((-_curLetter.y * LETTER_HEIGHT) - _mapYMargin()) + _mapPadding() + _mapBorder();
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

			// focus on mobile by default
			if (_doZoomIn || _isMobile) { _centerLetter(); }

			m.style.top  = _puzzleY + 'px';
			return m.style.left = _puzzleX + 'px';
		}
	};

	// update which clue is highlighted and scrolled to on the side list
	var _updateClue = function() {
		const highlightedLetter = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);

		if (highlightedLetter) {
			let clue = _dom('clue_'+highlightedLetter.getAttribute('data-q'));

			// if at an intersection, try to keep the same word selected
			const location = "" + _curLetter.x + _curLetter.y;
			if (_wordIntersections.hasOwnProperty(location)) {
				const index = _wordIntersections[location][~~(_prevDir === 1)] - 1;
				clue = _dom('clue_'+index);
				_curClue = parseInt(index);

			} else { _curClue = parseInt(clue.getAttribute('data-i')); } // TODO rework this?

			// if it's already highlighted, do not try to scroll to it
			if (clue.classList.contains('highlight')) {
				return;
			}

			// remove the highlight from all others
			for (var j in _questions) {
				_dom('clue_'+j).classList.remove('highlight');
			}

			const scrolly = clue.offsetTop;
			clue.classList.add('highlight');

			$('#clues').stop(true);
			$('#clues').animate({scrollTop: scrolly}, 0);
			// set clue container to size of new clue displayed on mobile
			if (_isMobile) {
				return $('#clues').css("height", parseInt($('#clue_'+_curClue).css('height')));
			}
		}
	};

	const _updateCompleteCount = function() {
		let count = 0;
		for (let i = 0; i < _questions.length; i++) {
			var question = _questions[i];
			var missing = false;
			for (var index of Array.from(Object.keys(question.locations))) {
				var location = question.locations[index];
				if (_dom(`letter_${location.x}_${location.y}`).value === '') { missing = true; }
			}
			
			if (!missing) {
				_questionsComplete.set(~~i, true);
				count++;
			}
		}
		
		if (count !== _completeCount) {
			_completeCount = count;
			return _dom('submit-status').innerHTML = '' + _completeCount + ' of ' + _questions.length + ' completed.'; 
		}
	};

	const _nextLetter = function(direction) {
		if (direction === VERTICAL) {
			return _curLetter.y++;
		} else {
			return _curLetter.x++;
		}
	};

	const _prevLetter = function(direction) {
		if (direction === VERTICAL) {
			return _curLetter.y--;
		} else {
			return _curLetter.x--;
		}
	};

	var _clueKeyDownHandler = function(keyEvent) {
		const questionIndex = _curClue;

		switch (keyEvent.key) {
			case 'ArrowUp':
				_setClueFocusDepth('up', questionIndex);
				return keyEvent.preventDefault();
			case 'ArrowDown':
				_setClueFocusDepth('down', questionIndex);
				return keyEvent.preventDefault();
			case 'ArrowLeft':
				_selectPreviousQuestion(questionIndex);
				var i = (questionIndex - 1) < 0 ? _questions.length - 1 : questionIndex - 1;
				_highlightPuzzleWord(i);
				return _highlightPuzzleLetter();
			case 'ArrowRight':
				_selectNextQuestion(questionIndex);
				i = (questionIndex + 1) % _questions.length;
				_highlightPuzzleWord(i);
				return _highlightPuzzleLetter();
		}
	};
	
	var _setClueFocusDepth = function(direction, index) {
		if (direction === 'up') {
			switch (_curClueFocusDepth) {
				case 0: return;
				case 1:
					_curClueFocusDepth = 0;
					_dom('letter_' + _curLetter.x + '_' + _curLetter.y).focus();
					_highlightPuzzleLetter();
					return _assistiveNotification('Focus returned to game board for question ' + (index + 1) + '.');
				case 2:
					_curClueFocusDepth = 0;
					if (_dom('hintbtn_' + index).hasAttribute('disabled')) {
						return _assistiveNotification('Hint button unavailable for question ' + (index + 1) + '. Focus returned to game board.');
					} else {
						_curClueFocusDepth = 1;
						_dom('hintbtn_' + index).focus();
						return _assistiveNotification('Hint button selected for question ' + (index + 1) + '.');
					}
			}
		} else if (direction === 'down') {
			switch (_curClueFocusDepth) {
				case 0:
					_curClueFocusDepth = 1;
					if (_dom('hintbtn_' + index).hasAttribute('disabled')) {
						return _assistiveNotification('Hint has already been requested for question ' + (index + 1) + '.');
					} else {
						_dom('hintbtn_' + index).focus();
						return _assistiveNotification('Hint button selected for question ' + (index + 1) + '.');
					}
				case 1:
					if (_dom('freewordbtn_' + index).hasAttribute('disabled')) {
						return _assistiveAlert('You cannot request a free word. No free words remain.');
					} else {
						_curClueFocusDepth = 2;
						_dom('freewordbtn_' + index).focus();
						return _assistiveNotification('Free Word button selected for question ' + (index + 1) + '. You have ' + _freeWordsRemaining + ' free words remaining.');
					}
				case 2: return;
			}
		}
	};

	var _boardKeyDownHandler = function(keyEvent, iteration) {
		let location;
		let letterTyped;
		if (iteration == null) { iteration = 0; }
		const preventDefault = true;

		const _lastLetter = {};
		_lastLetter.x = _curLetter.x;
		_lastLetter.y = _curLetter.y;

		_removePuzzleLetterHighlight();
		const letterElement = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);
		const isProtected = (letterElement.getAttribute('data-protected') != null);
		const isLocked = (letterElement.getAttribute('data-locked') != null);

		if ((keyEvent.key !== 'ArrowUp') && (keyEvent.key !== 'ArrowDown') && ((keyEvent.key !== 'Enter') || !(_specialCharacterFocusDepth > -1))) { _dismissSpecialCharacterFocus(); }

		let questionIndex = _curClue;

		switch (keyEvent.key) {

			case 'Control':
				if (_isMobile) { return; }
				if (!_doZoomIn) {
					_centerLetter();
					$('#focus-letter').attr('class', 'icon-zoomout');
					$('#movable').attr('class', 'crossword-board focused');
					$('#focus-text').text('focused');
					_highlightPuzzleLetter();
				} else {
					_resetView();
					$('#focus-letter').attr('class', 'icon-zoomin');
					$('#movable').attr('class', 'crossword-board');
					$('#focus-text').text('');
					_highlightPuzzleLetter();
				}
				return;
				break;

			case 'Alt': _highlightPuzzleLetter(); break;

			case 'ArrowLeft': _selectPreviousQuestion(questionIndex); break;

			case 'ArrowUp': //up
				keyEvent.preventDefault();
				_highlightPuzzleLetter(); // puzzle letter highlight is removed by default
				_handleSpecialCharacterFocus('up');
				return;
				break;

			case 'ArrowRight': _selectNextQuestion(questionIndex); break;

			case 'ArrowDown': //down
				keyEvent.preventDefault();
				if (_specialCharacterFocusDepth === -1) { _setClueFocusDepth('down', questionIndex);
				} else {
					_handleSpecialCharacterFocus('down');
					_highlightPuzzleLetter(); // puzzle letter highlight is removed by default
				}
				return;
				break;

			case 'Delete': //delete
				if (!isProtected && !isLocked) { letterElement.value = ''; }
				_checkIfDone();
				return;
				break;
			case 'Tab': // tab

				var question = _questions[questionIndex];
				location = "" + _curLetter.x + _curLetter.y;
				var position = question.locations[location].index;

				if (question.options.dir === 0) {
					if (keyEvent.shiftKey && (position > 0)) {
							_curLetter.x--;
							_curDir = 0;
							keyEvent.preventDefault();
					} else if (!keyEvent.shiftKey && (position < (Object.keys(question.locations).length - 1))) {
						_curLetter.x++;
						_curDir = 0;
						keyEvent.preventDefault();
					} else { return; }
				} else {
					if (keyEvent.shiftKey && (position > 0)) {
						_curLetter.y--;
						_curDir = 1;
						keyEvent.preventDefault();
					} else if (!keyEvent.shiftKey && (position < (Object.keys(question.locations).length - 1))) {
						_curLetter.y++;
						_curDir = 1;
						keyEvent.preventDefault();
					} else { return; }
				}

				_setActiveDescendant('letter_' + _curLetter.x + '_' + _curLetter.y);
				_updateClue();
				break;

			case 'Enter': //enter

				if (_specialCharacterFocusDepth > -1) {

					const select = $('#specialInputBody').find('li').eq(_specialCharacterFocusDepth);
					const spoof = $.Event('keydown');
					spoof.which = select[0].innerText.charCodeAt(0);
					spoof.keyCode = select[0].innerText.charCodeAt(0);
					const currentLetter = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);
					$(currentLetter).trigger(spoof);

					_assistiveNotification(select[0].innerText.charCodeAt(0) + ' inserted. Focus returned to game board.');

					keyEvent.preventDefault();
					return;
				}

				// go to the next clue, based on the clue that is currently selected
				questionIndex = _curClue;

				var nextQuestionIndex = (questionIndex + 1) % _questions.length;
				var nextQuestion = _questions[nextQuestionIndex];

				_curDir = nextQuestion.options.dir;
				_prevDir = _curDir;
				_curLetter.x = nextQuestion.options.x;
				_curLetter.y = nextQuestion.options.y;
				_updateClue();
				keyEvent.keyCode = 39 + _curDir;
				break;
			case 'Backspace': //backspace
				// dont let the page back navigate
				keyEvent.preventDefault();

				if (letterElement != null) {
					// if the current direction is unknown
					if (_curDir === -1) {
						// set to the one stored on the letter element from the qset
						_curDir = ~~letterElement.getAttribute('data-dir');
					}

					// move selection back
					_prevLetter(_curDir);

					// clear value
					if (!isProtected && !isLocked) { letterElement.value = ''; }
				}

				_checkIfDone();
				break;
			default: //any letter
				if (keyEvent && keyEvent.key) {
					letterTyped = keyEvent.key.toUpperCase();
				} else {
					letterTyped = String.fromCharCode(keyEvent.keyCode);
				}
				// a letter was typed, move onto the next letter or override if this is the last letter
				if (letterElement) {
					if (!_isGuessable(letterTyped)) {
						// disallow special characters from being entered
						keyEvent.preventDefault();
						_highlightPuzzleLetter();
						return;
					}

					if (_curDir === -1) {
						_curDir = ~~letterElement.getAttribute('data-dir');
					}
					_nextLetter(_curDir);

					if (!isProtected && !isLocked) { letterElement.value = letterTyped; }

					// if the puzzle is filled out, highlight the submit button
					_checkIfDone();
				}
		}

		const nextletterElement = _dom(`letter_${_curLetter.x}_${_curLetter.y}`);

		// highlight the next letter, if it exists and is not a space
		if (nextletterElement && (nextletterElement.getAttribute('data-protected') !== '1')) {
			_highlightPuzzleLetter();
		} else {
			// otherwise, if it does not exist, go to the next word
			if ((nextletterElement == null)) {
				if (keyEvent.keyCode >= 48) { keyEvent.keyCode = 13; }
				_curLetter = _lastLetter;
			}
			// recursively guess the next letter?
			if (iteration < NEXT_RECURSE_LIMIT) {
				// if recursion doesn't work, try to move on to the next clue
				if ((iteration === (NEXT_RECURSE_LIMIT - 2)) && (keyEvent.keyCode >= 48)) {
					// simulates enter being pressed after a letter typed in last slot
					keyEvent.keyCode = 13;
				}
				_boardKeyDownHandler(keyEvent, (iteration || 0)+1);
				return;
			} else {
				// highlight the last successful letter
				_highlightPuzzleLetter();
			}
		}

		// highlight the word
		if (nextletterElement) {
			// make sure the correct word is highlighted at an intersection
			location = "" + _curLetter.x + _curLetter.y;
			if (_wordIntersections.hasOwnProperty(location)) {
				const i = _wordIntersections[location][~~(_prevDir === 1)] - 1;
				_highlightPuzzleWord(i);
				// update the aria-describedby attribute to match the clue associated with the current direction
				nextletterElement.setAttribute('aria-describedby','cluetext_'+i);
				_curDir = _questions[i].options.dir;
			} else {
				if ((_curDir === ~~nextletterElement.getAttribute('data-dir')) || (_curDir === -1)) {
					_highlightPuzzleWord(nextletterElement.getAttribute('data-q'));
				}
			}

			if (_curDir !== -1) { _prevDir = _curDir; }
		}

		// to shut up screenreaders
		if (preventDefault) { keyEvent.preventDefault(); }

		// check and update number of words completed
		_updateCompleteCount();

		return (nextletterElement != null ? nextletterElement.focus() : undefined);
	};

	var _selectPreviousQuestion = function(index) {
		_curClueFocusDepth = 0;

		const prevQuestionIndex = (index - 1) < 0 ? _questions.length - 1 : index - 1;
		const prevQuestion = _questions[prevQuestionIndex];

		_curDir = prevQuestion.options.dir;
		_prevDir = _curDir;
		_curLetter.x = prevQuestion.options.x;
		_curLetter.y = prevQuestion.options.y;

		_curClue = prevQuestionIndex;

		_assistiveNotification('Question ' + (prevQuestionIndex + 1) + ' of ' + _questions.length + '. This question has ' + Object.keys(prevQuestion.locations).length + ' characters.');
		return _updateClue();
	};

	var _selectNextQuestion = function(index) {
		_curClueFocusDepth = 0;

		const nextQuestionIndex = (index + 1) % _questions.length;
		const nextQuestion = _questions[nextQuestionIndex];

		_curDir = nextQuestion.options.dir;
		_prevDir = _curDir;
		_curLetter.x = nextQuestion.options.x;
		_curLetter.y = nextQuestion.options.y;

		_curClue = nextQuestionIndex;

		_assistiveNotification('Question ' + (nextQuestionIndex + 1) + ' of ' + _questions.length + '. This question has ' + Object.keys(nextQuestion.locations).length + ' characters.');
		return _updateClue();
	};

	// is a letter one that can be guessed?
	var _isGuessable = character => _allowedInput.indexOf(character) !== -1;

	// update the UI elements pertaining to free words
	var _updateFreeWordsRemaining = function() {
		const sentence = ' free word' + (_freeWordsRemaining === 1 ? '' : 's') + ' remaining';
		$('#freeWordsRemaining').html(_freeWordsRemaining + sentence);

		// hide buttons if no free words remain
		if (_freeWordsRemaining < 1) {
			return (() => {
				const result = [];
				for (var i in _questions) {
					if (_qset.options.freeWords < 1) {
						result.push($('#freewordbtn_'+i).css('display', 'none'));
					} else {
						_dom('freewordbtn_'+i).classList.add('disabled');
						result.push(_dom('freewordbtn_'+i).setAttribute('disabled', 'true'));
					}
				}
				return result;
			})();
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

		// keep the prior direction if at an intersection
		if (_wordIntersections.hasOwnProperty(location) && (_prevDir !== -1)) {
			_curDir = _prevDir;
			forEveryQuestion(function(i, letters, x, y, dir) {
				if (_curDir === dir) {
					return forEveryLetter(x, y, dir, letters, function(letterLeft, letterTop, l) {
						if ((_curLetter.x === letterLeft) && (_curLetter.y === letterTop)) {
							return _highlightPuzzleWord(i);
						}
					});
				}
			});
		} else {
			_curDir = ~~_dom(`letter_${_curLetter.x}_${_curLetter.y}`).getAttribute('data-dir');
			_prevDir = _curDir;
			_highlightPuzzleWord((target).getAttribute('data-q'));
		}

		_highlightPuzzleLetter(animate);
		return _updateClue();
	};

	// confirm that the user really wants to risk a penalty
	var _hintConfirm = function(e) {
		if (e.target.classList.contains('disabled')) {
			_assistiveAlert('You have already requested the hint for this question.');
			return;
		}
		
		const index = e.target.getAttribute('data-i');
		return _showAlert(`Receiving a hint will result in a ${_qset.options.hintPenalty}% penalty for this question.`, 'Okay', 'Nevermind', _dom('hintbtn_'+index),  () => _getHint(index));
	};

	// fired by the free word buttons
	var _getFreeword = function(e) {
		if (_freeWordsRemaining < 1) { return; }

		// stop if parent clue is not highlighted
		if (!_dom('clue_' + e.target.getAttribute('data-i')).classList.contains('highlight')) { return; }

		// stop if button is disabled
		if (e.target.classList.contains('disabled')) { return; }

		// get question index from button attributes
		const index = parseInt(e.target.getAttribute('data-i'));

		_usedFreeWords[index] = true;

		// letter array to fill
		const letters = _questions[index].answers[0].text.split('');
		const {
            x
        } = _questions[index].options;
		const {
            y
        } = _questions[index].options;
		const {
            dir
        } = _questions[index].options;
		const answer  = '';

		// fill every letter element
		forEveryLetter(x,y,dir,letters, function(letterLeft, letterTop, l) {
			const letter = _dom(`letter_${letterLeft}_${letterTop}`);
			letter.classList.add('locked');
			const existingText = letter.getAttribute('aria-label');
			letter.setAttribute('aria-label', existingText + '. This character is locked because it is part of a free word.');
			letter.setAttribute('data-locked', '1');
			return letter.value = letters[l].toUpperCase();
		});

		_freeWordsRemaining--;

		_dom('freewordbtn_' + index).classList.add('disabled');
		_dom('freewordbtn_' + index).setAttribute('inert', true);
		_dom('freewordbtn_' + index).setAttribute('disabled', true);
		
		_dom('hintbtn_' + index).classList.add('disabled');

		_assistiveAlert('Free word selected. you have ' + _freeWordsRemaining + ' remaining free words.');
		_curClueFocusDepth = 0;

		_updateFreeWordsRemaining();
		_checkIfDone();
		
		_dom(`letter_${_curLetter.x}_${_curLetter.y}`).focus();
		return _highlightPuzzleLetter();
	};

	// highlight a word (series of letters)
	var _highlightPuzzleWord = function(index) {
		// remove highlight from every letter
		$(".letter.highlight").removeClass("highlight");
		// and add it to the ones we care about
		return forEveryQuestion(function(i, letters, x, y, dir) {
			if (~~i === ~~index) {
				return forEveryLetter(x,y,dir,letters, function(letterLeft, letterTop) {
					const l = _dom(`letter_${letterLeft}_${letterTop}`);
					if (l != null) {
						return l.classList.add('highlight');
					}
				});
			}
		});
	};

	var _showIntroDialog = function() {
		const modal = _dom('introbox');
		modal.classList.add('show');
		_dom('backgroundcover').classList.add('show');

		$(modal).find('#intro_dismiss').unbind('click').click(function() {
			_hideIntroDialog();
			return _dom('movable').focus();
		});

		$(modal).find('#intro_instructions').unbind('click').click(function() {
			_hideIntroDialog();
			return _showKeyboardDialog();
		});

		return _dom('application').setAttribute('inert', 'true');
	};

	var _hideIntroDialog = function() {
		_dom('backgroundcover').classList.remove('show');
		_dom('introbox').classList.remove('show');
		return _dom('application').removeAttribute('inert');
	};

	var _showKeyboardDialog = function() {
		const modal = _dom('tutorialbox');
		modal.classList.add('show');
		_dom('backgroundcover').classList.add('show');

		$(modal).find('#tutorial_dismiss').unbind('click').click(() => _hideKeyboardDialog());

		_dom('tutorial_dismiss').focus();
		// set the application to inert to prevent dialog being defocused
		return _dom('application').setAttribute('inert', 'true');
	};

	var _hideKeyboardDialog = function() {
		_dom('backgroundcover').classList.remove('show');
		_dom('tutorialbox').classList.remove('show');
		_dom('application').removeAttribute('inert');

		return _dom('kbhelp').focus();
	};

	// show the modal alert dialog
	var _showAlert = function(caption, okayCaption, cancelCaption, focusTarget, action) {

		const ab = _dom('alertbox');

		ab.classList.add('show');
		_dom('backgroundcover').classList.add('show');

		_dom('ab_cancel').classList.add('removed');

		$('#alertcaption').html(caption);
		_dom('ab_confirm').innerHTML = okayCaption;
		if (cancelCaption) {
			_dom('ab_cancel').classList.remove('removed');
			_dom('ab_cancel').innerHTML = cancelCaption;

			$(ab).find('#ab_cancel').unbind('click').click(() => _hideAlert(focusTarget));
		}

		$(ab).find('#ab_confirm').unbind('click').click(function() {
			action();
			return _hideAlert(focusTarget);
		});
		
		_dom('ab_cancel').focus();
		// set the application to inert to prevent dialog being defocused
		return _dom('application').setAttribute('inert', 'true');
	};

	// hide it
	var _hideAlert = function(focusTarget = null) {
		_dom('backgroundcover').classList.remove('show');
		_dom('alertbox').classList.remove('show');
		_dom('application').removeAttribute('inert');
		
		if (focusTarget !== null) {
			focusTarget.focus();
			if (focusTarget === _dom(`letter_${_curLetter.x}_${_curLetter.y}`)) { return _highlightPuzzleLetter(); }
		}
	};

	// called after confirm dialog
	var _getHint = function(index) {
		_usedHints[index] = true;
		Materia.Score.submitInteractionForScoring(_questions[index].id, 'question_hint', '-' + _qset.options.hintPenalty);

		const hintSpot = _dom(`hintspot_${index}`);
		hintSpot.innerHTML = `Hint. ${_questions[index].options.hint}`;
		hintSpot.style.opacity = 1;

		const hintButton = _dom('hintbtn_' + index);

		hintButton.classList.add('disabled');
		hintButton.setAttribute('aria-labelledby', 'hintspot_'+index);

		_assistiveAlert('Hint for question ' + (index + 1) + ': ' + _questions[index].options.hint);
		_curClueFocusDepth = 1;

		hintButton.focus();

		// update clue box height after hint is shown on mobile
		if (_isMobile) {
			return $('#clues').css("height", parseInt($('#clue_'+_curClue).css('height')));
		}
	};

	var _handleSpecialCharacterFocus = function(direction) {

		let select;
		const drawer = _dom('specialInput');
		const specialCharacterSelectLength = $('#specialInputBody').find('li').length;

		if (direction === 'up') {
			
			if (!drawer.hasAttribute('open')) {
				drawer.setAttribute('open', 'true');
				drawer.classList.remove('down');
				drawer.classList.add('up');
			}

			$('#specialInputBody').find('li').eq(_specialCharacterFocusDepth)[0].classList.remove('focus');
			
			if ((_specialCharacterFocusDepth + 1) < specialCharacterSelectLength) { _specialCharacterFocusDepth++; }

			select = $('#specialInputBody').find('li').eq(_specialCharacterFocusDepth);
			select[0].classList.add('focus');

			return _assistiveNotification(select.html() + ' selected. Use enter to insert the value at the current character.');

		} else if (direction === 'down') {

			if ((_specialCharacterFocusDepth === 0) && drawer.hasAttribute('open')) {
				drawer.removeAttribute('open');
				drawer.classList.remove('up');
				drawer.classList.add('down');

				_assistiveNotification('Focus returned to game board.');
			}

			$('#specialInputBody').find('li').eq(_specialCharacterFocusDepth)[0].classList.remove('focus');

			_specialCharacterFocusDepth--;

			select = $('#specialInputBody').find('li').eq(_specialCharacterFocusDepth);
			return select[0].classList.add('focus');
		}
	};

	var _dismissSpecialCharacterFocus = function() {
		const drawer = _dom('specialInput');
		_specialCharacterFocusDepth = -1;

		const chars = document.querySelectorAll('li.focus');
		for (var char of Array.from(chars)) {
			char.classList.remove('focus');
		}

		drawer.removeAttribute('open');
		drawer.classList.remove('up');
		return drawer.classList.add('down');
	};

	// highlight submit button if all letters are filled in
	var _checkIfDone = function() {
		let done = true;
		let unfinishedWord = null;

		forEveryQuestion((i, letters, x, y, dir) => forEveryLetter(x, y, dir, letters, function(letterLeft, letterTop, l) {
            if (letters[l] !== ' ') {
                if (_dom(`letter_${letterLeft}_${letterTop}`).value === '') {
                    unfinishedWord = _dom(`letter_${letterLeft}_${letterTop}`).getAttribute('data-q');
                    done = false;
                    return;
                }
            }
        }));

		if (done) {
			if (_submitPromptReady) {
				_showAlert("You've completed every question are ready to submit.", 'Submit', 'Cancel', _dom('movable'), _submitAnswers);
				return _submitPromptReady = false;
			} else {
				return $('.arrow_box').show();
			}
			
		} else {
			const question = _questions[unfinishedWord];
			let missing = null;
			for (var index of Array.from(Object.keys(question.locations))) {
				var location = question.locations[index];
				if (_dom(`letter_${location.x}_${location.y}`).value === '') { missing = location.index + 1; }
			}

			return $('.arrow_box').hide();
		}
	};

	// draw a number label to identify the question
	var _renderNumberLabel = function(questionNumber, x, y) {
		const numberLabel = document.createElement('div');
		numberLabel.innerHTML = questionNumber;
		numberLabel.classList.add('numberlabel');
		numberLabel.setAttribute('aria-hidden', true);
		numberLabel.style.top = (y * LETTER_HEIGHT) + _mapPadding() + 'px';
		numberLabel.style.left = (x * LETTER_WIDTH) + _mapPadding() + 'px';
		numberLabel.onclick = () => _letterClicked({target: $(`#letter_${x}_${y}`)[0]});
		return _boardDiv.append(numberLabel);
	};

	// draw the clue from template html
	var _renderClue = function(question, hintPrefix, i, dir) {
		const clue = document.createElement('li');
		clue.id = 'clue_' + i;

		// store the '# across/down' information in the question for later use
		_questions[i].prefix = hintPrefix;

		clue.innerHTML = $('#t_hints').html()
			.replace(/{{hintPrefix}}/g, hintPrefix)
			.replace(/{{question}}/g, question)
			.replace(/{{i}}/g, i)
			.replace(/{{dir}}/g, dir);

		clue.setAttribute('data-i', i);
		clue.setAttribute('data-dir', dir);
		clue.setAttribute('role', 'listitem');
		clue.classList.add('clue');

		clue.onmouseover = _clueMouseOver;
		clue.onmouseout  = _clueMouseOut;
		clue.onmouseup   = _clueMouseUp;

		$('#clues').append(clue);

		// attach focus listeners to the hintbtn and freewordbtn after the clue element is attached to the DOM
		_dom('hintbtn_' + i).addEventListener('focus', _clueFocus);
		_dom('freewordbtn_' + i).addEventListener('focus', _clueFocus);
		_dom('prevQ_' + i).addEventListener('click', _navPrevQ);
		return _dom('nextQ_' + i).addEventListener('click', _navNextQ);
	};

	// simulate clue clicks for mobile clue nav
	var _navPrevQ = function() {
		const i = (_curClue - 1) < 0 ? _questions.length - 1 : _curClue - 1;
		return _clueMouseUp({target: $('#clue_'+i)[0]});
	};

	var _navNextQ = function() {
		const i = (_curClue + 1) % _questions.length;
		return _clueMouseUp({target: $('#clue_'+i)[0]});
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
		_prevDir = _questions[i].options.dir;

		let firstLetter = $(`#letter_${x}_${y}`)[0];
		// if the first letter of the word is protected, try to loop through the rest
		while ((firstLetter != null) && (firstLetter.getAttribute('data-protected') != null)) {
			if (_prevDir === VERTICAL) {
				y++;
			} else {
				x++;
			}
			firstLetter = $(`#letter_${x}_${y}`)[0];
		}

		return _letterClicked({ target: firstLetter });
	};

	// highlight words when a clue is moused over, to correspond what the user is seeing
	var _clueMouseOver = function(e) {
		if ((e == null)) { e = window.event; }
		return _highlightPuzzleWord((e.target || e.srcElement).getAttribute('data-i'));
	};

	var _clueMouseOut = e => _highlightPuzzleWord(-1);

	var _clueFocus = function(e) {
		if ((e == null)) { e = window.event; }

		_removePuzzleLetterHighlight();

		// click on the first letter of the word
		const i = e.target.getAttribute('data-i');
		const {
            x
        } = _questions[i].options;
		const {
            y
        } = _questions[i].options;
		
		_curLetter = { x, y };
		_curDir = (_prevDir =  ~~e.target.getAttribute('data-dir'));
		_curClue = parseInt(i);
		const clueElement = _dom('clue_'+_curClue);

		// if the clue is already highlighted, do not try to scroll to it
		if (!clueElement.classList.contains('highlight')) {
			// remove the highlight from all others
			for (var j in _questions) {
				_dom('clue_'+j).classList.remove('highlight');
			}

			const scrolly = clueElement.offsetTop;
			clueElement.classList.add('highlight');
			
			$('#clues').stop(true);
			$('#clues').animate({scrollTop: scrolly}, 150);
		}

		// make sure the word associated with the current clue is highlighted (focus is not on the word)
		_highlightPuzzleWord(_curClue);

		// sync focusDepth
		if (e.target.classList.contains('hint')) { _curClueFocusDepth = 1; }
		if (e.target.classList.contains('free-word')) { return _curClueFocusDepth = 2; }
	};

	// submit every question to the scoring engine
	var _submitAnswers = function() {
		forEveryQuestion(function(i, letters, x, y, dir) {
			let answer = '';
			forEveryLetter(x, y, dir, letters, function(letterLeft, letterTop, l) {
				const letterElement = _dom(`letter_${letterLeft}_${letterTop}`);
				const isProtected = (letterElement.getAttribute('data-protected') != null);

				if (isProtected) {
					// get the letter from the qset
					return answer += letters[l];
				} else {
					// get the letter from the input
					return answer += letterElement.value || '_';
				}
			});

			return Materia.Score.submitQuestionForScoring(_questions[i].id, answer);
		});

		return Materia.Engine.end();
	};

	// loop iteration functions to prevent redundancy
	var forEveryLetter = (x, y, dir, letters, cb) => (() => {
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
            var letters = _questions[i].answers[0].text.toUpperCase().split('');
            var {
                x
            } = _questions[i].options;
            var {
                y
            } = _questions[i].options;
            var {
                dir
            } = _questions[i].options;
            result.push(callBack(i, letters, x, y, dir));
        }
        return result;
    })();

	// return public stuff for Materia

	return {
		manualResize: true,
		start
	};
})();
