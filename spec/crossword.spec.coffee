client = {}

describe 'Testing framework', ->
	it 'should load widget', (done) ->
		require('./widgets.coffee') 'crossword', ->
			client = this
			done()
	, 15000

crosswordClick = (id) ->
	client.execute "$('" + id + "').click()", null, ->
		# something


crosswordTypeString = (string) ->
	for i in [0...string.length]
		code = string.charCodeAt(i)

		crosswordKeyInput(code)

crosswordKeyInput = (code) ->
	client.execute("var ge = $.Event('keydown'); ge.keyCode = "+code+"; $('#boardinput').trigger(ge)", null, ->

		)

crosswordExpectString = (startx, starty, dir, string, callback) ->
	i = 0

	f = ->
		client.getText "#letter_" + startx + "_" + starty, (err, text) ->
			expect(err).toBeNull()

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
		expect(err).toBeNull()
		expect(classes).toContain('highlight')
		callback()

describe 'Crossword Player', ->
	it 'should be able to click to select a word', (done) ->
		crosswordClick("#letter_0_3")
		done()

	it 'should highlight the letter we clicked', (done) ->
		crosswordExpectHighlight '#letter_0_3', ->
			done()

	it 'should be able to type eiffel tower', (done) ->
		crosswordTypeString("EIFFELTOWER")
		crosswordExpectString 0, 3, 0, "EIFFEL TOWER", ->
			done()
	
	it 'should be able to move left with arrow keys', (done) ->
		crosswordKeyInput(37)
		crosswordKeyInput(37)
		crosswordKeyInput(37)
		crosswordKeyInput(37)
		crosswordExpectHighlight '#letter_7_3', ->
			done()

	it 'should be able to type "the white house"', (done) ->
		crosswordTypeString("THEWHITEHOUSE")
		crosswordExpectString 7, 3, 1, "THE WHITE HOUSE", ->
			done()
	
	it 'should highlight clues when clicked', (done) ->
		crosswordClick("#clue_2")
		done()

		

###
describe 'Score page', ->
	it 'should get a 90', (done) ->
		client.pause(2000)
		client.getTitle (err, title) ->
			expect(err).toBeNull()
			expect(title).toBe('Score Results | Materia')
			client
				.waitFor('.overall_score')
				.getText '.overall_score', (err, text) ->
					expect(err).toBeNull()
					expect(text).toBe('90%')
					client.call(done)
					client.end()

###
