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

    /* This should call the generateNewPuzzle method with no params
    it('should blur given elements when appropriate', function(){
        $scope.activate = false;

        element = $compile(angular.element('<div focus-me="activate"></div>'))($scope);
        $scope.$digest();

        //$(element[0][0]).blur;
        spyOn($scope, 'generateNewPuzzle');
        $scope.activate = false;
        $scope.$digest();
        $timeout.flush();

        //make sure the element was given focus
        expect(element[0][0].blur).toHaveBeenCalled();
    });
    */
});
