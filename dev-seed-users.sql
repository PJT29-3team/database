-- 로컬 개발용 로그인 목업 계정. ddl.sql 실행 후 필요할 때만 수동 실행한다.
-- 운영 환경에는 절대 실행하지 않는다.
-- 비밀번호: test1234!

INSERT INTO users (
    email, password_hash, name, birth_year, phone_number,
    email_verified_at, status
) VALUES (
    'tester@jiphyeonjeon.local',
    '$2a$10$bA27fqITAEtUylUdBvX.oeMyRZSnqYeSFe5B4UBo1k.L2BP7GZ/QC',
    '테스터',
    1985,
    '010-1234-5678',
    CURRENT_TIMESTAMP(6),
    'ACTIVE'
)
ON DUPLICATE KEY UPDATE
    password_hash = VALUES(password_hash),
    status = VALUES(status),
    email_verified_at = VALUES(email_verified_at);
