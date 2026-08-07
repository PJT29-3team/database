-- 추천 조건에 사용자 연결을 추가한다.
-- financial_product_preference는 지금까지 INSERT만 하고 조회할 수 없었다.
-- user_id가 없어 "이 사용자의 마지막 조건"을 고를 방법이 없었기 때문이다.
-- 그 결과 /summary를 새로고침하면 투자금액·즉시지출·매달쓸돈이 0으로 떨어졌다.
--
-- 이미 운영 중인 DB용 변경분이다. 새로 만드는 DB는 ddl.sql + house.sql이면 된다.
-- 여러 번 실행해도 안전하다.

SET NAMES utf8mb4;

-- 1. user_id 컬럼
SET @has_col = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'financial_product_preference'
      AND COLUMN_NAME = 'user_id'
);
SET @sql = IF(@has_col > 0,
    'SELECT ''skipped: financial_product_preference.user_id 가 이미 있습니다''',
    'ALTER TABLE financial_product_preference
        ADD COLUMN user_id BIGINT UNSIGNED NOT NULL
            COMMENT ''users(user_id). 마지막 입력 조건을 복원하기 위해 필요하다''
            AFTER row_uuid,
        ADD INDEX idx_financial_product_preference_user (user_id, financial_product_preference_id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. 기존 행은 주인을 알 수 없다. NOT NULL 기본값 0으로 들어가 있어
--    FK를 걸 수 없으므로 지운다. 추천 화면에 다시 들어가면 새로 쌓인다.
DELETE FROM financial_product_preference WHERE user_id = 0;

-- 3. 외래키
SET @has_fk = (
    SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'financial_product_preference'
      AND CONSTRAINT_NAME = 'fk_financial_product_preference_user'
);
SET @sql = IF(@has_fk > 0,
    'SELECT ''skipped: fk_financial_product_preference_user 가 이미 있습니다''',
    'ALTER TABLE financial_product_preference
        ADD CONSTRAINT fk_financial_product_preference_user
            FOREIGN KEY (user_id) REFERENCES users (user_id)
            ON DELETE RESTRICT ON UPDATE RESTRICT'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
