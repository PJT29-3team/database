-- financial_product_preference 에 park_amount 를 더한다.
--
-- horizon 화면에서 파킹통장·CMA 배분 금액을 사용자가 직접 조정할 수 있게 하면서,
-- 그 값을 저장할 자리가 필요해졌다. financial_product_favorites.allocation_amount 와
-- 같은 성격(저장 후 PATCH로 갱신되는 배분 금액)이라 같은 방식으로 컬럼 하나만 더한다.
--
-- NULL이면 "사용자가 조정한 적 없음" = 자동배분을 그대로 쓴다는 뜻이다.
--
-- 여러 번 실행해도 안전하다.

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'financial_product_preference'
        AND column_name = 'park_amount') > 0,
    'SELECT ''financial_product_preference.park_amount 가 이미 있습니다'' AS skipped',
    'ALTER TABLE financial_product_preference
        ADD COLUMN park_amount BIGINT UNSIGNED NULL
            COMMENT ''파킹통장·CMA 배분 금액(원). 사용자가 조정한 값. NULL이면 자동배분'' AFTER monthly_need'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
