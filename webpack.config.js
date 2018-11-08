const path = require('path')

let srcPath = path.join(process.cwd(), 'src')
let outputPath = path.join(process.cwd(), 'build')

let webpackWidget = require('materia-widget-development-kit/webpack-widget')

let defaultCopy = webpackWidget.getDefaultCopyList()

let webpackConfig = webpackWidget.getLegacyWidgetBuildConfig({
	//pass in extra files for webpack to copy
	copyList: [
		...defaultCopy,
		{
			from: `${srcPath}/classList.min.js`,
			to: outputPath,
		},
		{
			from: `${srcPath}/hammer.min.js`,
			to: outputPath,
		},
	]
})

webpackConfig.entry['scoreScreen.js'] = [path.join(__dirname, 'src', 'scoreScreen.coffee')]
webpackConfig.entry['scoreScreen.css'] = [path.join(__dirname, 'src', 'scoreScreen.html'), path.join(__dirname, 'src', 'scoreScreen.scss')]
webpackConfig.entry['print.js'] = [path.join(__dirname, 'src', 'print.coffee')]
webpackConfig.entry['creator.puzzle.js'] = [path.join(__dirname, 'src', 'creator.puzzle.coffee')]

module.exports = webpackConfig
