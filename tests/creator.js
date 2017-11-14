describe('Crossword', function(){
    var widgetInfo = window.__demo__['build/demo'];
    var qset = widgetInfo.qset;
    var $scope = {};
    var ctrl={};
    var initialpuzzleItems = {};
    var $compile = {};

    describe('Creator Controller', function() {

        module.sharedInjector();
        beforeAll(module('crosswordCreator'));

        beforeAll(inject(function(_$compile_, $rootScope, $controller){
            $scope = $rootScope.$new();
            ctrl = $controller('crosswordCreatorCtrl', { $scope: $scope });
            $compile = _$compile_;
        }));

        beforeEach(function() {
            spyOn(Materia.CreatorCore, 'save').and.callFake(function(title, qset){
                //the creator core calls this on the creator when saving is successful
                $scope.onSaveComplete();
                return {title: title, qset: qset};
            });
            spyOn(Materia.CreatorCore, 'cancelSave').and.callFake(function(msg){
                throw new Error(msg);
            });
        });

        it('should make a new widget', function() {
            $scope.initNewWidget({name: 'crosser'});
            expect($scope.showIntroDialog).toBe(true);
            expect($scope.widget.title).toBe("New Crossword Widget");
        });

        it('should handle saving a null qset', function() {
            expect($scope.widget.puzzleItems.length).toBe(0);
            expect(function(){
                $scope.onSaveClicked();
            }).toThrow(new Error('Required fields not filled out'));
        });

        it('should make an existing widget', function() {
            $scope.initExistingWidget('crosser', widgetInfo, qset.data);
            expect($scope.widget.puzzleItems.length).toBe(6);
            expect($scope.widget.title).toEqual('crosser');
            expect($scope.widget.puzzleItems[0].answer).toEqual('Everest');
            expect($scope.widget.puzzleItems[1].hint).toEqual('Located in India');
            initialpuzzleItems = JSON.parse(JSON.stringify($scope.widget.puzzleItems));
        });

        it('should not do any media imports', function() {
            var media = [{id: "testMedia"}];
            expect($scope.onMediaImportComplete(media)).toBeNull();
        });

        it('should import questions properly', function () {
            var importing = qset.data.items[0].items;
            // clear the current puzzle items accumulated from previous tests
            $scope.widget.puzzleItems = [];

            // verify we have a clean state to test this function
            expect($scope.widget.puzzleItems.length).toBe(0);
            $scope.onQuestionImportComplete(importing);
            expect($scope.widget.puzzleItems).toEqual(initialpuzzleItems);
        });

        /*
        // TODO: no idea how this works
        it('should start a timer', function() {
            timer = $scope.startTimer();
            expect(timer).toBe("");
        });
        */


        it('should add puzzle items', function() {
            $scope.addPuzzleItem();
            expect($scope.widget.puzzleItems[6]).toEqual({
                question: '',
                answer: '',
                hint: '',
                id: '',
                found: true });

            $scope.addPuzzleItem('question', 'answer', 'hint', '1');
            expect($scope.widget.puzzleItems[7]).toEqual({
                question: 'question',
                answer: 'answer',
                hint: 'hint',
                id: '1',
                found: true
            });
            expect($scope.widget.puzzleItems.length).toBe(8);
        });

        it('should remove puzzle items', function() {
            // Check the length before we remove the item
            expect($scope.widget.puzzleItems.length).toBe(8);

            // Remove an item and check the length
            $scope.removePuzzleItem(6); // remove this one because it was empty
            expect($scope.widget.puzzleItems.length).toBe(7);
        });

        /*
        // Commented out so it doesn't pop up all the time
        it('should print the puzzle', inject(function($timeout) {
            print = $scope.printPuzzle();
            $timeout.flush();
            $timeout.verifyNoPendingTasks();
            expect(print).toBe("")
        }));
        */

        it('should hide the intro', function() {
            // Show the intro dialog, then hide it
            $scope.showIntroDialog = true;
            expect($scope.showIntroDialog).toBe(true);
            $scope.introComplete();
            expect($scope.showIntroDialog).toBe(false);
        });

        it('should close all the dialogs', function() {
            // Show all the dialogs
            $scope.showIntroDialog = $scope.showTitleDialog = $scope.showOptionsDialog = true;
            // Close all of them, check that they're closed
            $scope.closeDialog();
            expect($scope.showIntroDialog).toBe(false);
            expect($scope.showTitleDialog).toBe(false);
            expect($scope.showOptionsDialog).toBe(false);
        });

        it('should show and hide the options dialog', function(){
            expect($scope.showOptionsDialog).toBe(false);
            $scope.showOptions();
            expect($scope.showOptionsDialog).toBe(true);
            $scope.closeDialog();
            expect($scope.showOptionsDialog).toBe(false);
        });

        it('should save the widget properly', function() {
            expect($scope.widget.puzzleItems.length).toBe(7);
            var successReport = $scope.onSaveClicked();
            // make sure the title was sent properly
            expect(successReport.title).toBe($scope.widget.title);
            // check the length was the same
            expect(successReport.qset.items[0].items.length).toBe(7);
        });

        it('should not generate a new puzzle if not forced & not necessary', function() {
            puzzleGen = $scope.generateNewPuzzle(false, true);
            expect($scope.hasFreshPuzzle).toBe(true);
            expect(puzzleGen).toBe(false);
        });

        /*
        it('should be force the generation of a new puzzle', inject(function($timeout) {
            puzzleGen = $scope.generateNewPuzzle(true, true);
            $timeout.flush();
            $timeout.verifyNoPendingTasks();
            expect(puzzleGen).toBe("");
        }));
        */

        /*
        it('should not save a broken puzzle', function() {
            // remove all the items
            var length = $scope.widget.puzzleItems.length;
            expect(length).toBe(7);
            for (i = 0; i < length; i++)
                $scope.removePuzzleItem(0)
            length = $scope.widget.puzzleItems.length;
            expect(length).toBe(0);
            // add a item that can't intersect with anything
            $scope.addPuzzleItem('Weird Symbols', '@!#%^#', 'hint', '1');
            $scope.addPuzzleItem('Question', 'Answer', 'hint2', '2');
            var successReport = $scope.onSaveClicked();
            expect(successReport).toBe("");
        });
        */

        it('should not save a puzzle without a title', function() {
            $scope.widget.title = '';
            expect(function(){
                $scope.onSaveClicked();
            }).toThrow(new Error('Required fields not filled out'));
        });

    });
});
