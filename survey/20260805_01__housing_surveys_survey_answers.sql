-- 설문 결과 저장에 필요한 컬럼과 공통코드.
-- 이미 운영 중인 DB용 변경분이다. 새로 만드는 DB는 house.sql 하나만 실행하면 된다.
-- 여러 번 실행해도 안전하다.

-- 1. 설문 답변과 계산 결과
--    주소 없이 금액을 직접 받는 설문(POST /api/survey/submit)이 채운다.
--    앞의 5개는 사용자 입력, 뒤의 3개는 백엔드 계산 결과다.
SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'housing_surveys'
        AND column_name = 'acquisition_price_amount') > 0,
    'SELECT ''housing_surveys 설문 답변 컬럼이 이미 있습니다'' AS skipped',
    'ALTER TABLE housing_surveys
        ADD COLUMN acquisition_price_amount BIGINT UNSIGNED NULL
            COMMENT ''설문 입력 과거 취득가액'' AFTER max_purchase_budget_amount,
        ADD COLUMN transfer_price_amount BIGINT UNSIGNED NULL
            COMMENT ''설문 입력 예상 양도가액'' AFTER acquisition_price_amount,
        ADD COLUMN holding_years SMALLINT UNSIGNED NULL
            COMMENT ''보유기간(년)'' AFTER transfer_price_amount,
        ADD COLUMN residence_years SMALLINT UNSIGNED NULL
            COMMENT ''거주기간(년)'' AFTER holding_years,
        ADD COLUMN regulated_area BOOLEAN NULL
            COMMENT ''조정대상지역 주택 여부'' AFTER residence_years,
        ADD COLUMN capital_gains_tax_amount BIGINT UNSIGNED NULL
            COMMENT ''Backend-calculated 추정 양도소득세'' AFTER regulated_area,
        ADD COLUMN brokerage_fee_amount BIGINT UNSIGNED NULL
            COMMENT ''Backend-calculated 중개수수료(부가세 포함)'' AFTER capital_gains_tax_amount,
        ADD COLUMN net_proceeds_amount BIGINT UNSIGNED NULL
            COMMENT ''Backend-calculated 매도 실수령액'' AFTER brokerage_fee_amount'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. "처음부터 다시" 재시작 시 기존 설문을 옮겨둘 상태.
--    active_user_id 생성 컬럼이 status = 'IN_PROGRESS' 일 때만 user_id 를 갖고
--    uq_active_housing_survey 가 그 값에만 유일성을 걸므로, 상태를 옮겨야
--    같은 사용자의 새 설문을 INSERT 할 수 있다.
INSERT INTO common_codes (
    code_group, code, code_name, description, display_order, is_active
)
SELECT 'SURVEY_STATUS', 'ABANDONED', '중단',
       '사용자가 처음부터 다시 시작해 폐기된 설문', 30, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM common_codes
     WHERE code_group = 'SURVEY_STATUS' AND code = 'ABANDONED'
);
