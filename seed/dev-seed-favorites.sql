-- 호라이즌 시나리오 개발용 관심상품 시드
-- 전제: financial-products.sql 이 먼저 적용된 상태
-- survey_id = 1 (dev-seed-users.sql 의 테스트 계정 기준)
SET NAMES utf8mb4;

-- 단기 예적금: NH 올원 정기예금 (subscription_period=6)
INSERT INTO financial_product_favorites
    (survey_id, financial_product_account_id, is_selected, created_by)
SELECT 1, financial_product_account_id, 'Y', 'DEV-SEED'
  FROM financial_product_account
 WHERE product_type = 'NH-OLLWON-DEP-06'
 LIMIT 1;

-- 중기 만기매칭 ETF: KODEX 27-12 은행채 (duration_months=16)
INSERT INTO financial_product_favorites
    (survey_id, financial_product_stock_id, is_selected, created_by)
SELECT 1, financial_product_stock_id, 'Y', 'DEV-SEED'
  FROM financial_product_stock
 WHERE product_type = 'KODEX-2712-BANK'
 LIMIT 1;

-- 장기 목표만기 펀드: 미래에셋 목표만기2030 채권형 (duration_months=49)
INSERT INTO financial_product_favorites
    (survey_id, financial_product_stock_id, is_selected, created_by)
SELECT 1, financial_product_stock_id, 'Y', 'DEV-SEED'
  FROM financial_product_stock
 WHERE product_type = 'FUND-TM-BOND-2030'
 LIMIT 1;
