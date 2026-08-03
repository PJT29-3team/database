ALTER TABLE housing_surveys
    CHANGE COLUMN current_step current_step_code VARCHAR(40) NOT NULL DEFAULT 'INTRO'
        COMMENT 'SURVEY_STEP 공통 코드';
