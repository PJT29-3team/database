-- Jiphyeonjeon final integrated schema
-- Target: MySQL 8.0+
-- Scope: member management, housing survey/current home, favorite properties,
--        financial preferences/products, and generated PDF report history.
--
-- Fresh-install DDL:
--   This file drops and recreates the 16 approved tables.
-- Security:
--   Raw refresh/action tokens must never be stored. Only SHA-256 hashes are stored.
-- Calculation policy:
--   Remaining funds and estimated selling costs are calculated by the backend.
--   The database stores calculation inputs and immutable output snapshots only.
-- Static content:
--   Notices, FAQ, policies, and customer-center phone information are not DB tables.

SET NAMES utf8mb4;

DROP TABLE IF EXISTS common_codes;
DROP TABLE IF EXISTS generated_reports;
DROP TABLE IF EXISTS favorite_financial_products;
DROP TABLE IF EXISTS financial_investment_profiles;
DROP TABLE IF EXISTS favorite_properties;
DROP TABLE IF EXISTS survey_desired_regions;
DROP TABLE IF EXISTS housing_surveys;
DROP TABLE IF EXISTS home_analysis_snapshots;
DROP TABLE IF EXISTS service_change_histories;
DROP TABLE IF EXISTS user_home_histories;
DROP TABLE IF EXISTS user_homes;
DROP TABLE IF EXISTS housing_preference_profiles;
DROP TABLE IF EXISTS account_deletion_requests;
DROP TABLE IF EXISTS social_accounts;
DROP TABLE IF EXISTS account_action_tokens;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;

-- Shared application codes. Business tables deliberately have no physical
-- foreign keys to this table; the backend validates active codes.
CREATE TABLE common_codes (
    common_code_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    code_group VARCHAR(60) NOT NULL,
    code VARCHAR(60) NOT NULL,
    code_name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (common_code_id),
    UNIQUE KEY uq_common_codes_row_uuid (row_uuid),
    UNIQUE KEY uq_common_codes_group_code (code_group, code),
    INDEX idx_common_codes_group_active (code_group, is_active, display_order)
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

-- 2. JWT refresh token sessions. token_hash is SHA-256 hexadecimal text.
CREATE TABLE refresh_tokens (
    refresh_token_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    device_name VARCHAR(255) NULL COMMENT 'Session/device label shown to the user',
    expires_at DATETIME(6) NOT NULL,
    revoked_at DATETIME(6) NULL COMMENT 'Rotation or logout revocation timestamp',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (refresh_token_id),
    UNIQUE KEY uq_refresh_tokens_row_uuid (row_uuid),
    UNIQUE KEY uq_refresh_tokens_hash (token_hash),
    INDEX idx_refresh_tokens_user_active (user_id, revoked_at, expires_at),
    INDEX idx_refresh_tokens_cleanup (expires_at, revoked_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'JWT Refresh Token 해시와 회전·로그아웃 상태';

-- 3. One-time email verification/change/password reset tokens.
CREATE TABLE account_action_tokens (
    action_token_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    purpose VARCHAR(32) NOT NULL,
    target_email VARCHAR(320) NULL COMMENT 'Signup/email-change destination',
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    consumed_at DATETIME(6) NULL,
    revoked_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (action_token_id),
    UNIQUE KEY uq_account_action_tokens_row_uuid (row_uuid),
    UNIQUE KEY uq_action_tokens_hash (token_hash),
    INDEX idx_action_tokens_active (
        user_id,
        purpose,
        consumed_at,
        revoked_at,
        expires_at
    ),
    INDEX idx_action_tokens_cleanup (expires_at, consumed_at, revoked_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '회원가입 이메일 인증·이메일 변경·비밀번호 재설정 일회용 토큰';

-- 4. Social provider identity linked to one user.
CREATE TABLE social_accounts (
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
    UNIQUE KEY uq_social_accounts_row_uuid (row_uuid),
    UNIQUE KEY uq_social_provider_user (provider, provider_user_id),
    UNIQUE KEY uq_social_user_provider (user_id, provider)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '카카오·네이버 소셜 계정 연결정보';

-- 5. Withdrawal request with 30-day grace period and cancellation state.
CREATE TABLE account_deletion_requests (
    deletion_request_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    reason_code VARCHAR(40) NOT NULL,
    reason_detail VARCHAR(500) NULL COMMENT 'Required only when reason_code is OTHER',
    data_deletion_consent_at DATETIME(6) NOT NULL,
    requested_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    scheduled_delete_at DATETIME(6) NOT NULL,
    cancelled_at DATETIME(6) NULL,
    completed_at DATETIME(6) NULL,
    active_user_id BIGINT UNSIGNED GENERATED ALWAYS AS (
        CASE
            WHEN cancelled_at IS NULL AND completed_at IS NULL THEN user_id
            ELSE NULL
        END
    ) STORED,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (deletion_request_id),
    UNIQUE KEY uq_account_deletion_requests_row_uuid (row_uuid),
    UNIQUE KEY uq_active_deletion_request (active_user_id),
    INDEX idx_account_deletion_due (
        scheduled_delete_at,
        cancelled_at,
        completed_at
    ),
    INDEX idx_account_deletion_user_requested (user_id, requested_at DESC)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '30일 유예 회원탈퇴 신청·취소·완료 기록';

-- 6. Static survey cards and top-level safety/convenience/asset weights.
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

-- 7. One editable current home per user.
CREATE TABLE user_homes (
    user_home_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    external_property_key VARCHAR(255) NOT NULL,
    external_unit_type_key VARCHAR(255) NULL,
    road_address VARCHAR(500) NOT NULL,
    jibun_address VARCHAR(500) NULL,
    detail_address VARCHAR(255) NULL,
    building_name VARCHAR(255) NULL,
    postal_code VARCHAR(20) NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    move_in_date_ymd VARCHAR(8) NOT NULL COMMENT '입주일자 yyyyMMdd',
    selected_supply_area_sqm DECIMAL(10, 2) NULL,
    selected_exclusive_area_sqm DECIMAL(10, 2) NULL,
    has_mortgage BOOLEAN NOT NULL DEFAULT FALSE,
    mortgage_balance_amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (user_home_id),
    UNIQUE KEY uq_user_homes_row_uuid (row_uuid),
    UNIQUE KEY uq_user_homes_user (user_id),
    INDEX idx_user_homes_property (external_property_key)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '사용자가 수정할 수 있는 현재집 원본정보';

-- 8. Append-only audit history shared by the main service domains.
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

-- 9. Immutable-ish home analysis output used by completed surveys and reports.
CREATE TABLE home_analysis_snapshots (
    snapshot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_home_id BIGINT UNSIGNED NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    error_code VARCHAR(100) NULL,
    external_property_key VARCHAR(255) NOT NULL,
    external_unit_type_key VARCHAR(255) NULL,
    road_address VARCHAR(500) NOT NULL,
    jibun_address VARCHAR(500) NULL,
    building_name VARCHAR(255) NULL,
    postal_code VARCHAR(20) NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    move_in_date_ymd VARCHAR(8) NOT NULL COMMENT '분석 기준 입주일자 yyyyMMdd',
    built_date_ymd VARCHAR(8) NULL COMMENT '준공일자 yyyyMMdd',
    building_age_years SMALLINT UNSIGNED NULL,
    total_households INT UNSIGNED NULL,
    building_count SMALLINT UNSIGNED NULL,
    heating_type VARCHAR(100) NULL,
    selected_supply_area_sqm DECIMAL(10, 2) NULL,
    selected_exclusive_area_sqm DECIMAL(10, 2) NULL,
    room_count SMALLINT UNSIGNED NULL,
    bathroom_count SMALLINT UNSIGNED NULL,
    unit_household_count INT UNSIGNED NULL,
    estimated_market_price_amount BIGINT UNSIGNED NULL
        COMMENT 'External market API estimate',
    mortgage_balance_amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
    estimated_selling_cost_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated cost estimate',
    estimated_net_proceeds_amount BIGINT UNSIGNED NULL
        COMMENT 'Backend-calculated net proceeds estimate',
    suitability_grade VARCHAR(20) NULL,
    ai_summary TEXT NULL,
    unit_types_json JSON NULL,
    price_trend_json JSON NULL,
    recent_transactions_json JSON NULL,
    source_name VARCHAR(100) NULL,
    source_reference_id VARCHAR(255) NULL,
    source_valued_at DATETIME(6) NULL,
    completed_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (snapshot_id),
    UNIQUE KEY uq_home_analysis_snapshots_row_uuid (row_uuid),
    INDEX idx_home_snapshots_latest (user_home_id, status, completed_at DESC),
    INDEX idx_home_snapshots_source (
        source_name,
        source_reference_id,
        source_valued_at
    )
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '외부 시세와 백엔드 계산 결과를 보존하는 현재집 분석 스냅샷';

-- 10. Survey execution. Multiple completed surveys are retained; one can be active.
CREATE TABLE housing_surveys (
    survey_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    profile_code VARCHAR(40) NULL,
    home_analysis_snapshot_id BIGINT UNSIGNED NULL,
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

-- 11. Multiple desired regions selected without ordering.
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

-- 12. Only user-favorited properties are persisted; recommendation results are not.
CREATE TABLE favorite_properties (
    favorite_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    evaluated_survey_id BIGINT UNSIGNED NOT NULL,
    external_property_key VARCHAR(255) NOT NULL,
    availability_status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    evaluation_policy_version VARCHAR(40) NOT NULL,
    asking_price_amount BIGINT UNSIGNED NOT NULL,
    remaining_budget_amount BIGINT NOT NULL
        COMMENT 'Backend result: survey purchase budget minus asking price',
    total_score DECIMAL(5, 2) NOT NULL,
    safety_score DECIMAL(5, 2) NOT NULL,
    convenience_score DECIMAL(5, 2) NOT NULL,
    asset_score DECIMAL(5, 2) NOT NULL,
    property_snapshot_json JSON NOT NULL,
    evaluation_details_json JSON NOT NULL,
    saved_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    evaluated_at DATETIME(6) NOT NULL,
    last_checked_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (favorite_id),
    UNIQUE KEY uq_favorite_properties_row_uuid (row_uuid),
    UNIQUE KEY uq_favorite_properties_user_property (user_id, external_property_key),
    INDEX idx_favorite_properties_user_saved (user_id, saved_at DESC),
    INDEX idx_favorite_properties_survey (evaluated_survey_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '사용자가 직접 관심 등록한 주택과 최신 재평가 스냅샷';

-- 13. One current financial recommendation condition set per user.
CREATE TABLE financial_investment_profiles (
    investment_profile_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    selected_favorite_id BIGINT UNSIGNED NOT NULL
        COMMENT 'Favorite property used as the downsizing fund basis',
    investment_ratio_percent DECIMAL(5, 2) NOT NULL,
    risk_tolerance VARCHAR(20) NOT NULL,
    investment_period_code VARCHAR(20) NOT NULL
        COMMENT 'INVESTMENT_PERIOD 코드',
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (investment_profile_id),
    UNIQUE KEY uq_financial_investment_profiles_row_uuid (row_uuid),
    UNIQUE KEY uq_financial_profiles_user (user_id),
    INDEX idx_financial_profiles_favorite (selected_favorite_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '관심주택을 기준으로 한 사용자의 최신 금융상품 추천 조건';

-- 14. Only products explicitly favorited by the user are persisted.
CREATE TABLE favorite_financial_products (
    favorite_financial_product_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT (UUID()),
    user_id BIGINT UNSIGNED NOT NULL,
    source_code VARCHAR(40) NOT NULL,
    external_product_key VARCHAR(255) NOT NULL,
    product_category_code VARCHAR(40) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    institution_name VARCHAR(255) NOT NULL,
    product_risk_grade VARCHAR(30) NOT NULL,
    availability_status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    product_snapshot_json JSON NOT NULL
        COMMENT 'Provider data and display values captured when saved/refreshed',
    saved_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_checked_at DATETIME(6) NULL,
    del_yn CHAR(1) NOT NULL DEFAULT 'N',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    PRIMARY KEY (favorite_financial_product_id),
    UNIQUE KEY uq_favorite_financial_products_row_uuid (row_uuid),
    UNIQUE KEY uq_financial_products_user_source_key (user_id, source_code, external_product_key),
    INDEX idx_fin_favorites_user_saved (user_id, saved_at DESC),
    INDEX idx_fin_favorites_product (source_code, external_product_key)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '사용자가 관심 등록한 금융상품의 표시 스냅샷';

-- 15. MyPage report history. PDF bytes live in private object/file storage.
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
    ('USER_STATUS', 'PENDING_DELETE', '탈퇴 유예', '탈퇴 신청 후 30일 유예 중인 계정', 40, TRUE),
    ('USER_STATUS', 'DELETED', '탈퇴 완료', '개인정보 익명화가 완료된 계정', 50, TRUE),
    ('USER_STATUS', 'SUSPENDED', '이용 정지', '운영 정책에 따라 이용이 정지된 계정', 60, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'SIGNUP', '회원가입 인증', '회원가입 이메일 인증 토큰', 10, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'EMAIL_CHANGE', '이메일 변경', '이메일 주소 변경 인증 토큰', 20, TRUE),
    ('ACTION_TOKEN_PURPOSE', 'PASSWORD_RESET', '비밀번호 재설정', '비밀번호 재설정 토큰', 30, TRUE),
    ('SOCIAL_PROVIDER', 'KAKAO', '카카오', '카카오 소셜 로그인', 10, TRUE),
    ('SOCIAL_PROVIDER', 'NAVER', '네이버', '네이버 소셜 로그인', 20, TRUE),
    ('DELETION_REASON', 'NO_LONGER_NEEDED', '더 이상 서비스를 이용하지 않음', '회원탈퇴 선택 사유', 10, TRUE),
    ('DELETION_REASON', 'PRIVACY_CONCERN', '개인정보 보호 우려', '회원탈퇴 선택 사유', 20, TRUE),
    ('DELETION_REASON', 'DIFFICULT_TO_USE', '서비스 사용이 어려움', '회원탈퇴 선택 사유', 30, TRUE),
    ('DELETION_REASON', 'OTHER', '기타', '상세 사유를 함께 입력하는 회원탈퇴 사유', 40, TRUE),
    ('HOME_ANALYSIS_STATUS', 'PENDING', '분석 대기', '외부 시세 조회 및 분석 대기', 10, TRUE),
    ('HOME_ANALYSIS_STATUS', 'COMPLETED', '분석 완료', '현재집 분석이 정상 완료됨', 20, TRUE),
    ('HOME_ANALYSIS_STATUS', 'FAILED', '분석 실패', '외부 조회 또는 계산 실패', 30, TRUE),
    ('SURVEY_STATUS', 'IN_PROGRESS', '진행 중', '설문 응답을 입력 중인 상태', 10, TRUE),
    ('SURVEY_STATUS', 'COMPLETED', '완료', '설문과 예산 계산이 완료된 상태', 20, TRUE),
    ('SURVEY_STEP', 'INTRO', '설문 시작', '설문 안내 및 시작 전 단계', 0, TRUE),
    ('SURVEY_STEP', 'CURRENT_HOME', '현재집 확인', '현재집 주소 선택과 시세 분석 단계', 10, TRUE),
    ('SURVEY_STEP', 'PREFERENCE_PROFILE', '주거 선호 선택', '안전·생활·자산 선호 유형 선택 단계', 20, TRUE),
    ('SURVEY_STEP', 'MORTGAGE', '담보대출 확인', '현재집 담보대출 여부와 잔액 입력 단계', 30, TRUE),
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
    ('HISTORY_ENTITY_TYPE', 'USER_HOME', '현재집', '현재집 등록·수정·삭제 대상', 20, TRUE),
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
    ('RISK_TOLERANCE', 'HIGH', '높은 위험', '수익을 위해 가격 변동을 감수하는 성향', 30, TRUE),
    ('INVESTMENT_PERIOD', 'SHORT', '단기', '1년 이내 투자 기간', 10, TRUE),
    ('INVESTMENT_PERIOD', 'MEDIUM', '중기', '1년 초과 3년 이내 투자 기간', 20, TRUE),
    ('INVESTMENT_PERIOD', 'LONG', '장기', '3년 초과 투자 기간', 30, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'DEPOSIT', '예금', '정기예금 등 예금 상품', 10, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'SAVINGS', '적금', '정기적금 등 적립식 상품', 20, TRUE),
    ('FINANCIAL_PRODUCT_CATEGORY', 'CMA', 'CMA', '종합자산관리계좌 상품', 30, TRUE),
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
    ('REPORT_STAGE', 'CURRENT_HOME', '현재집 진단', '현재집 분석까지 포함한 보고서', 10, TRUE),
    ('REPORT_STAGE', 'PROPERTY_COMPARISON', '관심주택 비교', '현재집과 관심주택 비교까지 포함한 보고서', 20, TRUE),
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
        60.00, 25.00, 15.00, 1, TRUE
    ),
    (
        'VALUE_STABILITY',
        '가성비·거래안정 중시형',
        '가격과 나중에 되팔기 쉬운지를 함께 봐요',
        '합리적인 가격과 거래량, 가격 변동성을 고르게 확인하는 성향입니다.',
        '가격 부담과 환금성을 균형 있게 반영해드려요.',
        40.00, 20.00, 40.00, 2, TRUE
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
        40.00, 40.00, 20.00, 4, TRUE
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
DELETE FROM refresh_tokens
WHERE expires_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 7 DAY)
   OR revoked_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 7 DAY);

DELETE FROM account_action_tokens
WHERE expires_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)
   OR consumed_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)
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
