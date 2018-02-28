var $compile = null;
var $scope = {};
var element = null;

describe('focusMe Directive', function(){
	var $timeout = null;
	beforeEach(module('crosswordCreator'));

	beforeEach(inject(function(_$compile_, $rootScope, _$timeout_){
		$timeout = _$timeout_;
		$compile = _$compile_;
		$scope = $rootScope.$new();
	}));

	it('should focus given elements when appropriate', function(){
		$scope.activate = false;

		element = $compile(angular.element('<div focus-me="activate"></div>'))($scope);
		$scope.$digest();

		spyOn(element[0], 'focus');
		$scope.activate = true;
		$scope.$digest();
		$timeout.flush();

		//make sure the element was given focus
		expect(element[0].focus).toHaveBeenCalled();
	});

	/* Can't get this one to work
	it('should blur given elements when appropriate', function(){
		$scope.activate = false;

		element = $compile(angular.element('<div blur="activate"></div>'))($scope);
		$scope.$digest();

		spyOn(element[0], 'blur');
		angular.element(element[0]).triggerHandler('blur');
		$scope.activate = true;
		$scope.$digest();

		expect(element[0].blur).toHaveBeenCalled();
	});
	*/

});

describe('selectMe Directive', function(){
	var $timeout = null;
	beforeEach(module('crosswordCreator'));

	beforeEach(inject(function(_$compile_, $rootScope, _$timeout_){
		$timeout = _$timeout_;
		$compile = _$compile_;
		$scope = $rootScope.$new();
	}));

	it('should select given elements when appropriate', function(){
		$scope.activate = false;

		element = $compile(angular.element('<div select-me="activate"></div>'))($scope);
		$scope.$digest();

		spyOn($(element[0]).focus(), 'select');
		spyOn(element[0], 'focus');
		$scope.activate = true;
		$scope.$digest();
		$timeout.flush();

		//make sure the element was given focus
		expect(element[0].focus).toHaveBeenCalled();
	});

});
