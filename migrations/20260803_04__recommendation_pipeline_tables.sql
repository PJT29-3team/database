CREATE TABLE IF NOT EXISTS poi_facilities (
    poi_facility_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    source_code VARCHAR(40) NOT NULL
        COMMENT '데이터 출처 (DATA_GO_KR/SEOUL/GYEONGGI/KFTC/MOCK)',
    external_facility_key VARCHAR(255) NOT NULL COMMENT '출처 고유키',
    facility_type_code VARCHAR(40) NOT NULL
        COMMENT 'POI_FACILITY_TYPE 코드 (HOSPITAL/PHARMACY/BUS_STOP/CCTV ...)',
    facility_name VARCHAR(255) NOT NULL,
    road_address VARCHAR(500) NULL,
    sido_name VARCHAR(40) NULL,
    sigungu_name VARCHAR(40) NULL,
    eupmyeondong_name VARCHAR(40) NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    geocoded_yn CHAR(1) NOT NULL DEFAULT 'N'
        COMMENT '카카오 로컬 API로 좌표를 보정했는지',
    raw_payload_json JSON NULL COMMENT '원본 응답 스냅샷',
    synced_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (poi_facility_id),
    UNIQUE KEY uq_poi_facilities_row_uuid (row_uuid),
    UNIQUE KEY uq_poi_facilities_source_key (source_code, external_facility_key),
    INDEX idx_poi_facilities_geo (facility_type_code, latitude, longitude),
    INDEX idx_poi_facilities_region (sigungu_name, facility_type_code),
    INDEX idx_poi_facilities_synced (synced_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '점수 산출용 주변 시설 위치';

CREATE TABLE IF NOT EXISTS apartment_trades (
    apartment_trade_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    external_trade_key VARCHAR(255) NOT NULL COMMENT '거래 고유키 (중복 적재 방지)',
    legal_dong_code VARCHAR(10) NOT NULL COMMENT '법정동 코드',
    sigungu_name VARCHAR(40) NOT NULL,
    eupmyeondong_name VARCHAR(40) NOT NULL,
    complex_name VARCHAR(255) NOT NULL COMMENT '단지명',
    exclusive_area DECIMAL(8, 2) NOT NULL COMMENT '전용면적 m2',
    floor_no INT NULL,
    build_year INT NULL,
    trade_ymd CHAR(8) NOT NULL COMMENT '거래일 yyyyMMdd',
    trade_amount BIGINT UNSIGNED NOT NULL COMMENT '거래금액 원',
    raw_payload_json JSON NULL,
    synced_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (apartment_trade_id),
    UNIQUE KEY uq_apartment_trades_row_uuid (row_uuid),
    UNIQUE KEY uq_apartment_trades_external (external_trade_key),
    INDEX idx_apartment_trades_complex (legal_dong_code, complex_name, exclusive_area),
    INDEX idx_apartment_trades_ymd (trade_ymd)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '국토부 아파트 실거래 내역';

-- 실거래 내역을 법정동 + 단지명으로 묶어 만드는 추천 대상 카탈로그.
CREATE TABLE IF NOT EXISTS apartment_complexes (
    apartment_complex_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    external_complex_key VARCHAR(255) NOT NULL
        COMMENT '법정동코드 + 단지명 해시. PropertyScore.externalPropertyKey 로 사용',
    complex_name VARCHAR(255) NOT NULL,
    legal_dong_code VARCHAR(10) NOT NULL,
    sido_name VARCHAR(40) NOT NULL,
    sigungu_name VARCHAR(40) NOT NULL,
    eupmyeondong_name VARCHAR(40) NOT NULL,
    road_address VARCHAR(500) NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    build_year INT NULL,
    has_elevator_yn CHAR(1) NOT NULL DEFAULT 'N' COMMENT '승강기 설치 현황 매칭 결과',
    slope_percent DECIMAL(5, 2) NULL COMMENT '진입로 경사도 %',
    representative_area DECIMAL(8, 2) NULL COMMENT '대표 전용면적 m2',
    representative_price BIGINT UNSIGNED NULL COMMENT '대표 평형 거래가 중앙값 원',
    trade_count_5y INT NOT NULL DEFAULT 0,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (apartment_complex_id),
    UNIQUE KEY uq_apartment_complexes_row_uuid (row_uuid),
    UNIQUE KEY uq_apartment_complexes_external (external_complex_key),
    INDEX idx_apartment_complexes_geo (latitude, longitude),
    INDEX idx_apartment_complexes_region (sigungu_name, eupmyeondong_name)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '실거래 내역에서 집계한 추천 대상 단지 카탈로그';

-- 점수 배치의 산출물. total_score는 저장하지 않는다 —
-- 사용자가 고른 유형에 따라 달라지므로 조회 시점에 RecommendationScorer가 계산한다.
CREATE TABLE IF NOT EXISTS complex_scores (
    complex_score_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    apartment_complex_id BIGINT UNSIGNED NOT NULL COMMENT '논리 참조',
    external_complex_key VARCHAR(255) NOT NULL,
    safety_score DECIMAL(5, 2) NOT NULL,
    convenience_score DECIMAL(5, 2) NOT NULL,
    asset_score DECIMAL(5, 2) NOT NULL,
    score_detail_json JSON NOT NULL
        COMMENT '지표별 세부 점수와 결측 지표 목록',
    scoring_policy_version VARCHAR(40) NOT NULL
        COMMENT '산출 규칙 버전. 규칙이 바뀌면 재계산 대상 판별에 사용',
    calculated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (complex_score_id),
    UNIQUE KEY uq_complex_scores_row_uuid (row_uuid),
    UNIQUE KEY uq_complex_scores_complex (apartment_complex_id),
    INDEX idx_complex_scores_calculated (calculated_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '단지별 주거안전·생활편의·자산안정 점수';

CREATE TABLE IF NOT EXISTS batch_job_runs (
    batch_job_run_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    job_name VARCHAR(100) NOT NULL COMMENT 'POI_SYNC / TRADE_SYNC / COMPLEX_CATALOG / SCORE_CALC',
    job_target VARCHAR(100) NULL COMMENT '세부 대상 (HOSPITAL, BUS_STOP 등)',
    status_code VARCHAR(20) NOT NULL COMMENT 'RUNNING / SUCCESS / FAILED',
    processed_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0,
    error_message TEXT NULL,
    started_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    finished_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (batch_job_run_id),
    UNIQUE KEY uq_batch_job_runs_row_uuid (row_uuid),
    INDEX idx_batch_job_runs_job (job_name, started_at DESC)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '수집·점수 배치 실행 이력';

-- POI_FACILITY_TYPE 코드 그룹. 멱등하게 넣는다.
INSERT INTO common_codes (code_group, code, code_name, description, display_order, is_active)
SELECT * FROM (
    SELECT 'POI_FACILITY_TYPE' AS g, 'CLINIC' AS c, '동네의원' AS n, '아플때 지표 - 의원 최단거리' AS d, 10 AS o, TRUE AS a UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'HOSPITAL', '종합병원', '아플때 지표 - 종합병원 최단거리', 20, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'PHARMACY', '약국', '아플때 지표 - 약국 최단거리', 30, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'ELEVATOR', '승강기', '넘어질위험 지표 - 승강기 설치 현황', 40, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'DISASTER_ZONE', '재해위험지역', '산사태·침수 지표 - 위험구역 포함 여부', 50, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'LANDSLIDE_ZONE', '산사태위험지역', '산사태·침수 지표 - 위험구역 포함 여부', 60, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'EARTHQUAKE_SHELTER', '지진옥외대피장소', '산사태·침수 지표 - 대피소 최단거리', 70, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'CCTV', '방범용 CCTV', '치안 지표 - 반경 500m 개수', 80, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'POLICE', '경찰서·지구대', '치안 지표 - 최단거리', 90, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'FIRE_STATION', '소방서', '치안 지표 - 최단거리', 100, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'TRADITIONAL_MARKET', '전통시장', '장보기·산책 지표 - 최단거리', 110, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'MART', '대형마트', '장보기·산책 지표 - 최단거리', 120, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'PARK', '공원', '장보기·산책 지표 - 최단거리 (수도권만 커버)', 130, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'BUS_STOP', '버스정류장', '대중교통 지표 - 최단거리', 140, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'SUBWAY_STATION', '지하철역', '대중교통 지표 - 최단거리', 150, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'COMMUNITY_CENTER', '행정복지센터', '동네시설 지표 - 최단거리', 160, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'BANK', '은행', '동네시설 지표 - 최단거리', 170, TRUE UNION ALL
    SELECT 'POI_FACILITY_TYPE', 'NURSING_HOME', '요양시설', '동네시설 지표 - 최단거리', 180, TRUE
) AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM common_codes c
     WHERE c.code_group = seed.g AND c.code = seed.c
);

-- 배치 상태 코드
INSERT INTO common_codes (code_group, code, code_name, description, display_order, is_active)
SELECT * FROM (
    SELECT 'BATCH_JOB_STATUS' AS g, 'RUNNING' AS c, '실행 중' AS n, '배치가 진행 중' AS d, 10 AS o, TRUE AS a UNION ALL
    SELECT 'BATCH_JOB_STATUS', 'SUCCESS', '성공', '배치가 정상 종료', 20, TRUE UNION ALL
    SELECT 'BATCH_JOB_STATUS', 'FAILED', '실패', '배치가 오류로 종료', 30, TRUE
) AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM common_codes c
     WHERE c.code_group = seed.g AND c.code = seed.c
);
