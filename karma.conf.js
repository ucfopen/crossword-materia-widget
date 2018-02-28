module.exports = function(config) {
	config.set({

		autoWatch: false,

		basePath: './',

		browsers: ['PhantomJS'],

		files: [
			'../../js/*.js',
			'https://cdnjs.cloudflare.com/ajax/libs/jquery/1.9.1/jquery.min.js',
			'node_modules/angular/angular.js',
			'node_modules/angular-animate/angular-animate.js',
			'node_modules/angular-mocks/angular-mocks.js',
			'node_modules/angular-sanitize/angular-sanitize.js',
			'build/demo.json',
			'build/creator.puzzle.js',
			'build/print.js',
			'build/creator.js',
			'tests/*.js'
		],

		frameworks: ['jasmine'],

		plugins: [
			'karma-coverage',
			'karma-eslint',
			'karma-jasmine',
			'karma-json-fixtures-preprocessor',
			'karma-junit-reporter',
			'karma-mocha-reporter',
			'karma-phantomjs-launcher'
		],

		preprocessors: {
			'build/*.js': ['coverage', 'eslint'],
			'build/demo.json': ['json_fixtures']
		},

		singleRun: true,

		//plugin-specific configurations
		eslint: {
			stopOnError: true,
			stopOnWarning: false,
			showWarnings: true,
			engine: {
				configFile: '.eslintrc.json'
			}
		},

		jsonFixturesPreprocessor: {
			variableName: '__demo__'
		},

		reporters: ['coverage', 'mocha'],

		//reporter-specific configurations

		coverageReporter: {
			check: {
				global: {
					statements: 100,
					branches:   80,
					functions:  90,
					lines:      90
				},
				each: {
					statements: 100,
					branches:   80,
					functions:  90,
					lines:      90
				}
			},
			reporters: [
				{ type: 'cobertura', subdir: '.', file: 'coverage.xml' }
			]
		}

	});
};

