client = {}

describe 'Testing framework', ->
	it 'should load test dependencies', (done) ->
		require('./widgets.coffee') 'crossword', ->
			client = this
			done()
	, 25000

crosswordClick = (id) ->
	client.execute "$('" + id + "').click()"

crosswordTypeString = (string) ->
	for i in [0...string.length]
		code = string.charCodeAt(i)
		crosswordKeyInput(code)
		client.pause(50)

crosswordKeyInput = (code) ->
	client.execute("var ge = $.Event('keydown'); ge.keyCode = "+code+"; $('#boardinput').trigger(ge)")

crosswordExpectString = (startx, starty, dir, string, callback) ->
	i = 0

	f = ->
		client.getText "#letter_" + startx + "_" + starty, (err, text) ->
			if dir
				starty++
			else
				startx++

			if string.charAt(i) != " "
				expect(text).toBe(string.charAt(i))

			i++

			if i == string.length
				callback()
			else
				f()
	f()

crosswordExpectHighlight = (id, callback) ->
	client.getAttribute id, 'class', (err, classes) ->
		expect(classes).toContain('highlight')
		callback()

describe 'Crossword Player', ->
	it 'should be able to click to select a word', (done) ->
		crosswordClick("#letter_0_3")
		done()

	it 'should highlight the letter we clicked', (done) ->
		crosswordExpectHighlight '#letter_0_3', done

	it 'should be able to type eiffel tower', (done) ->
		crosswordTypeString("EIFFELTOWER")
		crosswordExpectString 0, 3, 0, "EIFFEL TOWER", done

	it 'should be able to move left with arrow keys', (done) ->
		crosswordKeyInput(37)
		crosswordKeyInput(37)
		crosswordKeyInput(37)
		crosswordKeyInput(37)
		crosswordExpectHighlight '#letter_7_3', done

	it 'should be able to type "the white house"', (done) ->
		crosswordTypeString("THEWHITEHOUSE")
		crosswordExpectString 7, 3, 1, "THE WHITE HOUSE", done

	it 'should be able to type the tajmahal', (done) ->
		crosswordClick("#letter_5_17")
		crosswordExpectHighlight '#letter_5_17', ->
			crosswordTypeString("THETAJMAHAL")
			client.pause(1000)
			crosswordExpectString 5, 17, 0, "THE TAJ-MAHAL", done

	it 'should be able to get a hint', (done) ->
		crosswordClick("#letter_7_4")
		client.execute "$('#hintbtn_2').click()", ->
			client.execute "$('#okbtn').click()", ->
				client.getText "#hintspot_2", (err, text) ->
					expect(text).toContain("They painted it white")
					done()

	it 'should highlight clues when clicked', (done) ->
		client.execute "$('#clue_3').mouseup()", ->
			crosswordExpectHighlight '#clue_3', done

	it 'should be able to type answer after clicking clue', (done) ->
		crosswordTypeString("STONEHENGE")
		crosswordExpectString 6, 10, 0, "STONEHENGE", done

	it 'should be able to get a free word', (done) ->
		client.execute "$('#clue_4').mouseup()", ->
			client.execute "$('#freewordbtn_4').click()", ->
				crosswordExpectString 1, 0, 1, "SPHINX", done

	it 'should display hyphens in words', (done) ->
		client.getText "#letter_12_17", (err, text) ->
			expect(text).toBe('-')
			done()

	it 'should make hyphens protected from input', (done) ->
		client.getAttribute "#letter_12_17", 'data-protected', (err, attr) ->
			expect(attr).toBe('1')
			done()

	it 'should make black spaces protected from input', (done) ->
		client.getAttribute "#letter_7_12", 'data-protected', (err, attr) ->
			expect(attr).toBe('1')
			done()

	it 'should display black squares for spaces', (done) ->
		client.getCssProperty "#letter_7_12", 'background-color', (err, color) ->
			expect(color.value).toBe('rgba(0,0,0,1)')
			done()

	it 'should be able to submit', (done) ->
		client.execute "$('#checkBtn').click()", ->
			client.execute "$('#okbtn').click()", ->
				done()


describe 'Score page', ->
	it 'should get a 77', (done) ->
		client.pause(2000)
		client.getTitle (err, title) ->
			expect(title).toBe('Score Results | Materia')
			client
				.waitFor('.overall-score, .overall_score')
				.getText '.overall-score, .overall_score', (err, text) ->
					expect(text).toBe('77%')
					client.call(done)
					client.end()

