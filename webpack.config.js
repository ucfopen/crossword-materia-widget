const fs = require('fs')
const path = require('path')
const widgetWebpack = require('materia-widget-development-kit/webpack-widget')
const copy = widgetWebpack.getDefaultCopyList()

const outputPath = path.join(process.cwd(), 'build')

const customCopy = copy.concat([
	{
		from: path.join(__dirname, 'node_modules', 'hammerjs', 'hammer.min.js'),
		to: outputPath,
	},
	{
		from: path.join(__dirname, 'src', '_guides', 'assets'),
		to: path.join(outputPath, 'guides', 'assets'),
		toType: 'dir'
	},
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
	'guides/player.tmp.html': [
		path.join(__dirname, 'src', '_guides', 'player.md')
	],
	'guides/creator.tmp.html': [
		path.join(__dirname, 'src', '_guides', 'creator.md')
	]
}

const options = {
	copyList: customCopy,
	entries: entries
}

let buildConfig = widgetWebpack.getLegacyWidgetBuildConfig(options)

module.exports = buildConfig

// module.exports = widgetWebpack.getLegacyWidgetBuildConfig(options)

