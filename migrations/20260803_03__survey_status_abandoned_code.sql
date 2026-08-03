INSERT INTO common_codes (code_group, code, code_name, description, display_order, is_active)
SELECT 'SURVEY_STATUS', 'ABANDONED', '중단', '사용자가 처음부터 다시 시작해 폐기된 설문', 30, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM common_codes WHERE code_group = 'SURVEY_STATUS' AND code = 'ABANDONED'
);
