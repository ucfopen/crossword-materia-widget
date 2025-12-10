from core.models import Log
from scoring.module import ScoreModule


class Crossword(ScoreModule):
    INITIAL_SCORE = 100
    HINT_INTERACTION = "question_hint"

    def __init__(self, play):
        super().__init__(play)
        self.points_lost = 0.0
        self.hint_deductions = 0.0
        self.modifiers = {}
        self.incorrect_deductions = []

    def check_answer(self, log):

        question = self.get_question_by_item_id(log.item_id)
        if not question:
            return 0

        correct_text = question.get("answers")[0]["text"]
        answer = self.normalize_string(correct_text)
        response = self.normalize_string(log.text)

        max_len = max(len(answer), len(response))

        match_num = 0
        guessable = 0

        for i in range(max_len):
            if self.is_guessable_letter(answer[i]):
                guessable += 1
                if answer[i] == response[i]:
                    match_num += 1

        if guessable == 0:
            return 0

        percent_correct = match_num / guessable
        base_score = self.INITIAL_SCORE

        # save the raw point deduction
        self.incorrect_deductions.append(
            base_score - percent_correct * base_score
        )

        # Default to full credit unless a hint modifier is present
        if log.item_id in self.modifiers:
            deduction = float(self.modifiers[log.item_id])
            hint_factor = 1 - (- deduction / self.INITIAL_SCORE)
            score = (base_score * percent_correct) * hint_factor
            self.hint_deductions += (base_score * percent_correct) - score
        else:
            score = base_score * percent_correct

        return score

    def handle_log_widget_interaction(self, log):
        if log.text == self.HINT_INTERACTION:
            self.modifiers[log.item_id] = log.value

    def calculate_score(self):
        super().calculate_score()
        if self.total_questions > 0:
            self.hint_deductions = -1 * (self.hint_deductions /
                                         self.total_questions)

            # points lost represents the point value deduction
            # from incorrect letter guesses, sans hint deduction
            self.points_lost = -1 * (
                sum(self.incorrect_deductions) / self.total_questions
            )

    def normalize_string(self, string_val: str):
        return list(string_val.lower())

    def is_guessable_letter(self, char: str) -> bool:
        return char.isalpha() or char.isdigit()

    def get_ss_answer(self, log, question):
        correct_text = question.get("answers")[0]["text"]
        answer_chars = self.normalize_string(correct_text)
        submitted_chars = self.normalize_string(log.text)

        max_len = max(len(answer_chars), len(submitted_chars))
        if len(submitted_chars) < max_len:
            submitted_chars += [" "] * (max_len - len(submitted_chars))
        for i in range(max_len):
            if (i < len(answer_chars) and 
                    self.is_guessable_letter(answer_chars[i])):
                if i < len(submitted_chars) and submitted_chars[i] == ' ':
                    submitted_chars[i] = '_'
        return "".join(submitted_chars)

    def get_feedback(self, log, answers):
        for play_log in self.logs:
            if (play_log.log_type == Log.LogType.SCORE_WIDGET_INTERACTION
                    and play_log.item_id == log.item_id):
                return "Hint Received"

        return None

    def get_overview_items(self):
        overview = []
        if self.hint_deductions < 0:
            overview.append({
                "message": "Hint Deductions",
                "value": self.hint_deductions
            })
        overview.append({
            "message": "Points Lost",
            "value": self.points_lost
            })
        overview.append({
            "message": "Final Score",
            "value": self.calculated_percent
            })
        return overview
