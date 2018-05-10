const path = require('path')
const CopyPlugin = require('copy-webpack-plugin')

let srcPath = path.join(process.cwd(), 'src')
let outputPath = path.join(process.cwd(), 'build')

// load the reusable legacy webpack config from materia-widget-dev
let webpackConfig = require('materia-widget-development-kit/webpack-widget').getLegacyWidgetBuildConfig()

webpackConfig.entry['scoreScreen.js'] = [path.join(__dirname, 'src', 'scoreScreen.coffee')]
webpackConfig.entry['scoreScreen.css'] = [
	path.join(__dirname, 'src', 'scoreScreen.html'),
	path.join(__dirname, 'src', 'scoreScreen.scss')
]

webpackConfig.entry['print.js'] = [path.join(__dirname, 'src', 'print.coffee')]
webpackConfig.entry['creator.puzzle.js'] = [path.join(__dirname, 'src', 'creator.puzzle.coffee')]

let additionalCopy = new CopyPlugin([
	{
		from: `${srcPath}/classList.min.js`,
		to: outputPath,
	},
	{
		from: `${srcPath}/hammer.min.js`,
		to: outputPath,
	},
])

webpackConfig.plugins.push(additionalCopy)

module.exports = webpackConfig
