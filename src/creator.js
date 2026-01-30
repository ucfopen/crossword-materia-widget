/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__, or convert again using --optional-chaining
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
const CrosswordCreator = angular.module('crosswordCreator', []);

CrosswordCreator.directive('focusMe', ['$timeout', '$parse', ($timeout, $parse) => ({
    link(scope, element, attrs) {
        const model = $parse(attrs.focusMe);
        scope.$watch(model, function(value) {
            if (value === true) {
                return $timeout(() => element[0].focus());
            }
        });
        return element.bind('blur', () => scope.$apply(model.assign(scope, false)));
    }
})
]);
CrosswordCreator.directive('selectMe', ['$timeout', '$parse', ($timeout, $parse) => ({
    link(scope, element, attrs) {
        const model = $parse(attrs.selectMe);
        return scope.$watch(model, function(value) {
            if (value === true) {
                return $timeout(() => $(element[0]).focus().select());
            }
        });
    }
})
]);

CrosswordCreator.controller('crosswordCreatorCtrl', ['$scope', '$timeout', function($scope, $timeout) {
	/* Initialize class variables */
	let _qset;
	let _title = (_qset = ($scope.hasFreshPuzzle = null));

	$scope.widget = {
		title: 'New Crossword Widget',
		hintPenalty: 50,
		freeWords: 1,
		puzzleItems: []
	};

	// dialogs
	$scope.showIntroDialog = false;
	$scope.showOptionsDialog = false;
	$scope.showTitleDialog = false;

	// scope and local variables for the special input keyboard
	$scope.specialInputState = false;
	$scope.specialInputChar = null;
	$scope.specialCharacters = ['À', 'Â', 'Ä', 'Ã', 'Å', 'Æ', 'Ç', 'É', 'È', 'Ê', 'Ë', 'Í', 'Ì', 'Î', 'Ï', 'Ñ', 'Ó', 'Ò', 'Ô', 'Ö', 'Õ', 'Ø', 'Œ', 'Ú', 'Ù', 'Û', 'Ü'];

	const specialInputTarget = {
		index: -1,
		field: null
	};

	let specialInputTargetElement = null;

	/* Scope Methods */
	$scope.initNewWidget = (widget, baseUrl) => $scope.$apply(() => $scope.showIntroDialog = true);

	$scope.initExistingWidget = function(title,widget,qset,version,baseUrl) {
		_qset = qset;
		const _items = qset.items[0].items;

		$scope.$apply(function() {
			$scope.widget.title	= title;
			$scope.widget.puzzleItems = [];
			$scope.widget.freeWords = qset.options.freeWords;
			$scope.widget.hintPenalty = qset.options.hintPenalty;
			for (var item of Array.from(_items)) {
				$scope.addPuzzleItem( item.questions[0].text, item.answers[0].text , item.options.hint, item.id);
			}
		});

		_drawCurrentPuzzle(_items);
		return $scope.hasFreshPuzzle = true;
	};

	$scope.onSaveClicked = function(mode) {
		if (!_buildSaveData() && (mode !== 'history')) {
			return Materia.CreatorCore.cancelSave('Required fields not filled out');
		}
		return Materia.CreatorCore.save(_title, _qset);
	};

	$scope.onSaveComplete = (title, widget, qset, version) => true;

	$scope.onQuestionImportComplete = items => $scope.$apply(function() {
        for (var item of Array.from(items)) {
            $scope.addPuzzleItem(item.questions[0].text, item.answers[0].text, (item.options != null ? item.options.hint : undefined) || '', item.id);
        }
        return $scope.generateNewPuzzle(true);
    });

	$scope.onMediaImportComplete = media => null;

	$scope.addPuzzleItem = function(q, a, h, id) {
		if (q == null) { q = ''; }
		if (a == null) { a = ''; }
		if (h == null) { h = ''; }
		if (id == null) { id = ''; }
		return $scope.widget.puzzleItems.push({
			question: q,
			answer: a,
			hint: h,
			id,
			found: true
		});
	};

	$scope.removePuzzleItem = function(index) {
		$scope.widget.puzzleItems.splice(index,1);
		$scope.noLongerFresh();
		return $scope.generateNewPuzzle();
	};

	$scope.introComplete = () => $scope.showIntroDialog = false;

	$scope.closeDialog = () => $scope.showIntroDialog = ($scope.showTitleDialog = ($scope.showOptionsDialog = false));

	$scope.showOptions = () => $scope.showOptionsDialog = true;

	$scope.generateNewPuzzle = function(force, reset) {
		if (force == null) { force = false; }
		if (reset == null) { reset = false; }
		if ($scope.hasFreshPuzzle && !force) { return false; }
		$('.loading').show();
		$scope.isBuilding = true;

		return $timeout(function() {
			if (reset) {
				Crossword.Puzzle.resetRandom();
			}

			$scope.hasFreshPuzzle = false;
			_buildSaveData(reset);
			$('.loading').hide();
			$scope.stopTimer();

			return $scope.$apply(() => $scope.isBuilding = false);
		}
		,300);
	};

	$scope.noLongerFresh = function() {
		$scope.hasFreshPuzzle = false;
		return $scope.resetTimer();
	};

	$scope.$watch('widget.hintPenalty', function(newValue, oldValue) {
		if ((newValue != null) && newValue.match && !newValue.match(/^[0-9]?[0-9]?$/)) {
			return $scope.widget.hintPenalty = oldValue;
		}
	});

	$scope.$watch('widget.freeWords', function(newValue, oldValue) {
		if ((newValue != null) && newValue.match && !newValue.match(/^[0-9]?[0-9]?$/)) {
			return $scope.widget.freeWords = oldValue;
		}
	});

	$scope.printPuzzle = function() {
		$scope.generateNewPuzzle();
		if (__guard__(_qset != null ? _qset.items : undefined, x => x.length)) {
			return $timeout(() => Crossword.Print.printBoard({ name: $scope.widget.title }, _qset.items[0].items)
			,500);
		}
	};

	// Timer for regenerating
	$scope.startTimer = function() {
		$scope.stopTimer();
		return $scope.timer = setInterval($scope.generateNewPuzzle, 1000);
	};

	$scope.stopTimer = () => clearInterval($scope.timer);

	$scope.resetTimer = function() {
		$scope.stopTimer();
		return $scope.startTimer();
	};

	$scope.setSpecialInputTarget = function(event, index, field) {
		specialInputTarget.index = index;
		specialInputTarget.field = field;
		specialInputTargetElement = angular.element(event.currentTarget);

		return false;
	};

	$scope.specialCharacterInput = function(character, event) {

		if (specialInputTarget === null) { return; }

		$scope.specialInputChar = character;

		const inputString = specialInputTargetElement[0].value;
		const cursorPos = specialInputTargetElement[0].selectionStart;
		const textBefore = inputString.substring(0, cursorPos);
		const textAfter = inputString.substring(cursorPos, inputString.length);

		const {
            index
        } = specialInputTarget;

		switch (specialInputTarget.field) {
			case 'answer': $scope.widget.puzzleItems[index].answer = textBefore + $scope.specialInputChar + textAfter; break;
			case 'question': $scope.widget.puzzleItems[index].question = textBefore + $scope.specialInputChar + textAfter; break;
			case 'hint': $scope.widget.puzzleItems[index].hint = textBefore + $scope.specialInputChar + textAfter; break;
		}

		return $timeout(function() {
			specialInputTargetElement[0].focus();
			specialInputTargetElement[0].selectionStart = (specialInputTargetElement[0].selectionEnd = cursorPos + 1);

			if (specialInputTarget.field === 'answer') { return $scope.noLongerFresh(); }
		});
	};

	/* Private methods */

	var _buildSaveData = function(force) {
		let item, puzzleItem;
		if (force == null) { force = false; }
		if ((_qset == null)) { _qset = {}; }

		_qset.options = { hintPenalty: $scope.widget.hintPenalty, freeWords: $scope.widget.freeWords };

		const words = [];

		_qset.assets = [];
		_qset.rand = false;
		_qset.name = '';
		_title = $scope.widget.title;
		const _okToSave = (_title != null) && (_title !== '') ? true : false;

		const _puzzleItems = $scope.widget.puzzleItems;

		// if the puzzle has changed, regenerate
		if (!$scope.hasFreshPuzzle) {
			let _items = [];

			for (puzzleItem of Array.from(_puzzleItems)) {
				_items.push(_process(puzzleItem));
				words.push(puzzleItem.answer);
			}

			// generate the puzzle using the guessing algorithm in puzzle.coffee
			_items = Crossword.Puzzle.generatePuzzle(_items, force);
			if (!_items) {
				return false;
			}

			_drawCurrentPuzzle(_items);

			_qset.items = [{ items: _items }];

			$scope.hasFreshPuzzle = _okToSave;
		}

		for (puzzleItem of Array.from(_puzzleItems)) {
			for (item of Array.from(_qset.items[0].items)) {
				if (item.answers[0].text === puzzleItem.answer) {
					item.questions[0].text = puzzleItem.question;
					item.options.hint = puzzleItem.hint;
					break;
				}
			}
		}

		$scope.unused = false;
		for (item of Array.from($scope.widget.puzzleItems)) {
			if (item.answer === '') { continue; }
			var found = false;
			for (var qitem of Array.from(_qset.items[0].items)) {
				if (item.answer === qitem.answers[0].text) {
					found = true;
				}
			}

			item.found = found;
			if (!found) {
				$scope.unused = true;
			}
		}
		$scope.error = $scope.unused || $scope.tooBig;

		return _okToSave;
	};

	var _drawCurrentPuzzle = function(items) {
		let _top;
		$('#preview_kids').empty();

		let _left = (_top = 0);

		for (var item of Array.from(items)) {
			var letters = item.answers[0].text.split('');
			var x = ~~item.options.x;
			var y = ~~item.options.y;

			for (var i = 0, end = letters.length; i < end; i++) {
				var letterLeft, letterTop;
				if (item.options.dir === 0) {
					letterLeft = x + i;
					letterTop = y;
				} else {
					letterLeft = x;
					letterTop = y + i;
				}

				if (letterLeft > _left) { _left = letterLeft; }
				if (letterTop > _top) { _top = letterTop; }

				var letter = document.createElement('div');

				letter.id = 'letter_' + letterLeft + '_' + letterTop;
				letter.className = 'letter';
				letter.style.top = (letterTop * 25) + 'px';
				letter.style.left = (letterLeft * 27) + 'px';
				letter.innerHTML = letters[i].toUpperCase();

				if (letters[i] === ' ') {
					// if it's a space, make it a black block
					letter.className += ' space';
				}

				$('#preview_kids').append(letter);
			}
		}

		return $scope.$apply(function() {
			$scope.scrollWarn = (_left > 17) || (_top > 20);
			$scope.sizeWarn = (_left > 20) || (_top > 25);
			$scope.tooBig = (_left > 35) || (_top > 45);
			return $scope.error = $scope.unused || $scope.tooBig;
		});
	};

	var _process = function(puzzleItem) {
		const questionObj =
			{text: puzzleItem.question};
		const answerObj = {
			text: puzzleItem.answer,
			value: '100',
			id: ''
		};

		return {
			questions: [questionObj],
			answers: [answerObj],
			id: puzzleItem.id,
			type: 'QA',
			assets: [],
			options: {
				hint: puzzleItem.hint,
				x: 0,
				y: 0
			}
		};
	};

	return Materia.CreatorCore.start($scope);
}
]);

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}