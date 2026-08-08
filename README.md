# database

## 신규 세팅 순서

두 DDL 파일은 겹치는 테이블 19개를 각자 정의한다. **나중에 실행한 쪽이 이긴다.**
아래 순서를 지켜야 백엔드가 요구하는 스키마가 나온다.

```bash
mysql -uroot -p<pw> --default-character-set=utf8mb4 <db> -e "SET FOREIGN_KEY_CHECKS=0; SOURCE ddl.sql; SET FOREIGN_KEY_CHECKS=1;"
mysql -uroot -p<pw> --default-character-set=utf8mb4 <db> -e "SET FOREIGN_KEY_CHECKS=0; SOURCE house.sql; SET FOREIGN_KEY_CHECKS=1;"
mysql -uroot -p<pw> --default-character-set=utf8mb4 <db> < survey/20260806_01__housing_surveys_desired_area.sql
mysql -uroot -p<pw> --default-character-set=utf8mb4 <db> < seed/financial-products.sql
```

`SET FOREIGN_KEY_CHECKS=0` 없이 돌리면 **중간에 멈춰 스키마가 반쯤 부서진 채로 남는다.**
두 파일의 `DROP TABLE` 목록이 서로 달라서, 상대 파일이 만든 테이블의 FK가 DROP을 막기 때문이다.

```
ERROR 3730: Cannot drop table 'housing_surveys' referenced by a foreign key
            constraint 'fk_house_favorites_survey' on table 'house_favorites'
```

## 각 파일의 역할

| 파일 | 내용 |
|---|---|
| `ddl.sql` | 전체 스키마 21개 테이블. `house.sql`에 없는 `user_homes`, `financial_product_interaction_log`를 여기서만 만든다 |
| `house.sql` | 매물(`house`, `house_score`, `score_details`) 포함 23개 테이블. 겹치는 테이블은 이쪽이 최종본이다 |
| `survey/*.sql` | 운영 중인 DB용 증분 변경. 여러 번 실행해도 안전하다 |
| `seed/financial-products.sql` | 금융상품 목업 데이터. 만기 있는 상품만, 적금(SAVINGS) 제외 |

`ddl.sql`이 만드는 `favorite_properties`, `home_analysis_snapshots`는 팀이 쓰지 않는
옛 설계다(백엔드가 `house_favorites`와 `housing_surveys` 컬럼을 대신 쓴다). 빈 채로 남아도 무해하다.

## 주의

**겹치는 19개 테이블은 `ddl.sql`만 고치면 반영되지 않는다.** `house.sql`이 나중에 실행되어
덮어쓰기 때문이다. 두 파일을 같이 고쳐야 한다.
