const path = require('path')
const widgetWebpack = require('materia-widget-development-kit/webpack-widget')
const rules = widgetWebpack.getDefaultRules()
const copy = widgetWebpack.getDefaultCopyList()

const srcPath = path.join(process.cwd(), 'src')
const outputPath = path.join(process.cwd(), 'build')

const customCopy = copy.concat([
	{
		from: `${srcPath}/classList.min.js`,
		to: outputPath,
	},
	{
		from: `${srcPath}/hammer.min.js`,
		to: outputPath,
	},
	{
		from: `${srcPath}/_helper-docs/assets`,
		to: `${outputPath}/guides/assets`,
		toType: 'dir'
	}
])

const customRules = [
	rules.loaderDoNothingToJs,
	rules.loaderCompileCoffee,
	rules.copyImages,
	rules.loadHTMLAndReplaceMateriaScripts,
	rules.loadAndPrefixCSS,
	rules.loadAndPrefixSASS,
	rules.loadGuideTemplate
]

const entries = {
	'creator.js': [
		path.join(__dirname, 'src', 'creator.coffee')
	],
	'player.js': [
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
	'print.js': [
		path.join(__dirname, 'src', 'print.coffee')
	],
	'creator.puzzle.js': [
		path.join(__dirname, 'src', 'creator.puzzle.coffee')
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
	moduleRules: customRules,
	copyList: customCopy,
	entries: entries
}

module.exports = widgetWebpack.getLegacyWidgetBuildConfig(options)
