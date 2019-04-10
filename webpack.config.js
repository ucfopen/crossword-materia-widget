const path = require('path')
const srcPath = path.join(process.cwd(), 'src') + path.sep
const outputPath = path.join(process.cwd(), 'build')
const widgetWebpack = require('materia-widget-development-kit/webpack-widget')
const entries = widgetWebpack.getDefaultEntries()
const copy = widgetWebpack.getDefaultCopyList()

const newCopy = copy.concat([
	{
		from: path.join(__dirname, 'node_modules', 'hammerjs', 'hammer.min.js'),
		to: outputPath,
	},
	{
		from: `${srcPath}/classList.min.js`,
		to: outputPath,
	},
	{
		from: `${srcPath}/_helper-docs`,
		to: `${outputPath}/_helper-docs`,
		toType: 'dir'
	}
])

entries['scoreScreen.js'] = [
	srcPath+'scoreScreen.coffee'
]
entries['scoreScreen.css'] = [
	srcPath+'scoreScreen.html',
	srcPath+'scoreScreen.scss'
]

entries['player.js'] = [
	srcPath+'print.coffee',
	srcPath+'player.coffee',
]
entries['creator.js'] = [
	srcPath+'print.coffee',
	srcPath+'creator.puzzle.coffee',
	srcPath+'creator.coffee',
]


// options for the build
const options = {
	entries: entries,
	copyList: newCopy,
}

module.exports = widgetWebpack.getLegacyWidgetBuildConfig(options)
