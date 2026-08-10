SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name = 'survey_recommendation_items') > 0,
    'SELECT ''survey_recommendation_items 가 이미 있습니다'' AS skipped',
    'CREATE TABLE survey_recommendation_items (
        recommendation_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        row_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
            NOT NULL DEFAULT (UUID()),
        survey_id BIGINT UNSIGNED NOT NULL COMMENT ''어떤 설문으로 추천했는지'',
        rank_no TINYINT UNSIGNED NOT NULL COMMENT ''추천 순위. 1이 1위'',

        house_id INT UNSIGNED NOT NULL
            COMMENT ''조회 시점 house_id. 논리 참조라 외래키를 걸지 않는다'',

        house_name VARCHAR(200) NOT NULL COMMENT ''조회 시점 단지명'',
        jibun_address VARCHAR(300) NULL COMMENT ''조회 시점 지번주소'',
        house_price_amount BIGINT UNSIGNED NOT NULL COMMENT ''조회 시점 매매가(원)'',
        exclusive_area_sqm DECIMAL(6,2) NULL COMMENT ''조회 시점 전용면적(㎡)'',
        latitude DECIMAL(10,7) NULL,
        longitude DECIMAL(10,7) NULL,

        total_score TINYINT UNSIGNED NOT NULL COMMENT ''조회 시점 종합 점수'',
        remaining_amount BIGINT NULL
            COMMENT ''실수령액 - 매매가. 예산을 넘는 매물이면 음수'',

        profile_code VARCHAR(40) NOT NULL COMMENT ''그때 적용한 성향'',

        del_yn CHAR(1) NOT NULL DEFAULT ''N'',
        created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        created_by VARCHAR(100) NOT NULL DEFAULT ''SYSTEM'',
        updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
            ON UPDATE CURRENT_TIMESTAMP(6),
        updated_by VARCHAR(100) NOT NULL DEFAULT ''SYSTEM'',

        PRIMARY KEY (recommendation_item_id),
        UNIQUE KEY uq_survey_recommendation_items_row_uuid (row_uuid),
        UNIQUE KEY uq_survey_recommendation_items_rank (survey_id, rank_no),
        INDEX idx_survey_recommendation_items_house (house_id),
        CONSTRAINT fk_survey_recommendation_items_survey
            FOREIGN KEY (survey_id) REFERENCES housing_surveys (survey_id)
            ON DELETE CASCADE ON UPDATE RESTRICT,
        CONSTRAINT chk_survey_recommendation_items_rank CHECK (rank_no BETWEEN 1 AND 50),
        CONSTRAINT chk_survey_recommendation_items_score CHECK (total_score <= 100)
    ) ENGINE = InnoDB
      DEFAULT CHARSET = utf8mb4
      COLLATE = utf8mb4_0900_ai_ci
      COMMENT = ''설문 시점에 보여준 추천 매물 스냅샷'''
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
