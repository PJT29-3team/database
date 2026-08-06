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
