const fs = require('fs')
const path = require('path')
const widgetWebpack = require('materia-widget-development-kit/webpack-widget')
const copy = widgetWebpack.getDefaultCopyList()

const outputPath = path.join(process.cwd(), 'build')
const srcPath = path.join(__dirname, 'src') + path.sep

const customCopy = copy.concat([
	{
		from: path.join(__dirname, 'node_modules', 'hammerjs', 'hammer.min.js'),
		to: outputPath,
	},
	{
		from: path.join(srcPath, '_guides', 'assets'),
		to: path.join(outputPath, 'guides', 'assets'),
		toType: 'dir'
	},
])

const entries = {
	'player': [
		path.join(srcPath, 'player.html'),
		path.join(srcPath, 'print.coffee'),
		path.join(srcPath, 'player.coffee'),
		path.join(srcPath, 'player.scss')
	],
	'creator': [
		path.join(srcPath, 'creator.html'),
		path.join(srcPath, 'print.coffee'),
		path.join(srcPath, 'creator.coffee'),
		path.join(srcPath, 'creator.puzzle.coffee'),
		path.join(srcPath, 'creator.scss'),
	],
	'scoreScreen': [
		path.join(srcPath, 'scoreScreen.html'),
		path.join(srcPath, 'scoreScreen.coffee'),
		path.join(srcPath, 'scoreScreen.scss')
	]
}

const options = {
	copyList: customCopy,
	entries: entries
}

let buildConfig = widgetWebpack.getLegacyWidgetBuildConfig(options)

module.exports = buildConfig

// module.exports = widgetWebpack.getLegacyWidgetBuildConfig(options)

