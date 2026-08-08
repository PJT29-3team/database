SET NAMES utf8mb4;

-- 기존 테스트 데이터 초기화
DELETE FROM financial_product_account;
DELETE FROM financial_product_stock;

-- =================================================================
-- 1. 예금 (financial_product_account) — VERY_LOW (매우낮은위험)
-- =================================================================
INSERT INTO financial_product_account (row_uuid, product_type, category_code, account_name, institution_name, safety_level, invest_period, interest_rate, max_interest_rate, subscription_period, recommend_reason, recommended_weight, del_yn, created_at, updated_at) VALUES 
('4845d78d-dfa7-45e7-b7c1-5eb336c29c79', 'DUMMY_ACC_25', 'DEPOSIT', 'KB 시니어 맞춤 정기예금 1호', 'KB국민은행', 'VERY_LOW', 'UNDER_12M', 3.55, 3.85, 6, '6개월 만기로 자금이 오래 묶이지 않아 단기 목적에 적합합니다.', 1.0, 'N', NOW(), NOW()),
('7e703b95-91c4-4153-af95-31befde1b252', 'DUMMY_ACC_26', 'DEPOSIT', 'NH 올원 시니어 정기예금', 'NH농협은행', 'VERY_LOW', 'UNDER_12M', 3.45, 3.75, 6, '가입이 간편하고 단기 자금 운용에 우수한 금리를 제공합니다.', 1.0, 'N', NOW(), NOW()),
('a479411b-b77a-4e75-bdf4-9effbf7dbd61', 'DUMMY_ACC_27', 'DEPOSIT', '신한 쏠편한 정기예금 (6개월)', '신한은행', 'VERY_LOW', 'UNDER_12M', 3.50, 3.80, 9, '단기 목돈 보관에 최적화된 안정적인 예금 상품입니다.', 1.0, 'N', NOW(), NOW()),

('bf5c4917-6713-4bdb-af3b-6dde2ada6945', 'DUMMY_ACC_28', 'DEPOSIT', '카카오뱅크 정기예금 (12개월)', '카카오뱅크', 'VERY_LOW', 'Y1_TO_2', 3.60, 3.90, 12, '1~2년 중기 목돈 마련을 위한 대표 원금보장 예금입니다.', 1.0, 'N', NOW(), NOW()),
('59b4bbca-4442-411a-9277-1250b38130b8', 'DUMMY_ACC_29', 'DEPOSIT', '하나은행 하나의 정기예금', '하나은행', 'VERY_LOW', 'Y1_TO_2', 3.50, 3.80, 18, '18개월 만기로 시니어 자산의 안정적 이자 수익을 도옵니다.', 1.0, 'N', NOW(), NOW()),
('f46d024a-e655-4e20-bc9d-e124a21c9a0c', 'DUMMY_ACC_30', 'DEPOSIT', '우리 WON 정기예금 (15개월)', '우리은행', 'VERY_LOW', 'Y1_TO_2', 3.55, 3.85, 15, '여유자금을 1년 이상 안정적으로 굴리기 좋은 상품입니다.', 1.0, 'N', NOW(), NOW()),

('b4abd774-9ea5-43d2-bc1f-dca1eaff5849', 'DUMMY_ACC_31', 'DEPOSIT', 'IBK 성공만기 정기예금 (24개월)', 'IBK기업은행', 'VERY_LOW', 'Y2_TO_3', 3.65, 3.95, 24, '2년 예치 시 국책은행의 높은 안정성을 바탕으로 합니다.', 1.0, 'N', NOW(), NOW()),
('4491160a-fef5-4a0e-8e41-161b3ebc2e19', 'DUMMY_ACC_32', 'DEPOSIT', 'KDB 드림 정기예금', '산업은행', 'VERY_LOW', 'Y2_TO_3', 3.70, 4.00, 30, '2년 이상 장기 목돈 보관에 우수한 만기 이율을 드립니다.', 1.0, 'N', NOW(), NOW()),
('129bb0f8-ab9d-4de6-935f-7ddc0629f731', 'DUMMY_ACC_33', 'DEPOSIT', 'SC제일 퍼스트 정기예금', 'SC제일은행', 'VERY_LOW', 'Y2_TO_3', 3.60, 3.90, 24, '2~3년 구간 안정적인 원금보장을 희망하는 분께 추천합니다.', 1.0, 'N', NOW(), NOW()),

('2362b8b1-ffba-4b92-b223-aee3421da798', 'DUMMY_ACC_34', 'DEPOSIT', 'KB 든든 시니어 장기예금 (36개월)', 'KB국민은행', 'VERY_LOW', 'OVER_36M', 3.75, 4.10, 36, '3년 이상 장기 여유자금을 가장 안전하게 운용할 수 있습니다.', 1.0, 'N', NOW(), NOW()),
('10f2b228-2dc8-4e1f-9aa9-1a50252292e2', 'DUMMY_ACC_35', 'DEPOSIT', 'NH 농협 장기복리 예금', 'NH농협은행', 'VERY_LOW', 'OVER_36M', 3.80, 4.15, 48, '장기 예치에 따른 높은 이자 수익과 원금 안정성을 동시에 제공합니다.', 1.0, 'N', NOW(), NOW()),
('1f4a1c9c-e626-43cf-9fef-a6f2d9b635ee', 'DUMMY_ACC_36', 'DEPOSIT', '신한 쏠편한 장기예금 (48개월)', '신한은행', 'VERY_LOW', 'OVER_36M', 3.70, 4.05, 48, '장기 은퇴 자금 보호 및 고정 금리 수익 확보에 유리합니다.', 1.0, 'N', NOW(), NOW());

-- =================================================================
-- 2. 채권/ETF (financial_product_stock) — LOW & MEDIUM (낮은위험 & 보통위험)
-- =================================================================
INSERT INTO financial_product_stock (row_uuid, product_type, category_code, stock_name, institution_name, safety_level, maturity_date, return_rate, recommend_reason, del_yn, created_at, updated_at) VALUES 
-- [1년 미만 - LOW]
('684962ec-4e47-40d9-b900-2937d5303e4f', 'DUMMY_STK_13', 'BOND_ETF', 'KODEX 26-12 금융채(AA-이상)액티브', '삼성자산운용', 'LOW', '2026-12-15', 3.85, '우량 금융채 중심 투자로 단기 이중 안정성을 제공합니다.', 'N', NOW(), NOW()),
('2803ee76-6bc2-43d4-9c9e-846062a3a045', 'DUMMY_STK_14', 'BOND_ETF', 'KBSTAR 26-09 은행채(AAA)액티브', 'KB자산운용', 'LOW', '2026-09-25', 3.75, '만기가 임박한 AAA 은행채로 원금 손실 위험이 극히 낮습니다.', 'N', NOW(), NOW()),
('abbb8bf8-8649-4605-b664-a7181ba6719b', 'DUMMY_STK_15', 'BOND_ETF', 'TIGER 26-10 회사채(A+이상)', '미래에셋자산운용', 'LOW', '2026-10-20', 3.95, '1년 미만 단기 회사채 중 가장 우량한 채권에 집중 투자합니다.', 'N', NOW(), NOW()),

-- [1년~2년 - LOW]
('17f88826-6230-4fb4-b34f-790839cc477b', 'DUMMY_STK_16', 'BOND_ETF', 'KODEX 27-12 은행채(AAA)액티브', '삼성자산운용', 'LOW', '2027-12-15', 4.10, '2027년 만기 AAA 은행채로 1~2년 안정적 채권 수익을 실현합니다.', 'N', NOW(), NOW()),
('454c129f-b515-4669-bfc6-e4af10e87669', 'DUMMY_STK_17', 'BOND_ETF', 'TIGER 27-12 회사채(AA-이상)', '미래에셋자산운용', 'LOW', '2027-12-15', 4.25, '우량 회사채 채권으로 예금 대비 경쟁력 있는 이자 이익을 냅니다.', 'N', NOW(), NOW()),
('aeb72fcf-9360-47c7-a3d5-e0d86db7b499', 'DUMMY_STK_18', 'BOND_FUND', 'ACE 27-09 국고채액티브', '한국투자신탁운용', 'LOW', '2027-09-30', 4.05, '국고채 기반의 높은 신용도로 2년 미만 목표 자금을 보관합니다.', 'N', NOW(), NOW()),

-- [2년~3년 - LOW]
('92393e6f-3fb6-4623-975c-0b9156a11566', 'DUMMY_STK_19', 'BOND_ETF', 'KODEX 28-12 회사채(AA-이상)', '삼성자산운용', 'LOW', '2028-12-15', 4.35, '2028년 만기 우량 회사채로 확정 수준의 이자 수익을 기대합니다.', 'N', NOW(), NOW()),
('85857005-ffa2-4c98-b944-7aa03e78e94c', 'DUMMY_STK_20', 'BOND_FUND', '미래에셋 목표만기2029 채권형', '미래에셋자산운용', 'LOW', '2029-06-30', 4.45, '국공채 중심의 목표만기형 펀드로 3년 미만 자금 유치에 완벽합니다.', 'N', NOW(), NOW()),
('574b0051-3ae1-44ac-a34c-9c733c8fcfdd', 'DUMMY_STK_21', 'BOND_ETF', 'KBSTAR 28-11 특수채(AAA)', 'KB자산운용', 'LOW', '2028-11-20', 4.30, '공공기관 및 특수채 중심 투자의 극강 안정성 상품입니다.', 'N', NOW(), NOW()),

-- [3년 이상 - LOW]
('e8e014d3-85a4-4b43-9ad4-f13a4452aa93', 'DUMMY_STK_22', 'BOND_ETF', 'KODEX 30-12 회사채(AA-이상)', '삼성자산운용', 'LOW', '2030-12-15', 4.60, '장기 우량 회사채 투자로 3년 이상 안정된 이자 수입을 도옵니다.', 'N', NOW(), NOW()),
('edb0599e-3333-40ce-8839-cd097026de33', 'DUMMY_STK_23', 'BOND_FUND', '미래에셋 목표만기2030 채권형', '미래에셋자산운용', 'LOW', '2030-09-30', 4.75, '2030년 목표 만기 장기 채권 운용으로 노후 자금 증식을 돕습니다.', 'N', NOW(), NOW()),
('9bc1aab9-4021-44ef-a33f-b8f77ff63cc2', 'DUMMY_STK_24', 'BOND_ETF', 'TIGER 31-10 국고채30년액티브', '미래에셋자산운용', 'LOW', '2031-10-15', 4.80, '대한민국 국고채 장기 투자로 안정적인 고금리를 누릴 수 있습니다.', 'N', NOW(), NOW()),

-- [1년 미만 - MEDIUM]
('076bf347-2ba6-4429-884c-a0eda2e96bab', 'DUMMY_STK_1', 'BOND_ETF', 'TIGER 26-11 회사채(A+이상)액티브', '미래에셋자산운용', 'MEDIUM', '2026-11-15', 4.30, 'A+ 등급 회사채 투자로 단기 예금 대비 높은 수익을 추구합니다.', 'N', NOW(), NOW()),
('6932c05c-cfb0-4a26-971e-714a4934fc8d', 'DUMMY_STK_2', 'BOND_FUND', '삼성 목표만기2026 채권혼합', '삼성자산운용', 'MEDIUM', '2026-12-20', 4.45, '단기 채권에 일부 혼합자산을 더해 수익성을 다변화했습니다.', 'N', NOW(), NOW()),
('1021133d-4573-41b8-94ff-cceadd91f5e3', 'DUMMY_STK_3', 'BOND_ETF', 'ACE 26-12 신종자본증권액티브', '한국투자신탁운용', 'MEDIUM', '2026-12-30', 4.60, '금융지주 신종자본증권 기반으로 높은 우대 이자를 지향합니다.', 'N', NOW(), NOW()),

-- [1년~2년 - MEDIUM]
('51d88329-009a-4145-8a51-aff7042e05bd', 'DUMMY_STK_4', 'BOND_ETF', 'TIGER 28-04 회사채(A+이상)', '미래에셋자산운용', 'MEDIUM', '2028-04-21', 4.70, '중기 회사채 보유로 안정성과 적정 수익률을 조화롭게 확보합니다.', 'N', NOW(), NOW()),
('ad9c264f-f43a-47b5-90f4-fab6ea6743d1', 'DUMMY_STK_5', 'BOND_FUND', '삼성 목표만기2028 채권혼합', '삼성자산운용', 'MEDIUM', '2028-06-30', 4.85, '목표만기 시점에 맞춰 중간 수준의 위험과 준수한 수익률을 냅니다.', 'N', NOW(), NOW()),
('5f607783-745d-4f39-955b-e2f572f871b2', 'DUMMY_STK_6', 'BOND_ETF', 'SOL 27-12 BBB+이상 회사채', '신한자산운용', 'MEDIUM', '2027-12-20', 4.90, '투자적격 등급 중 고금리 회사채를 선별하여 이자를 극대화합니다.', 'N', NOW(), NOW()),

-- [2년~3년 - MEDIUM]
('7d3de945-b983-4f58-b9b5-75f4b49d0cbc', 'DUMMY_STK_7', 'BOND_FUND', '삼성 미국달러우량채권 2029년 만기', '삼성자산운용', 'MEDIUM', '2029-05-31', 5.10, '달러 우량 채권 투자로 환차익 기회와 안정적 이자를 기대합니다.', 'N', NOW(), NOW()),
('7c9f6239-350b-450d-8aa8-79358c0e7559', 'DUMMY_STK_8', 'BOND_FUND', '삼성 목표만기2029 채권혼합', '삼성자산운용', 'MEDIUM', '2029-06-30', 5.20, '2~3년 장기 목표로 채권 기반 수익에 일부 프리미엄을 올립니다.', 'N', NOW(), NOW()),
('57563220-198a-4a45-8fd7-c13d6d5f0ee9', 'DUMMY_STK_9', 'BOND_ETF', 'KBSTAR 29-12 회사채(A+이상)', 'KB자산운용', 'MEDIUM', '2029-12-15', 5.05, '3년 가깝게 장기 예치 시 꾸준한 월분배 및 만기 이자를 실현합니다.', 'N', NOW(), NOW()),

-- [3년 이상 - MEDIUM]
('227f9bfc-61d5-47e6-9e17-10983e914128', 'DUMMY_STK_10', 'BOND_ETF', 'KODEX 31-12 회사채(A+이상)', '삼성자산운용', 'MEDIUM', '2031-12-15', 5.40, '3년 이상 장기 보유 시 시니어 은퇴 자금용 고수익을 드립니다.', 'N', NOW(), NOW()),
('f1bd05c5-69ac-4a0d-a33e-b41a926dd272', 'DUMMY_STK_11', 'BOND_FUND', '한화 목표만기2031 채권혼합', '한화자산운용', 'MEDIUM', '2031-09-30', 5.55, '장기 복리 효과를 노린 시니어 맞춤 목표만기 자산운용 펀드입니다.', 'N', NOW(), NOW()),
('c1d90d3d-c0ca-4e54-94f9-d9dd60fe24a6', 'DUMMY_STK_12', 'BOND_ETF', 'TIGER 32-06 미국30년국채혼합', '미래에셋자산운용', 'MEDIUM', '2032-06-15', 5.65, '장기 미국 국채 기반으로 인플레이션 대비 우수한 자산 증식을 지향합니다.', 'N', NOW(), NOW());
