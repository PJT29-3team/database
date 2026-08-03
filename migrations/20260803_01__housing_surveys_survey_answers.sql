ALTER TABLE housing_surveys
    ADD COLUMN acquisition_price_amount BIGINT UNSIGNED NULL
        COMMENT '설문 입력 과거 취득가액' AFTER max_purchase_budget_amount,
    ADD COLUMN transfer_price_amount BIGINT UNSIGNED NULL
        COMMENT '설문 입력 예상 양도가액' AFTER acquisition_price_amount,
    ADD COLUMN holding_years SMALLINT UNSIGNED NULL
        COMMENT '보유기간(년)' AFTER transfer_price_amount,
    ADD COLUMN residence_years SMALLINT UNSIGNED NULL
        COMMENT '거주기간(년)' AFTER holding_years,
    ADD COLUMN regulated_area BOOLEAN NULL
        COMMENT '조정대상지역 주택 여부' AFTER residence_years,
    ADD COLUMN capital_gains_tax_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated 추정 양도소득세' AFTER regulated_area,
    ADD COLUMN brokerage_fee_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated 중개수수료(부가세 포함)' AFTER capital_gains_tax_amount,
    ADD COLUMN net_proceeds_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated 매도 실수령액' AFTER brokerage_fee_amount;
