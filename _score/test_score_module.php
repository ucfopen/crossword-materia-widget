<?php
/**
 * @group App
 * @group Materia
 * @group Score
 * @group Crossword
 */
class Test_Score_Modules_Crossword extends \Basetest
{

	protected function _get_qset()
	{
		return json_decode('
			{
				"items":[
					{
						"items":[
							{
								"name":null,
								"type":"QA",
								"assets":null,
								"answers":[
									{
										"value":100,
										"text":"AnswerOne",
										"options":{}
									}
								],
								"questions":[
									{
										"text":"Question One"
									}
								],
								"options":[
									{
										"y":0,
										"posSet":1,
										"dir":1,
										"x":1,
										"hint":"Hint for Question One"
									}
								],
								"id":0
							},
							{
								"name":null,
								"type":"QA",
								"assets":null,
								"answers":[
									{
										"value":100,
										"text":"AnswerTwo",
										"options":{}
									}
								],
								"questions":[
									{
										"text":"Question Two"
									}
								],
								"options":[
									{
										"y":0,
										"posSet":1,
										"dir":1,
										"x":1,
										"hint":"Hint for Question Two"
									}
								],
								"id":0
							},
							{
								"name":null,
								"type":"QA",
								"assets":null,
								"answers":[
									{
										"value":100,
										"text":"AnswerThree",
										"options":{}
									}
								],
								"questions":[
									{
										"text":"Question Three"
									}
								],
								"options":[
									{
										"y":0,
										"posSet":1,
										"dir":1,
										"x":1,
										"hint":"Hint for Question Three"
									}
								],
								"id":0
							}
						],
						"name":"",
						"options":{},
						"assets":[],
						"rand":false
					}
				],
				"name":"",
				"options":[
					{
						"freeWords":0,
						"hintPenalty":50
					}
				],
				"assets":[],
				"rand":false
			}
		');
	}

	protected function _makeWidget()
	{
		$this->_asAuthor();

		$title = 'CROSSWORD SCORE MODULE TEST';
		$widget_id = $this->_find_widget_id('Crossword');
		$qset = (object) ['version' => 1, 'data' => $this->_get_qset()];

		return \Materia\Api::widget_instance_save($widget_id, $title, $qset, false);
	}

	public function test_check_answer()
	{
		$inst = $this->_makeWidget('false');

		$play_session = \Materia\Api::session_play_create($inst->id);
		$qset = \Materia\Api::question_set_get($inst->id, $play_session);

		$logs = array();
		$logs[] = json_decode('{
			"text":"ANSWERONE",
			"type":1004,
			"value":0,
			"item_id":"'.$qset->data['items'][0]['items'][0]['id'].'",
			"game_time":10
		}');

		$logs[] = json_decode('{
			"text":"ANSWERTWO",
			"type":1004,
			"value":0,
			"item_id":"'.$qset->data['items'][0]['items'][1]['id'].'",
			"game_time":11
		}');

		$logs[] = json_decode('{
			"text":"WRONG123456",
			"type":1004,
			"value":0,
			"item_id":"'.$qset->data['items'][0]['items'][2]['id'].'",
			"game_time":12
		}');

		$logs[] = json_decode('{
			"text":"",
			"type":2,
			"value":"",
			"item_id":0,
			"game_time":13
		}');

		$output = \Materia\Api::play_logs_save($play_session, $logs);

		$scores = \Materia\Api::widget_instance_scores_get($inst->id);

		$this_score = \Materia\Api::widget_instance_play_scores_get($play_session);

		$this->assertInternalType('array', $this_score);
		$this->assertEquals(67, $this_score[0]['overview']['score']);
	}

	public function test_check_answerPartial()
	{
		$inst = $this->_makeWidget('false');
		$play_session = \Materia\Api::session_play_create($inst->id);
		$qset = \Materia\Api::question_set_get($inst->id, $play_session);

		$logs = array();

		$logs[] = json_decode('{
			"text":"ANSWERONE",
			"type":1004,
			"value":0,
			"item_id":"'.$qset->data['items'][0]['items'][0]['id'].'",
			"game_time":10
		}');

		$logs[] = json_decode('{
			"text":"ANSWERTWO",
			"type":1004,
			"value":0,
			"item_id":"'.$qset->data['items'][0]['items'][1]['id'].'",
			"game_time":11
		}');

		$logs[] = json_decode('{
			"text":"Hint Received",
			"type":1003,
			"value":-50,
			"item_id":"'.$qset->data['items'][0]['items'][1]['id'].'",
			"game_time":12
		}');

		$logs[] = json_decode('{
			"text":"WRONG123456",
			"type":1004,
			"value":0,
			"item_id":"'.$qset->data['items'][0]['items'][2]['id'].'",
			"game_time":13
		}');

		$logs[] = json_decode('{
			"text":"",
			"type":2,
			"value":"",
			"item_id":0,
			"game_time":14
		}');

		$output = \Materia\Api::play_logs_save($play_session, $logs);

		$scores = \Materia\Api::widget_instance_scores_get($inst->id);

		$this_score = \Materia\Api::widget_instance_play_scores_get($play_session);

		$this->assertInternalType('array', $this_score);
		$this->assertEquals(50, $this_score[0]['overview']['score']);
	}

}