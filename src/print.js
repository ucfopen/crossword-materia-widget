/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
Namespace('Crossword').Print = (function() {
	// constants
	const LETTER_HEIGHT			= 23;
	const LETTER_WIDTH			= 27;

	// mess of rendering HTML to build a printable crossword from the qset
	const _printBoard = function(_instance, _questions) {
		const frame = document.createElement('iframe');
		$('body').append(frame);
		const wnd = frame.contentWindow;
		frame.style.display = 'none';

		wnd.document.write("<h1 style='page-break-after: always'>" + _instance.name + '</h1>');
		wnd.document.write("<h1 style='page-break-before:always'>" + _instance.name + '</h1>');

		const downClues = document.createElement('div');
		downClues.innerHTML = '<strong>Down</strong>';

		const acrossClues = document.createElement('div');
		acrossClues.innerHTML = '<br><strong>Across</strong>';

		wnd.document.body.appendChild(downClues);
		wnd.document.body.appendChild(acrossClues);

		for (var i in _questions) {
			var letters = _questions[i].answers[0].text.toUpperCase().split('');
			var x = ~~_questions[i].options.x;
			var y = ~~_questions[i].options.y;
			var dir = ~~_questions[i].options.dir;

			var question = _questions[i].questions[0].text;
			var questionNumber = parseInt(i) + 1;

			var clue = '<p><strong>' + questionNumber + '</strong>: ' + question + '</p>';

			var _puzzleGrid = {};

			for (var l = 0, end = letters.length-1; l <= end; l++) {
				var letterLeft, letterTop;
				if (dir === 0) {
					letterLeft = x + l;
					letterTop = y;
				} else {
					letterLeft = x;
					letterTop = y + l;
				}

				var numberLabel = document.createElement('div');
				numberLabel.innerHTML = questionNumber;
				numberLabel.style.position = 'absolute';
				numberLabel.style.top = 129 + (y * LETTER_HEIGHT) + 'px';
				numberLabel.style.left = 80 + (x * LETTER_WIDTH) + 'px';
				numberLabel.style.fontSize = 10 + 'px';
				numberLabel.style.zIndex = '1000';

				var letter = wnd.document.createElement('input');
				letter.type = 'text';
				letter.setAttribute('maxlength', 1);
				letter.style.position = 'absolute';
				letter.style.top = 120 + (letterTop * LETTER_HEIGHT) + 'px';
				letter.style.left = 60 + (letterLeft * LETTER_WIDTH) + 'px';
				letter.style.border = 'solid 1px #333';
				letter.style.width = '28px';
				letter.style.height = '24px';

				clue += '<div style="border: solid 1px #333; width: 28px; height: 24px; display: inline-block;"> </div>';

				if (letters[l] === ' ') {
					// if it's a space, make it a black block
					letter.style.backgroundColor = '#000';
				}

				wnd.document.body.appendChild(letter);
				wnd.document.body.appendChild(numberLabel);
			}

			if (dir) {
				downClues.innerHTML += clue;
			} else {
				acrossClues.innerHTML += clue;
			}
		}


		return wnd.print();
	};

	return {printBoard: _printBoard};
})();

