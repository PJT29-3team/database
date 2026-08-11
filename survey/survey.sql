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


-- 설문에서 고른 희망 평수(전용면적) 저장 컬럼.
-- 추천 조회가 이 범위로 매물을 거른다. NULL 이면 평수를 가리지 않는다.
-- 여러 번 실행해도 안전하다.
--
-- 단위는 ㎡다. house.house_size 가 ㎡이므로 비교 시 변환이 없어야
-- 인덱스를 탈 수 있다. 화면에 보이는 "평"은 표시 단계에서만 환산한다.
SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'housing_surveys'
        AND column_name = 'desired_min_area_sqm') > 0,
    'SELECT ''housing_surveys 희망 면적 컬럼이 이미 있습니다'' AS skipped',
    'ALTER TABLE housing_surveys
        ADD COLUMN desired_min_area_sqm DECIMAL(6,2) NULL
            COMMENT ''설문 입력 희망 최소 전용면적(㎡). NULL이면 하한 없음'' AFTER net_proceeds_amount,
        ADD COLUMN desired_max_area_sqm DECIMAL(6,2) NULL
            COMMENT ''설문 입력 희망 최대 전용면적(㎡). NULL이면 상한 없음'' AFTER desired_min_area_sqm'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name = 'survey_recommendation_items') > 0,
    'SELECT ''survey_recommendation_items 가 이미 있습니다'' AS skipped',
    'CREATE TABLE survey_recommendation_items (
        recommendation_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
            NOT NULL DEFAULT (UUID()),
        survey_id BIGINT UNSIGNED NOT NULL COMMENT ''어떤 설문으로 추천했는지'',
        rank_no TINYINT UNSIGNED NOT NULL COMMENT ''추천 순위. 1이 1위'',

        house_id INT UNSIGNED NOT NULL
            COMMENT ''조회 시점 house_id. 논리 참조라 외래키를 걸지 않는다'',

        house_name VARCHAR(200) NOT NULL COMMENT ''조회 시점 단지명'',
        jibun_address VARCHAR(300) NULL COMMENT ''조회 시점 지번주소'',
        house_price_amount BIGINT UNSIGNED NOT NULL COMMENT ''조회 시점 매매가(원)'',
        exclusive_area_sqm DECIMAL(6,2) NULL COMMENT ''조회 시점 전용면적(㎡)'',
        latitude DECIMAL(10,7) NULL,
        longitude DECIMAL(10,7) NULL,

        total_score TINYINT UNSIGNED NOT NULL COMMENT ''조회 시점 종합 점수'',
        remaining_amount BIGINT NULL
            COMMENT ''실수령액 - 매매가. 예산을 넘는 매물이면 음수'',

        profile_code VARCHAR(40) NOT NULL COMMENT ''그때 적용한 성향'',

        del_yn CHAR(1) NOT NULL DEFAULT ''N'',
        created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        created_by VARCHAR(100) NOT NULL DEFAULT ''SYSTEM'',
        updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
            ON UPDATE CURRENT_TIMESTAMP(6),
        updated_by VARCHAR(100) NOT NULL DEFAULT ''SYSTEM'',

        PRIMARY KEY (recommendation_item_id),
        UNIQUE KEY uq_survey_recommendation_items_row_uuid (row_uuid),
        UNIQUE KEY uq_survey_recommendation_items_rank (survey_id, rank_no),
        INDEX idx_survey_recommendation_items_house (house_id),
        CONSTRAINT fk_survey_recommendation_items_survey
            FOREIGN KEY (survey_id) REFERENCES housing_surveys (survey_id)
            ON DELETE CASCADE ON UPDATE RESTRICT,
        CONSTRAINT chk_survey_recommendation_items_rank CHECK (rank_no BETWEEN 1 AND 50),
        CONSTRAINT chk_survey_recommendation_items_score CHECK (total_score <= 100)
    ) ENGINE = InnoDB
      DEFAULT CHARSET = utf8mb4
      COLLATE = utf8mb4_0900_ai_ci
      COMMENT = ''설문 시점에 보여준 추천 매물 스냅샷'''
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'survey_recommendation_items'
        AND column_name = 'ai_summary') > 0,
    'SELECT ''survey_recommendation_items.ai_summary 가 이미 있습니다'' AS skipped',
    'ALTER TABLE survey_recommendation_items
        ADD COLUMN ai_summary TEXT NULL
            COMMENT ''매물 상세의 AI 요약(JSON). 처음 열 때 한 번 만들어 두고 다시 쓴다''
            AFTER profile_code'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
