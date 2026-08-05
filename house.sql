-- Jiphyeonjeon final integrated schema
-- Target: MySQL 8.0+
-- Scope: member management, housing survey, recommended/favorite properties,
--        financial preferences/products, financial product cache
--        (catalog / rate options / price history / return summary),
--        and generated PDF report history.
--
-- Fresh-install DDL:
--   This file drops and recreates the complete application schema.
-- Security:
--   Raw authentication tokens must never be stored. Only SHA-256 hashes are stored.
-- Calculation policy:
--   Remaining funds and estimated selling costs are calculated by the backend.
--   The database stores calculation inputs and immutable output snapshots only.
-- Static content:
--   Notices, FAQ, policies, and customer-center phone information are not DB tables.
SET NAMES utf8mb4;
SET sql_safe_updates = 0;
DROP TABLE IF EXISTS common_codes;
DROP TABLE IF EXISTS financial_product_favorites;
DROP TABLE IF EXISTS financial_product_history;
DROP TABLE IF EXISTS financial_product_price_histories;
DROP TABLE IF EXISTS financial_product_stock;
DROP TABLE IF EXISTS financial_product_account;

DROP TABLE IF EXISTS generated_reports;
DROP TABLE IF EXISTS house_favorites_history;
DROP TABLE IF EXISTS house_favorites;
DROP TABLE IF EXISTS score_details;
DROP TABLE IF EXISTS house_score;
DROP TABLE IF EXISTS house_persona_score;
DROP TABLE IF EXISTS house;
DROP TABLE IF EXISTS house;
DROP TABLE IF EXISTS survey_desired_regions;
DROP TABLE IF EXISTS housing_surveys;
DROP TABLE IF EXISTS service_change_histories;
DROP TABLE IF EXISTS housing_preference_profiles;
DROP TABLE IF EXISTS account_deletion_requests;
DROP TABLE IF EXISTS social_account;
DROP TABLE IF EXISTS password_reset_tokens;
DROP TABLE IF EXISTS email_verifications;
DROP TABLE IF EXISTS auth_sessions;
DROP TABLE IF EXISTS social_accounts;
DROP TABLE IF EXISTS account_action_tokens;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS password_histories;
DROP TABLE IF EXISTS users;

-- Shared application codes. Business tables deliberately have no physical
-- foreign keys to this table; the backend validates active codes.
CREATE TABLE common_codes (
    common_code_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    code_group VARCHAR(60) NOT NULL COMMENT '대분류 코드',
    code_group_name VARCHAR(100) NOT NULL DEFAULT '' COMMENT '대분류명',
    middle_code VARCHAR(60) NOT NULL DEFAULT '' COMMENT '중분류 코드; 없으면 빈 문자열',
    middle_code_name VARCHAR(100) NULL COMMENT '중분류명',
    code VARCHAR(60) NOT NULL COMMENT '소분류 코드',
    code_name VARCHAR(100) NOT NULL COMMENT '소분류명 또는 화면 표시문구',
    description VARCHAR(500) NULL,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    effective_start_ymd VARCHAR(8) NOT NULL DEFAULT '19000101'
        COMMENT '적용 시작일자 yyyyMMdd',
    effective_end_ymd VARCHAR(8) NULL COMMENT '적용 종료일자 yyyyMMdd; NULL은 종료일 없음',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (common_code_id),
    UNIQUE KEY uq_common_codes_row_uuid (row_uuid),
    UNIQUE KEY uq_common_codes_effective (
        code_group,
        middle_code,
        code,
        effective_start_ymd
    ),
    INDEX idx_common_codes_group_active (
        code_group,
        middle_code,
        is_active,
        effective_start_ymd,
        effective_end_ymd,
        display_order
    )
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '상태·유형·단계 표시값을 관리하는 공통 코드';

-- 1. User master: email/social login identity and account lifecycle.
CREATE TABLE users (
    user_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'numeric user identifier',
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()) COMMENT '외부 노출용 UUID',
    email VARCHAR(320) NOT NULL COMMENT 'Login email; anonymized on completed withdrawal',
    password_hash VARCHAR(255) NULL COMMENT 'Password hash; NULL for social-only accounts',
    name VARCHAR(100) NULL COMMENT 'User display name',
    birth_year SMALLINT UNSIGNED NULL COMMENT 'Birth year collected during signup/profile completion',
    phone_number VARCHAR(20) NULL COMMENT 'Email signup phone number',
    email_verified_at DATETIME(6) NULL COMMENT 'One-time signup email verification timestamp',
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING_VERIFICATION'
        COMMENT 'Account lifecycle status',
    deleted_at DATETIME(6) NULL COMMENT '탈퇴 완료 및 개인정보 익명화 시각',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_row_uuid (row_uuid),
    UNIQUE KEY uq_users_email (email),
    INDEX idx_users_status_created (status, created_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '회원 기본정보와 계정 상태';

-- 2. JWT authentication sessions. refresh_token_hash is SHA-256 hexadecimal text.
CREATE TABLE auth_sessions (
    auth_session_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    refresh_token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    device_name VARCHAR(255) NULL COMMENT 'Session/device label shown to the user',
    expires_at DATETIME(6) NOT NULL,
    revoked_at DATETIME(6) NULL COMMENT 'Rotation or logout revocation timestamp',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (auth_session_id),
    UNIQUE KEY uq_auth_sessions_row_uuid (row_uuid),
    UNIQUE KEY uq_auth_sessions_refresh_token_hash (refresh_token_hash),
    INDEX idx_auth_sessions_user_active (user_id, revoked_at, expires_at),
    INDEX idx_auth_sessions_cleanup (expires_at, revoked_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'JWT 인증 세션과 Refresh Token 해시';

-- 3. One-time signup and email-change verification tokens.
CREATE TABLE email_verifications (
    email_verification_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    verification_email VARCHAR(320) NOT NULL,
    verification_type VARCHAR(20) NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    used_at DATETIME(6) NULL,
    revoked_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (email_verification_id),
    UNIQUE KEY uq_email_verifications_row_uuid (row_uuid),
    UNIQUE KEY uq_email_verifications_token_hash (token_hash),
    INDEX idx_email_verifications_active (
        user_id,
        verification_type,
        used_at,
        revoked_at,
        expires_at
    ),
    INDEX idx_email_verifications_cleanup (expires_at, used_at, revoked_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '회원가입·이메일 변경 인증 토큰';

-- 4. One-time password reset tokens.
CREATE TABLE password_reset_tokens (
    password_reset_token_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    used_at DATETIME(6) NULL,
    revoked_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (password_reset_token_id),
    UNIQUE KEY uq_password_reset_tokens_row_uuid (row_uuid),
    UNIQUE KEY uq_password_reset_tokens_token_hash (token_hash),
    INDEX idx_password_reset_tokens_active (user_id, used_at, revoked_at, expires_at),
    INDEX idx_password_reset_tokens_cleanup (expires_at, used_at, revoked_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '비밀번호 재설정 일회성 토큰';

-- 5. Social provider identity linked to one user.
CREATE TABLE social_account (
    social_account_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    provider VARCHAR(20) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    provider_email VARCHAR(320) NULL,
    linked_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (social_account_id),
    UNIQUE KEY uq_social_account_row_uuid (row_uuid),
    UNIQUE KEY uq_social_account_provider_user (provider, provider_user_id),
    UNIQUE KEY uq_social_account_user_provider (user_id, provider)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '카카오·네이버 소셜 계정 연결정보';

-- 7. Static survey cards and top-level safety/convenience/asset weights.
CREATE TABLE housing_preference_profiles (
    profile_code VARCHAR(40) NOT NULL,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    title VARCHAR(100) NOT NULL,
    card_description VARCHAR(500) NOT NULL,
    popup_description TEXT NOT NULL,
    popup_footer VARCHAR(500) NULL,
    safety_weight DECIMAL(5, 2) NOT NULL,
    convenience_weight DECIMAL(5, 2) NOT NULL,
    asset_weight DECIMAL(5, 2) NOT NULL,
    display_order SMALLINT UNSIGNED NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (profile_code),
    UNIQUE KEY uq_housing_preference_profiles_row_uuid (row_uuid),
    INDEX idx_preference_profiles_active (is_active, display_order)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '설문 성향 카드와 안전·편의·자산 가중치';

-- 9. Append-only audit history shared by the main service domains.
-- Grant the application account SELECT and INSERT only on this table.
CREATE TABLE service_change_histories (
    change_history_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL
        COMMENT '논리 참조: 탈퇴 후에도 문의 추적용 숫자 식별값만 유지',
    entity_type_code VARCHAR(40) NOT NULL
        COMMENT 'HISTORY_ENTITY_TYPE 코드',
    entity_id BIGINT UNSIGNED NOT NULL
        COMMENT '변경 대상 테이블의 숫자 PK 논리 참조',
    entity_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL
        COMMENT '변경 대상 행의 외부 UUID',
    event_type_code VARCHAR(40) NOT NULL
        COMMENT 'HISTORY_EVENT_TYPE 코드',
    before_snapshot_json JSON NULL
        COMMENT '비밀번호·토큰·이메일·이름·상세주소를 제외한 변경 전 값',
    after_snapshot_json JSON NULL
        COMMENT '비밀번호·토큰·이메일·이름·상세주소를 제외한 변경 후 값',
    change_reason_code VARCHAR(40) NULL
        COMMENT '선택적 변경 사유 공통 코드',
    request_id VARCHAR(100) NULL COMMENT 'API 요청 및 로그 추적 식별자',
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (change_history_id),
    UNIQUE KEY uq_service_change_histories_row_uuid (row_uuid),
    INDEX idx_change_history_entity (
        entity_type_code,
        entity_id,
        occurred_at DESC
    ),
    INDEX idx_change_history_entity_uuid (
        entity_type_code,
        entity_uuid,
        occurred_at DESC
    ),
    INDEX idx_change_history_user (user_id, occurred_at DESC),
    INDEX idx_change_history_request (request_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '주요 서비스 변경 사건을 보관하는 추가 전용 비식별 감사 이력';

-- 11. Survey execution. Multiple completed surveys are retained; one can be active.
CREATE TABLE housing_surveys (
    survey_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    profile_code VARCHAR(40) NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    current_step_code VARCHAR(40) NOT NULL DEFAULT 'INTRO'
        COMMENT 'SURVEY_STEP 공통 코드',
    has_mortgage BOOLEAN NULL,
    mortgage_balance_amount BIGINT UNSIGNED NULL,
    reserve_option_code VARCHAR(30) NULL,
    reserve_custom_amount BIGINT UNSIGNED NULL,
    reserve_amount_used BIGINT UNSIGNED NULL,
    max_purchase_budget_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated maximum purchase budget',
    acquisition_price_amount BIGINT UNSIGNED NULL
        COMMENT '설문 입력 과거 취득가액',
    transfer_price_amount BIGINT UNSIGNED NULL
        COMMENT '설문 입력 예상 양도가액',
    holding_years SMALLINT UNSIGNED NULL
        COMMENT '보유기간(년)',
    residence_years SMALLINT UNSIGNED NULL
        COMMENT '거주기간(년)',
    regulated_area BOOLEAN NULL
        COMMENT '조정대상지역 주택 여부',
    capital_gains_tax_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated 추정 양도소득세',
    brokerage_fee_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated 중개수수료(부가세 포함)',
    net_proceeds_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated 매도 실수령액',
    started_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    completed_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    active_user_id BIGINT UNSIGNED GENERATED ALWAYS AS (
        CASE WHEN status = 'IN_PROGRESS' THEN user_id ELSE NULL END
    ) STORED,
    PRIMARY KEY (survey_id),
    UNIQUE KEY uq_housing_surveys_row_uuid (row_uuid),
    UNIQUE KEY uq_active_housing_survey (active_user_id),
    INDEX idx_housing_surveys_user_completed (user_id, completed_at DESC)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '로그인 후 주택 설문 실행과 완료 조건';

-- 12. Multiple desired regions selected without ordering.
CREATE TABLE survey_desired_regions (
    desired_region_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    survey_id BIGINT UNSIGNED NOT NULL,
    region_code VARCHAR(20) NOT NULL,
    sido_code VARCHAR(20) NOT NULL,
    sido_name VARCHAR(100) NOT NULL,
    sigungu_code VARCHAR(20) NULL,
    sigungu_name VARCHAR(100) NULL,
    eupmyeondong_code VARCHAR(20) NULL,
    eupmyeondong_name VARCHAR(100) NULL,
    selected_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (desired_region_id),
    UNIQUE KEY uq_survey_desired_regions_row_uuid (row_uuid),
    UNIQUE KEY uq_survey_region (survey_id, region_code),
    INDEX idx_survey_regions_code (region_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '설문별 순서 없는 복수 희망지역';

-- 13. Recommended properties and user-selected favorite properties.
CREATE TABLE house (
    house_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '매물 인덱스',
    house_name VARCHAR(100) NOT NULL COMMENT '집 이름',
    house_price DECIMAL(19, 0) NOT NULL COMMENT '가격',
    house_size DECIMAL(5, 2) NOT NULL COMMENT '집 평수',
    build_year SMALLINT UNSIGNED NULL COMMENT '준공년도',
    build_month TINYINT UNSIGNED NULL COMMENT '준공월',
    floors TINYINT UNSIGNED NULL COMMENT '층수',
    building_count TINYINT UNSIGNED NULL COMMENT '동수',
    household_count SMALLINT UNSIGNED NULL COMMENT '세대수',
    house_location VARCHAR(255) NOT NULL COMMENT '집 주소',
    latitude DECIMAL(10, 7) NOT NULL COMMENT '위도',
    longitude DECIMAL(10, 7) NOT NULL COMMENT '경도',
    PRIMARY KEY (house_id),
    INDEX idx_house_location (house_location),
    INDEX idx_house_price (house_price),
    INDEX idx_house_coordinates (latitude, longitude),
    CONSTRAINT chk_house_price_nonnegative CHECK (house_price >= 0),
    CONSTRAINT chk_house_size_positive CHECK (house_size > 0),
    CONSTRAINT chk_house_build_month CHECK (build_month BETWEEN 1 AND 12),
    CONSTRAINT chk_house_latitude CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_house_longitude CHECK (longitude BETWEEN -180 AND 180)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '추천 대상 매물 기본정보';

CREATE TABLE house_score (
    house_score_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '집별 점수 인덱스',
    house_id INT UNSIGNED NOT NULL COMMENT '집별 인덱스',
    safety_walking_score TINYINT UNSIGNED NOT NULL COMMENT '보행안전 점수',
    safety_medical_score TINYINT UNSIGNED NOT NULL COMMENT '의료안전 점수',
    safety_security_score TINYINT UNSIGNED NOT NULL COMMENT '치안안전 점수',
    safety_disaster_score TINYINT UNSIGNED NOT NULL COMMENT '재난안전 점수',
    convenience_shopping_score TINYINT UNSIGNED NOT NULL COMMENT '장보기 점수',
    convenience_transit_score TINYINT UNSIGNED NOT NULL COMMENT '대중교통 점수',
    convenience_neighbor_score TINYINT UNSIGNED NOT NULL COMMENT '동네시설 점수',
    asset_price_level_score TINYINT UNSIGNED NOT NULL COMMENT '집값수준 점수',
    asset_liquidity_score TINYINT UNSIGNED NOT NULL COMMENT '거래 유동성 점수',
    PRIMARY KEY (house_score_id),
    UNIQUE KEY uq_house_score_house (house_id),
    CONSTRAINT fk_house_score_house
        FOREIGN KEY (house_id) REFERENCES house (house_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_house_score_safety_walking CHECK (safety_walking_score <= 100),
    CONSTRAINT chk_house_score_safety_medical CHECK (safety_medical_score <= 100),
    CONSTRAINT chk_house_score_safety_security CHECK (safety_security_score <= 100),
    CONSTRAINT chk_house_score_safety_disaster CHECK (safety_disaster_score <= 100),
    CONSTRAINT chk_house_score_convenience_shopping CHECK (convenience_shopping_score <= 100),
    CONSTRAINT chk_house_score_convenience_transit CHECK (convenience_transit_score <= 100),
    CONSTRAINT chk_house_score_convenience_neighbor CHECK (convenience_neighbor_score <= 100),
    CONSTRAINT chk_house_score_asset_price_level CHECK (asset_price_level_score <= 100),
    CONSTRAINT chk_house_score_asset_liquidity CHECK (asset_liquidity_score <= 100)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '매물별 평가 점수';

CREATE TABLE score_details (
    score_details_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '집 상세 인덱스',
    house_id INT UNSIGNED NOT NULL COMMENT '집별 인덱스',
    elevator CHAR(1) NOT NULL DEFAULT 'N' COMMENT '엘리베이터 여부(Y/N)',
    slope_degree DECIMAL(5, 2) NOT NULL DEFAULT 0 COMMENT '경사도',
    clinic_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 내 의원 수',
    hospital_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 내 종합병원 수',
    pharmacy_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 내 약국 수',
    police_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 내 경찰서/지구대 수',
    fire_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 내 소방서 수',
    cctv_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 내 CCTV 수',
    flood_history CHAR(1) NOT NULL DEFAULT 'N' COMMENT '구 단위 침수 이력(Y/N)',
    landslide_risk CHAR(1) NOT NULL DEFAULT 'N' COMMENT '구 단위 산사태위험지역(Y/N)',
    market_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 전통시장 수',
    hypermarket_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 대형마트 수',
    park_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 공원 수',
    bus_stop_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 버스정류장 수',
    subway_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 지하철역 수',
    community_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 행정복지센터 수',
    bank_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 은행 지점 수',
    nursing_home_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '반경 요양시설 수',
    price_level TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '매매값 수준(하위 %)',
    trade_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '하락장 거래건수',
    PRIMARY KEY (score_details_id),
    UNIQUE KEY uq_score_details_house (house_id),
    CONSTRAINT fk_score_details_house
        FOREIGN KEY (house_id) REFERENCES house (house_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_score_details_elevator CHECK (elevator IN ('Y', 'N')),
    CONSTRAINT chk_score_details_flood_history CHECK (flood_history IN ('Y', 'N')),
    CONSTRAINT chk_score_details_landslide_risk CHECK (landslide_risk IN ('Y', 'N')),
    CONSTRAINT chk_score_details_slope CHECK (slope_degree >= 0),
    CONSTRAINT chk_score_details_price_level CHECK (price_level <= 100)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '매물별 점수 산정 상세정보';

CREATE TABLE house_favorites (
    house_favorites_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '관심 매물 인덱스',
    survey_id BIGINT UNSIGNED NOT NULL COMMENT '설문 인덱스',
    house_id INT UNSIGNED NOT NULL COMMENT '매물 인덱스',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '등록시각',
    is_selected CHAR(1) NOT NULL DEFAULT 'Y' COMMENT '최종 선택여부',
    PRIMARY KEY (house_favorites_id),
    UNIQUE KEY uq_house_favorites_survey_house (survey_id, house_id),
    INDEX idx_house_favorites_house (house_id),
    INDEX idx_house_favorites_survey_created (survey_id, created_at DESC),
    CONSTRAINT fk_house_favorites_survey
        FOREIGN KEY (survey_id) REFERENCES housing_surveys (survey_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_house_favorites_house
        FOREIGN KEY (house_id) REFERENCES house (house_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_house_favorites_selected CHECK (is_selected IN ('Y', 'N'))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '설문별 관심 매물';

CREATE TABLE house_favorites_history (
    house_favorites_history_id INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT '관심 매물 히스토리 인덱스',
    house_favorites_id INT UNSIGNED NOT NULL COMMENT '관심 매물 인덱스',
    survey_id BIGINT UNSIGNED NOT NULL COMMENT '설문 인덱스',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '등록시각',
    is_selected CHAR(1) NOT NULL COMMENT '최종 선택여부',
    PRIMARY KEY (house_favorites_history_id),
    INDEX idx_house_favorites_history_favorite_created (
        house_favorites_id,
        created_at DESC
    ),
    INDEX idx_house_favorites_history_survey_created (
        survey_id,
        created_at DESC
    ),
    CONSTRAINT fk_house_favorites_history_favorite
        FOREIGN KEY (house_favorites_id)
        REFERENCES house_favorites (house_favorites_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_house_favorites_history_survey
        FOREIGN KEY (survey_id) REFERENCES housing_surveys (survey_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_house_favorites_history_selected
        CHECK (is_selected IN ('Y', 'N'))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '관심 매물 선택 변경 이력';
CREATE TABLE house_persona_score (
    house_persona_score_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    house_id INT UNSIGNED NOT NULL,
    profile_code VARCHAR(40) NOT NULL,

    safety_score TINYINT UNSIGNED NOT NULL,
    convenience_score TINYINT UNSIGNED NOT NULL,
    asset_score TINYINT UNSIGNED NOT NULL,
    total_score TINYINT UNSIGNED NOT NULL,

    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (house_persona_score_id),

    UNIQUE KEY uq_house_persona_score_house_profile (
        house_id,
        profile_code
    ),

    KEY idx_house_persona_score_profile_total (
        profile_code,
        total_score DESC,
        house_id
    ),

    CONSTRAINT fk_house_persona_score_house
        FOREIGN KEY (house_id)
        REFERENCES house (house_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_house_persona_score_profile
        FOREIGN KEY (profile_code)
        REFERENCES housing_preference_profiles (profile_code)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,

    CONSTRAINT chk_house_persona_score_safety
        CHECK (safety_score <= 100),

    CONSTRAINT chk_house_persona_score_convenience
        CHECK (convenience_score <= 100),

    CONSTRAINT chk_house_persona_score_asset
        CHECK (asset_score <= 100),

    CONSTRAINT chk_house_persona_score_total
        CHECK (total_score <= 100)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  COMMENT='매물·주거선호 프로필별 평가점수';



-- 15. 관심 등록 금융상품 + 투자금액 배분 (금액 배분 기능).
CREATE TABLE financial_product_favorites (
    financial_product_favorites_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    survey_id BIGINT UNSIGNED NOT NULL
        COMMENT '논리 참조: 설문(housing_surveys→향후 survey). survey 확정 후 물리 FK 추가',
    financial_product_stock_id BIGINT UNSIGNED NULL
        COMMENT 'ETF/채권/펀드 관심 시 채움 (account_id와 배타)',
    financial_product_account_id BIGINT UNSIGNED NULL
        COMMENT '예적금/CMA 관심 시 채움 (stock_id와 배타)',
    allocation_amount DECIMAL(18, 0) NULL COMMENT '배분 금액(원)',
    allocation_percent DECIMAL(5, 2) NULL COMMENT '배분 비율(%)',
    is_selected CHAR(1) NOT NULL DEFAULT 'N' COMMENT '최종 선택 여부',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (financial_product_favorites_id),
    UNIQUE KEY uq_financial_product_favorites_row_uuid (row_uuid),
    INDEX idx_fin_favorites_survey (survey_id),
    INDEX idx_fin_favorites_stock (financial_product_stock_id),
    INDEX idx_fin_favorites_account (financial_product_account_id),
    CONSTRAINT chk_fin_favorites_one_product
        CHECK ((financial_product_stock_id IS NULL) <> (financial_product_account_id IS NULL))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '관심 등록 금융상품 + 투자금액 배분';

-- 15-1. 관심 금융상품 변경/선택 이력 (append 보관).
CREATE TABLE financial_product_history (
    financial_product_history_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    survey_id BIGINT UNSIGNED NOT NULL COMMENT '논리 참조: 설문',
    financial_product_stock_id BIGINT UNSIGNED NULL COMMENT '논리 참조(이력이라 FK 미설정)',
    financial_product_account_id BIGINT UNSIGNED NULL COMMENT '논리 참조(이력이라 FK 미설정)',
    allocation_amount DECIMAL(18, 0) NULL COMMENT '배분 금액(원)',
    allocation_percent DECIMAL(5, 2) NULL COMMENT '배분 비율(%)',
    is_selected CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (financial_product_history_id),
    UNIQUE KEY uq_financial_product_history_row_uuid (row_uuid),
    INDEX idx_fin_history_survey (survey_id, created_at DESC)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '관심 금융상품 변경/선택 이력(append-only)';

-- 16. MyPage report history. PDF bytes live in private object/file storage.
CREATE TABLE generated_reports (
    report_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    report_stage VARCHAR(30) NOT NULL
        COMMENT 'Highest completed cumulative report stage',
    title VARCHAR(255) NOT NULL,
    template_version VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'GENERATING',
    report_data_snapshot JSON NOT NULL
        COMMENT 'Generation-time inputs and backend-calculated display values',
    file_storage_key VARCHAR(700) NULL
        COMMENT 'Private object-storage key; never a public URL',
    file_name VARCHAR(255) NULL,
    file_size_bytes BIGINT UNSIGNED NULL,
    checksum_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    error_code VARCHAR(100) NULL,
    requested_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    generated_at DATETIME(6) NULL,
    expires_at DATETIME(6) NOT NULL COMMENT 'Normally requested_at plus 30 days',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (report_id),
    UNIQUE KEY uq_generated_reports_row_uuid (row_uuid),
    INDEX idx_generated_reports_user_requested (user_id, requested_at DESC),
    INDEX idx_generated_reports_cleanup (status, expires_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '고정 양식 PDF의 단계별 생성 스냅샷과 30일 보관 메타데이터';

-- ===========================================================================
-- Financial product master (stock / account) + price history.
-- 상품 마스터는 주별 배치로 product_type(고유코드) 기준 UPSERT → PK 안정적이라
-- favorites/price_histories 물리 FK 안전. 가격 이력은 append-only 원장.
-- survey_id는 다른 팀 담당(설문) 테이블이라 현재 논리 참조(물리 FK 미설정).
-- ===========================================================================

-- 17. ETF/채권/펀드 상품 마스터.
CREATE TABLE financial_product_stock (
    financial_product_stock_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    product_type VARCHAR(40) NOT NULL COMMENT '종목코드(단축코드/ISIN) — 주별 UPSERT 고유키',
    category_code VARCHAR(40) NOT NULL
        COMMENT 'FINANCIAL_PRODUCT_CATEGORY 코드 (BOND/BOND_ETF/BOND_FUND 등)',
    stock_name VARCHAR(255) NOT NULL COMMENT '상품명',
    institution_name VARCHAR(255) NOT NULL COMMENT '운용사',
    safety_level VARCHAR(30) NOT NULL COMMENT 'FINANCIAL_PRODUCT_RISK_GRADE 코드',
    maturity_date DATE NULL
        COMMENT '만기일(존속기한). 값이 있으면 만기 상품 → 추천은 maturity_date IS NOT NULL만',
    underlying_index VARCHAR(100) NULL COMMENT '기초지수',
    return_rate DECIMAL(9, 4) NULL COMMENT '3년(연환산) 수익률(%) — 주별 재계산',
    max_drawdown DECIMAL(9, 4) NULL COMMENT '최대낙폭 MDD(%)',
    volatility DECIMAL(9, 4) NULL COMMENT '변동성(%)',
    loss_risk CHAR(1) NULL COMMENT '원금손실 가능 여부 Y/N',
    past_return_date VARCHAR(8) NULL COMMENT '수익률 계산 기준일 yyyyMMdd',
    past_return_rate DECIMAL(9, 4) NULL COMMENT '과거(기간) 수익률(%)',
    recommend_reason TEXT NULL COMMENT '추천 이유',
    recommended_weight DECIMAL(5, 2) NULL COMMENT '추천 비중(%)',
    synced_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '주별 최신화 시각',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (financial_product_stock_id),
    UNIQUE KEY uq_financial_product_stock_row_uuid (row_uuid),
    UNIQUE KEY uq_financial_product_stock_type (product_type),
    INDEX idx_financial_product_stock_filter (maturity_date, safety_level)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'ETF/채권/펀드 상품 마스터(주별 UPSERT)';

-- 18. 예적금/CMA 상품 마스터.
CREATE TABLE financial_product_account (
    financial_product_account_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    product_type VARCHAR(40) NOT NULL COMMENT '상품코드(finlife fin_prdt_cd) — 주별 UPSERT 고유키',
    category_code VARCHAR(40) NOT NULL
        COMMENT 'FINANCIAL_PRODUCT_CATEGORY 코드 (DEPOSIT/SAVINGS/CMA)',
    account_name VARCHAR(255) NOT NULL COMMENT '상품명',
    institution_name VARCHAR(255) NOT NULL COMMENT '금융회사명',
    safety_level VARCHAR(30) NOT NULL COMMENT 'FINANCIAL_PRODUCT_RISK_GRADE 코드',
    invest_period VARCHAR(20) NOT NULL
        COMMENT 'INVESTMENT_PERIOD 코드. subscription_period 기준: <12=SHORT, 12~35=MEDIUM, >=36=LONG',
    interest_rate DECIMAL(5, 2) NULL COMMENT '기본금리(%)',
    max_interest_rate DECIMAL(5, 2) NULL COMMENT '최고우대금리(%)',
    subscription_period SMALLINT UNSIGNED NOT NULL
        COMMENT '가입기간(개월) — 이 값으로 단/중/장 구분. 통장류(CMA)는 0(=단기)',
    recommend_reason TEXT NULL COMMENT '추천 이유',
    recommended_weight DECIMAL(5, 2) NULL COMMENT '추천 비중(%)',
    synced_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '주별 최신화 시각',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (financial_product_account_id),
    UNIQUE KEY uq_financial_product_account_row_uuid (row_uuid),
    UNIQUE KEY uq_financial_product_account_type (product_type),
    INDEX idx_financial_product_account_filter (invest_period, safety_level)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '예적금/CMA 상품 마스터(주별 UPSERT)';

-- 19. 주별 종가 이력(append-only) — 3년 수익률·분석/알고리즘용. stock 전용.
--     기간별 수익률 요약(구 return_summaries)은 stock 테이블 필드로 흡수, 필요시 이력에서 재계산.
CREATE TABLE financial_product_price_histories (
    price_history_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    financial_product_stock_id BIGINT UNSIGNED NOT NULL
        COMMENT 'financial_product_stock 참조',
    base_date_ymd VARCHAR(8) NOT NULL COMMENT '기준일자 yyyyMMdd',
    close_price DECIMAL(18, 4) NULL COMMENT '종가',
    yield_rate DECIMAL(9, 4) NULL COMMENT '채권 유통수익률(%)',
    nav DECIMAL(18, 4) NULL COMMENT 'ETF 순자산가치(NAV)',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (price_history_id),
    UNIQUE KEY uq_price_histories_stock_date (financial_product_stock_id, base_date_ymd),
    INDEX idx_price_histories_series (financial_product_stock_id, base_date_ymd DESC)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '주별 종가 이력(append-only, 3년수익률·분석·알고리즘용)';

-- Physical integrity constraints for single-table logical references.
-- Deletes are explicit because this schema uses logical deletion and audit history.
ALTER TABLE auth_sessions
    ADD CONSTRAINT fk_auth_sessions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE email_verifications
    ADD CONSTRAINT fk_email_verifications_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE password_reset_tokens
    ADD CONSTRAINT fk_password_reset_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE social_account
    ADD CONSTRAINT fk_social_account_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE service_change_histories
    ADD CONSTRAINT fk_service_change_histories_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE housing_surveys
    ADD CONSTRAINT fk_housing_surveys_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_housing_surveys_profile
        FOREIGN KEY (profile_code) REFERENCES housing_preference_profiles (profile_code)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE survey_desired_regions
    ADD CONSTRAINT fk_survey_desired_regions_survey
        FOREIGN KEY (survey_id) REFERENCES housing_surveys (survey_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

-- 금융상품: favorites → stock/account, price_histories → stock (내부 물리 FK).
-- survey_id는 설문 테이블(다른 팀 담당) 확정 후 물리 FK 추가 예정(현재 논리 참조).
ALTER TABLE financial_product_favorites
    ADD CONSTRAINT fk_fin_favorites_stock
        FOREIGN KEY (financial_product_stock_id)
        REFERENCES financial_product_stock (financial_product_stock_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_fin_favorites_account
        FOREIGN KEY (financial_product_account_id)
        REFERENCES financial_product_account (financial_product_account_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE financial_product_price_histories
    ADD CONSTRAINT fk_fin_price_histories_stock
        FOREIGN KEY (financial_product_stock_id)
        REFERENCES financial_product_stock (financial_product_stock_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE generated_reports
    ADD CONSTRAINT fk_generated_reports_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Idempotent application-code seed data.
INSERT INTO common_codes (
    code_group,
    code,
    code_name,
    description,
    display_order,
    is_active
) VALUES
    ('USER_STATUS', 'PENDING_VERIFICATION', '이메일 인증 대기', '회원가입 후 최초 이메일 인증 전 상태', 10, TRUE),
    ('USER_STATUS', 'PENDING_PROFILE', '추가정보 입력 대기', '소셜 로그인 후 필수 프로필 입력 전 상태', 20, TRUE),
    ('USER_STATUS', 'ACTIVE', '정상', '정상적으로 서비스를 이용할 수 있는 계정', 30, TRUE),
    ('USER_STATUS', 'DELETED', '탈퇴 완료', '개인정보 익명화가 완료된 계정', 50, TRUE),
    ('USER_STATUS', 'SUSPENDED', '이용 정지', '운영 정책에 따라 이용이 정지된 계정', 60, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'SIGNUP', '회원가입 인증', '회원가입 이메일 인증 토큰', 10, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'SIGNUP_COMPLETION', '회원가입 완료', '이메일 인증 후 회원가입 완료용 일회성 토큰', 15, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'EMAIL_CHANGE', '이메일 변경', '이메일 주소 변경 인증 토큰', 20, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'PASSWORD_RESET', '비밀번호 재설정', '비밀번호 재설정 토큰', 30, TRUE),
    ('SOCIAL_PROVIDER', 'KAKAO', '카카오', '카카오 소셜 로그인', 10, TRUE),
    ('SOCIAL_PROVIDER', 'NAVER', '네이버', '네이버 소셜 로그인', 20, TRUE),
    ('SURVEY_STATUS', 'IN_PROGRESS', '진행 중', '설문 응답을 입력 중인 상태', 10, TRUE),
    ('SURVEY_STATUS', 'COMPLETED', '완료', '설문과 예산 계산이 완료된 상태', 20, TRUE),
    ('SURVEY_STATUS', 'ABANDONED', '중단', '사용자가 처음부터 다시 시작해 폐기된 설문', 30, TRUE),
    ('SURVEY_STEP', 'INTRO', '설문 시작', '설문 안내 및 시작 전 단계', 0, TRUE),
    ('SURVEY_STEP', 'PREFERENCE_PROFILE', '주거 선호 선택', '안전·생활·자산 선호 유형 선택 단계', 20, TRUE),
    ('SURVEY_STEP', 'MORTGAGE', '담보대출 확인', '보유 담보대출 여부와 잔액 입력 단계', 30, TRUE),
    ('SURVEY_STEP', 'RESERVE_BUDGET', '유보금 설정', '이사 후 남겨둘 최소 금액 설정과 구매 예산 확인 단계', 40, TRUE),
    ('SURVEY_STEP', 'DESIRED_REGION', '희망 지역 선택', '새 집을 찾을 희망 지역 복수 선택 단계', 50, TRUE),
    ('RESERVE_OPTION', 'AT_MOST_100M', '1억 이하', '이사 후 유보금 계산값 1억원', 10, TRUE),
    ('RESERVE_OPTION', 'FROM_100M_TO_200M', '1억~2억', '이사 후 유보금 계산값 2억원', 20, TRUE),
    ('RESERVE_OPTION', 'FROM_200M_TO_300M', '2억~3억', '이사 후 유보금 계산값 3억원', 30, TRUE),
    ('RESERVE_OPTION', 'AT_LEAST_300M', '3억 이상', '최소 유보금 3억원 기준', 40, TRUE),
    ('RESERVE_OPTION', 'CUSTOM', '직접 입력', '사용자가 유보금을 직접 입력', 50, TRUE),
    ('PROPERTY_AVAILABILITY', 'AVAILABLE', '거래 가능', '외부 매물 정보가 현재 유효함', 10, TRUE),
    ('PROPERTY_AVAILABILITY', 'UNAVAILABLE', '거래 불가', '외부 매물이 삭제되었거나 거래할 수 없음', 20, TRUE),
    ('SUITABILITY_GRADE', 'SUITABLE', '적정', '추천 조건에 적합한 상태', 10, TRUE),
    ('SUITABILITY_GRADE', 'NORMAL', '보통', '추천 조건에 보통 수준으로 적합한 상태', 20, TRUE),
    ('SUITABILITY_GRADE', 'CAUTION', '주의', '조건을 상세히 확인해야 하는 상태', 30, TRUE),
    ('HISTORY_ENTITY_TYPE', 'USER_ACCOUNT', '회원 계정', '회원 상태와 프로필 변경 대상', 10, TRUE),
    ('HISTORY_ENTITY_TYPE', 'HOUSING_SURVEY', '주택 설문', '설문 진행·완료·재설정 대상', 30, TRUE),
    ('HISTORY_ENTITY_TYPE', 'FAVORITE_PROPERTY', '관심매물', '관심매물 등록·해제·재평가 대상', 40, TRUE),
    ('HISTORY_ENTITY_TYPE', 'FINANCIAL_PROFILE', '금융 투자조건', '투자 비율·위험도·기간 설정 대상', 50, TRUE),
    ('HISTORY_ENTITY_TYPE', 'FAVORITE_FINANCIAL_PRODUCT', '관심 금융상품', '관심 금융상품 등록·해제 대상', 60, TRUE),
    ('HISTORY_EVENT_TYPE', 'CREATED', '등록', '업무 데이터 최초 등록', 10, TRUE),
    ('HISTORY_EVENT_TYPE', 'UPDATED', '수정', '업무 데이터 값 변경', 20, TRUE),
    ('HISTORY_EVENT_TYPE', 'STATUS_CHANGED', '상태 변경', '계정 또는 업무 상태 변경', 30, TRUE),
    ('HISTORY_EVENT_TYPE', 'COMPLETED', '완료', '업무 절차 완료', 40, TRUE),
    ('HISTORY_EVENT_TYPE', 'RESET', '재설정', '설문 또는 조건 재설정', 50, TRUE),
    ('HISTORY_EVENT_TYPE', 'FAVORITED', '관심 등록', '관심 대상 등록', 60, TRUE),
    ('HISTORY_EVENT_TYPE', 'UNFAVORITED', '관심 해제', '관심 대상 논리 해제', 70, TRUE),
    ('HISTORY_EVENT_TYPE', 'LOGICALLY_DELETED', '논리 삭제', '일반 조회에서 제외하도록 논리 삭제', 80, TRUE),
    ('HISTORY_EVENT_TYPE', 'RESTORED', '복구', '논리 삭제 데이터 복구', 90, TRUE),
    ('HISTORY_EVENT_TYPE', 'ANONYMIZED', '익명화', '회원 탈퇴 완료 후 개인정보 익명화', 100, TRUE),
    ('RISK_TOLERANCE', 'VERY_LOW', '매우 낮은 위험', '원금 보전 가능성을 가장 중요하게 보는 성향', 10, TRUE),
    ('RISK_TOLERANCE', 'LOW', '낮은 위험', '낮은 변동성과 안정성을 선호하는 성향', 20, TRUE),
    ('RISK_TOLERANCE', 'MEDIUM', '보통 위험', '어느 정도의 가격 변동을 감수하는 보통 위험 성향', 30, TRUE),
    ('INVESTMENT_PERIOD', 'SHORT', '단기', '1년 이내 투자 기간', 10, TRUE),
    ('INVESTMENT_PERIOD', 'MEDIUM', '중기', '1년 초과 3년 이내 투자 기간', 20, TRUE),
    ('INVESTMENT_PERIOD', 'LONG', '장기', '3년 초과 투자 기간', 30, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'DEPOSIT', '예금', '정기예금 등 예금 상품', 10, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'SAVINGS', '적금', '정기적금 등 적립식 상품', 20, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'CMA', 'CMA', '종합자산관리계좌 상품', 30, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'BOND', '채권', '국채·회사채 등 개별 채권 상품(채권시세정보 API)', 45, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'BOND_FUND', '채권형 펀드', '채권 중심 집합투자 상품', 40, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'BOND_ETF', '채권 ETF', '거래소에서 거래되는 채권형 상품', 50, TRUE),
    ('FINANCIAL_PRODUCT_RISK_GRADE', 'VERY_LOW', '매우 낮은 위험', '금융상품 위험등급', 10, TRUE),
    ('FINANCIAL_PRODUCT_RISK_GRADE', 'LOW', '낮은 위험', '금융상품 위험등급', 20, TRUE),
    ('FINANCIAL_PRODUCT_RISK_GRADE', 'MEDIUM', '보통 위험', '금융상품 위험등급', 30, TRUE),
    ('FINANCIAL_PRODUCT_RISK_GRADE', 'MODERATELY_HIGH', '다소 높은 위험', '금융상품 위험등급', 40, TRUE),
    ('FINANCIAL_PRODUCT_RISK_GRADE', 'HIGH', '높은 위험', '금융상품 위험등급', 50, TRUE),
    ('FINANCIAL_PRODUCT_RISK_GRADE', 'VERY_HIGH', '매우 높은 위험', '금융상품 위험등급', 60, TRUE),
    ('FINANCIAL_PRODUCT_AVAILABILITY', 'AVAILABLE', '판매 중', '현재 가입 가능한 금융상품', 10, TRUE),
    ('FINANCIAL_PRODUCT_AVAILABILITY', 'UNAVAILABLE', '가입 불가', '일시적으로 가입할 수 없는 금융상품', 20, TRUE),
    ('FINANCIAL_PRODUCT_AVAILABILITY', 'SALE_ENDED', '판매 종료', '판매가 종료된 금융상품', 30, TRUE),
    ('REPORT_STAGE', 'PROPERTY_COMPARISON', '관심주택 비교', '추천·관심주택 비교를 포함한 보고서', 20, TRUE),
    ('REPORT_STAGE', 'FINANCIAL_PLAN', '자금 운용 계획', '금융상품 관심 정보까지 포함한 보고서', 30, TRUE),
    ('REPORT_STATUS', 'GENERATING', '생성 중', 'PDF 파일을 생성하고 있는 상태', 10, TRUE),
    ('REPORT_STATUS', 'READY', '다운로드 가능', 'PDF 생성이 완료된 상태', 20, TRUE),
    ('REPORT_STATUS', 'FAILED', '생성 실패', 'PDF 생성에 실패한 상태', 30, TRUE),
    ('REPORT_STATUS', 'DELETING', '삭제 중', '보관기간 만료 후 파일을 삭제하는 상태', 40, TRUE)
ON DUPLICATE KEY UPDATE
    code_name = VALUES(code_name),
    description = VALUES(description),
    display_order = VALUES(display_order),
    is_active = VALUES(is_active);

-- Populate Korean 대분류명. 중분류가 필요한 신규 코드는 middle_code와
-- middle_code_name을 함께 입력하고, 기존 단일 단계 코드는 빈 문자열을 쓴다.
UPDATE common_codes
SET code_group_name = CASE code_group
    WHEN 'USER_STATUS' THEN '회원 상태'
    WHEN 'ACTION_TOKEN_PURPOSE' THEN '계정 처리 토큰 용도'
    WHEN 'PASSWORD_CHANGE_SOURCE' THEN '비밀번호 변경 경로'
    WHEN 'SOCIAL_PROVIDER' THEN '소셜 로그인 제공자'
    WHEN 'DELETION_REASON' THEN '회원탈퇴 사유'
    WHEN 'SURVEY_STATUS' THEN '설문 상태'
    WHEN 'SURVEY_STEP' THEN '설문 단계'
    WHEN 'RESERVE_OPTION' THEN '유보금 선택'
    WHEN 'PROPERTY_AVAILABILITY' THEN '매물 가용 상태'
    WHEN 'SUITABILITY_GRADE' THEN '적합도 등급'
    WHEN 'HISTORY_ENTITY_TYPE' THEN '이력 대상 유형'
    WHEN 'HISTORY_EVENT_TYPE' THEN '이력 사건 유형'
    WHEN 'RISK_TOLERANCE' THEN '투자 위험 성향'
    WHEN 'INVESTMENT_PERIOD' THEN '투자 기간'
    WHEN 'FINANCIAL_PRODUCT_CATEGORY' THEN '금융상품 유형'
    WHEN 'FINANCIAL_PRODUCT_RISK_GRADE' THEN '금융상품 위험 등급'
    WHEN 'FINANCIAL_PRODUCT_AVAILABILITY' THEN '금융상품 판매 상태'
    WHEN 'REPORT_STAGE' THEN '보고서 단계'
    WHEN 'REPORT_STATUS' THEN '보고서 상태'
    ELSE code_group
END
WHERE code_group_name = '';

-- Idempotent survey-profile seed data.
INSERT INTO housing_preference_profiles (
    profile_code,
    title,
    card_description,
    popup_description,
    popup_footer,
    safety_weight,
    convenience_weight,
    asset_weight,
    display_order,
    is_active
) VALUES
    (
        'SAFETY_FIRST',
        '안전 최우선형',
        '안전한 생활환경을 가장 중요하게 생각해요',
        '침수·산사태 위험과 피난 동선, 소방 접근성을 우선해서 살펴보는 성향입니다.',
        '안전 조건을 우선으로 하되 기본 생활 편의도 함께 확인해드려요.',
        60.00, 20.00, 20.00, 1, TRUE
    ),
    (
        'VALUE_STABILITY',
        '가성비·거래안정 중시형',
        '가격과 나중에 되팔기 쉬운지를 함께 봐요',
        '합리적인 가격과 거래량, 가격 변동성을 고르게 확인하는 성향입니다.',
        '가격 부담과 환금성을 균형 있게 반영해드려요.',
        50.00, 10.00, 40.00, 2, TRUE
    ),
    (
        'BALANCED',
        '무난한 기본형',
        '안전·편의·자산을 고르게 살펴봐요',
        '한 항목에 치우치지 않고 세 가지 기준을 안정적으로 비교하는 성향입니다.',
        '잘 모르겠을 때 선택하기 좋은 균형형입니다.',
        40.00, 30.00, 30.00, 3, TRUE
    ),
    (
        'CONVENIENCE_FIRST',
        '편의시설·생활여건 중시형',
        '병원과 마트, 교통이 가까운지를 중요하게 봐요',
        '의료·교통·생활시설의 접근성을 우선해서 살펴보는 성향입니다.',
        '일상 이동이 편한 주거지를 찾는 데 초점을 맞춰드려요.',
        50.00, 40.00, 10.00, 4, TRUE
    )
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    card_description = VALUES(card_description),
    popup_description = VALUES(popup_description),
    popup_footer = VALUES(popup_footer),
    safety_weight = VALUES(safety_weight),
    convenience_weight = VALUES(convenience_weight),
    asset_weight = VALUES(asset_weight),
    display_order = VALUES(display_order),
    is_active = VALUES(is_active);

-- Safe periodic token cleanup. Run from a scheduled backend job.
DELETE FROM auth_sessions
WHERE expires_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 7 DAY)
   OR revoked_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 7 DAY);

DELETE FROM email_verifications
WHERE expires_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)
   OR used_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)
   OR revoked_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY);

DELETE FROM password_reset_tokens
WHERE expires_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)
   OR used_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)
   OR revoked_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY);

-- Report cleanup is a two-resource operation and must be completed by the backend:
--   1. Lock/select expired rows and mark them DELETING.
--   2. Delete the private PDF object using file_storage_key.
--   3. Delete the generated_reports row only after object deletion succeeds.
-- This query identifies a bounded cleanup batch without deleting file metadata first.
SELECT
    report_id,
    user_id,
    file_storage_key,
    status,
    expires_at
FROM generated_reports
WHERE expires_at <= CURRENT_TIMESTAMP(6)
  AND status IN ('READY', 'FAILED', 'DELETING')
ORDER BY expires_at
LIMIT 100;
