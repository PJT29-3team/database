-- financial_product_preference 에 survey_id 를 더한다.
--
-- 추천 조건이 사용자에만 묶여 있어 "마지막 1건" 만 남았다. 그래서 마이페이지에서
-- 지난 설문의 보고서를 받으면 자금 배분이 늘 최신 조건으로 만들어졌다.
-- 어느 설문에서 넣은 조건인지 적어 두면 그 설문의 값으로 되살릴 수 있다.
--
-- 이미 쌓인 행은 어느 설문 것인지 기록이 없어 NULL 로 둔다.
-- NULL 인 행은 예전처럼 "사용자의 마지막 조건" 으로만 쓰인다.
--
-- 여러 번 실행해도 안전하다.

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'financial_product_preference'
        AND column_name = 'survey_id') > 0,
    'SELECT ''financial_product_preference.survey_id 가 이미 있습니다'' AS skipped',
    'ALTER TABLE financial_product_preference
        ADD COLUMN survey_id BIGINT UNSIGNED NULL
            COMMENT ''이 조건을 입력한 설문. 옛 행은 기록이 없어 NULL'' AFTER user_id'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.statistics
      WHERE table_schema = DATABASE()
        AND table_name = 'financial_product_preference'
        AND index_name = 'idx_financial_product_preference_survey') > 0,
    'SELECT ''idx_financial_product_preference_survey 가 이미 있습니다'' AS skipped',
    'ALTER TABLE financial_product_preference
        ADD INDEX idx_financial_product_preference_survey
            (survey_id, financial_product_preference_id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
