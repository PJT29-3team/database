SET NAMES utf8mb4;

-- =====================================================================
-- [금융 추천] 예금 가입자격/대상(join_member) 컬럼 추가
--
-- 프론트(ProductDetailView.vue)는 이미 detail.joinMember를 렌더링하도록 되어 있었으나
-- 백엔드에 대응 컬럼이 없어 항상 "실명 개인" 폴백만 보였다. finlife API의 join_member
-- (가입대상) 값을 그대로 저장해 실제 가입자격을 보여준다.
-- =====================================================================

ALTER TABLE financial_product_account
    ADD COLUMN join_member VARCHAR(300) NULL COMMENT '가입대상/자격(finlife join_member)'
    AFTER safety_level;
