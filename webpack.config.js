const path = require('path')
const widgetWebpack = require('materia-widget-development-kit/webpack-widget')
const rules = widgetWebpack.getDefaultRules()
const copy = widgetWebpack.getDefaultCopyList()

const srcPath = path.join(process.cwd(), 'src')
const outputPath = path.join(process.cwd(), 'build')

const customCopy = copy.concat([
	{
		from: `${srcPath}/_helper-docs/assets`,
		to: `${outputPath}/guides/assets`,
		toType: 'dir'
	},
	{
		from: path.join(__dirname, 'node_modules', 'hammerjs', 'hammer.min.js'),
		to: outputPath,
	}
])

const entries = {
	'creator.js': [
		path.join(__dirname, 'src', 'print.coffee'),
		path.join(__dirname, 'src', 'creator.puzzle.coffee'),
		path.join(__dirname, 'src', 'creator.coffee')
	],
	'player.js': [
		path.join(__dirname, 'src', 'print.coffee'),
		path.join(__dirname, 'src', 'player.coffee')
	],
	'creator.css': [
		path.join(__dirname, 'src', 'creator.html'),
		path.join(__dirname, 'src', 'creator.scss')
	],
	'player.css': [
		path.join(__dirname, 'src', 'player.html'),
		path.join(__dirname, 'src', 'player.scss')
	],
	'scoreScreen.js': [
		path.join(__dirname, 'src', 'scoreScreen.coffee')
	],
	'scoreScreen.css': [
		path.join(__dirname, 'src', 'scoreScreen.html'),
		path.join(__dirname, 'src', 'scoreScreen.scss')
	],
	'guides/guideStyles.css': [
		path.join(__dirname, 'src', '_helper-docs', 'guideStyles.scss')
	],
	'guides/creator.html': [
		__dirname + '/src/_helper-docs/creatorTemplate.html'
	],
	'guides/player.html': [
		__dirname + '/src/_helper-docs/playerTemplate.html'
	]
}

const options = {
	copyList: customCopy,
	entries: entries
}

module.exports = widgetWebpack.getLegacyWidgetBuildConfig(options)
