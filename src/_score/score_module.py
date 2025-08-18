from scoring.module import ScoreModule


class Crossword(ScoreModule):
    INITIAL_SCORE = 100
    HINT_INTERACTION = "question_hint"

    def __init__(self, play):
        super().__init__(play)
        self.points_lost = 0.0
        self.hint_deductions = 0.0
        self.modifiers = {}

    def handle_log_question_answered(self, log):
        self.scores[log.item_id] = self.check_answer(log)
        # Update totals once here
        self.total_questions += 1

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

        # Default to full credit unless a hint modifier is present
        if log.item_id in self.modifiers:
            deduction = float(self.modifiers[log.item_id])
            score = base_score * percent_correct * ((100 - deduction) / 100)
        else:
            score = base_score * percent_correct

        return score

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
            if i < len(answer_chars) and self.is_guessable_letter(answer_chars[i]):
                if i < len(submitted_chars) and submitted_chars[i] == ' ':
                    submitted_chars[i] = '_'
        return "".join(submitted_chars)

    def get_feedback(self, log, answers):
        for ans in answers:
            if "options" in ans and "feedback" in ans["options"]:
                return ans["options"]["feedback"]
        return None

    def get_overview_items(self):
        overview = []
        if self.hint_deductions < 0:
            overview.append({"message": "Hint Deductions", "value": self.hint_deductions})
        overview.append({"message": "Points Lost", "value": self.points_lost})
        overview.append({"message": "Final Score", "value": self.calculated_percent})
        return overview
