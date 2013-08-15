<?php
/**
 * Materia
 * It's a thing
 *
 * @package	    Materia
 * @version    1.0
 * @author     UCF New Media
 * @copyright  2011 New Media
 * @link       http://kogneato.com
 */


/**
 * NEEDS DOCUMENTATION
 *
 * The widget managers for the Materia package.
 *
 * @package	    Main
 * @subpackage  scoring
 * @category    Modules
  * @author      ADD NAME HERE
 */

namespace Materia;

class Score_Modules_Crossword extends Score_Module
{
	/** @var array Stores the individual scores in an array using question item_ids as keys */
	const INITIAL_SCORE = 100;

	const HINT_INTERACTION = 'question_hint';

	public $points_lost;
	public $hint_deductions;
	public $modifiers = [];
	protected $scores = [];

	protected function handle_log_question_answered($log)
	{
		$log->text = strtolower($log->text);
		$this->total_questions++;
		$this->scores[$log->item_id] = $this->check_answer($log); // score the question and add it to the total
	}

	protected function handle_log_widget_interaction($log)
	{
		if ($log->text == $this::HINT_INTERACTION)
		{
			$this->modifiers[$log->item_id] = (float) $log->value;
			// Add hit deduction to question's answer's feedback
			$this->questions[$log->item_id]->answers[0]['options']['feedback'] = 'Hint Received';
		}
	}

	// calculate the percentage and count total points
	protected function calculate_score()
	{
		$points_lost     = [];
		$updated_scores  = [];
		$hint_deductions = [];

		// if a score has a matching modifier associated with it, reduce the maximum possible question score by that amount
		foreach ($this->scores as $score_key => $score_val)
		{
			$updated_scores[$score_key] = $score_val;
			$points_lost[$score_key] = $this::INITIAL_SCORE - $score_val;

			if (isset($this->modifiers[$score_key]))
			{
				// Modifier is a negative integer, need to convert to a positive percentage
				$updated_scores[$score_key] *= 1 - (-$this->modifiers[$score_key] / $this::INITIAL_SCORE);
				$hint_deductions[$score_key] = $score_val - $updated_scores[$score_key];
			}
		}

		// Cannot generate a puzzle with zero questions => $this->total_questions > 0
		$this->points_lost        = -1 * array_sum($points_lost) / $this->total_questions;
		$this->hint_deductions    = -1 * array_sum($hint_deductions) / $this->total_questions;
		$this->verified_score     = array_sum($updated_scores);
		$this->calculated_percent = $this->verified_score / $this->total_questions;
	}

	public function check_answer($log)
	{
		if (isset($this->questions[$log->item_id]))
		{
			$question  = $this->questions[$log->item_id];
			$answer    = $this->normalize_string($question->answers[0]['text']);
			$submitted = $this->normalize_string($log->text);
			$match_num = 0;
			$guessable = 0;
			// Student could have left answer blank
			if (count($answer) > 0)
			{
				foreach ($answer as $index => $letter)
				{
					// if the letter is a guessable letter, make sure it matches
					if ($this->is_guessable_letter($letter))
					{
						$guessable++;
						if ($letter == $submitted[$index])
						{
							$match_num++;
						}
					}
				}
			}
			if ($guessable == 0) return 0;
			return $match_num / (float)$guessable * $this::INITIAL_SCORE;
		}
		return 0;
	}

	private function normalize_string($string)
	{
		return str_split(strtolower($string));
	}

	private function is_guessable_letter($char)
	{
		return  preg_match('/^[0-9a-z]+$/i', $char);
	}

	public function get_score_page_answer($log)
	{
		$question  = $this->questions[$log->item_id];
		$answer    = $this->normalize_string($question->answers[0]['text']);
		$submitted = $this->normalize_string($log->text);

		foreach ($answer as $index => $letter)
		{
			// space is guessable but user left blank, replace space with underscore
			if ($this->is_guessable_letter($letter) && $submitted[$index] == ' ')
			{
				$submitted[$index] = '_';
			}
		}

		return implode($submitted);
	}

	protected function get_feedback($log, $answers)
	{
		foreach ($answers as $answer)
		{
			if (isset($answer['options']['feedback']))
			{
				return $answer['options']['feedback'];
			}
		}
	}

	protected function get_overview_items()
	{
		$overview_items = [];

		if ($this->hint_deductions < 0)
		{
			$overview_items[] = ['message' => 'Hint Deductions', 'value' => $this->hint_deductions];
		}

		$overview_items[] = ['message' => 'Points Lost', 'value' => $this->points_lost];
		$overview_items[] = ['message' => 'Final Score', 'value' => $this->calculated_percent];

		return $overview_items;
	}
}