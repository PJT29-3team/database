-- 추천 조회는 희망지역과 예산으로 후보를 좁힌다.
-- 인덱스가 없으면 complex_scores 를 전체 스캔한 뒤에야 지역이 걸러져,
-- 단지가 늘수록 지역을 좁혀도 응답이 빨라지지 않는다.
CREATE INDEX idx_apartment_complexes_region_price
    ON apartment_complexes (sido_name, sigungu_name, representative_price);
