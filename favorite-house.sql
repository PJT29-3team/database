-- 기존 페르소나 점수 테이블 제거
DROP TABLE IF EXISTS house_persona_score;

-- house_id 컬럼 추가
ALTER TABLE house_favorites_history
    ADD COLUMN house_id INT UNSIGNED NULL
    COMMENT '관심 등록한 매물 인덱스'
    AFTER survey_id;

-- 기존 관심매물 데이터에서 매물 ID 복원
UPDATE house_favorites_history hfh
JOIN house_favorites hf
  ON hf.house_favorites_id = hfh.house_favorites_id
SET hfh.house_id = hf.house_id
WHERE hfh.house_id IS NULL;

-- 이미 삭제된 관심매물의 복원 불가능한 이력 제거
DELETE FROM house_favorites_history
WHERE house_id IS NULL;

-- 필수값으로 변경
ALTER TABLE house_favorites_history
    MODIFY COLUMN house_id INT UNSIGNED NOT NULL
    COMMENT '관심 등록한 매물 인덱스';

-- 현재 관심매물 삭제와 히스토리 삭제가 연동되지 않도록 기존 FK 제거
ALTER TABLE house_favorites_history
    DROP FOREIGN KEY fk_house_favorites_history_favorite;

-- 매물 기준 조회 인덱스 및 house FK 추가
ALTER TABLE house_favorites_history
    ADD INDEX idx_house_favorites_history_house_created
        (house_id, created_at DESC),
    ADD CONSTRAINT fk_house_favorites_history_house
        FOREIGN KEY (house_id)
        REFERENCES house (house_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;
