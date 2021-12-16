/*================ 建表语句 ================*/
CREATE TABLE test_table_uuid
(
    id       uuid NOT NULL
        CONSTRAINT test_table_uuid_pk
            PRIMARY KEY,
    column_2 VARCHAR(64),
    column_3 VARCHAR(64),
    column_4 VARCHAR(64),
    column_5 VARCHAR(64),
    column_6 VARCHAR(64),
    column_7 VARCHAR(64),
    column_8 VARCHAR(64),
    column_9 VARCHAR(64),
    row_num  SERIAL
);

COMMENT ON TABLE test_table_uuid IS '主键为uuid的表';

ALTER TABLE test_table_uuid
    OWNER TO postgres;

CREATE UNIQUE INDEX test_table_uuid_id_uindex
    ON test_table_uuid (id);

CREATE UNIQUE INDEX test_table_uuid_row_num_uindex
    ON test_table_uuid (row_num);

/*================ 存储过程 ================*/
CREATE OR REPLACE FUNCTION insert_foo_data()
    RETURNS VOID AS
$$
DECLARE
    total INTEGER DEFAULT 0;
BEGIN
    WHILE total < 1000 * 1000 LOOP
        INSERT INTO test_table_uuid(id, column_2, column_3, column_4, column_5, column_6, column_7, column_8, column_9)
        VALUES (gen_random_uuid(), '中文2', '中文3', '中文4', '中文5', '中文6', '中文7', '中文8', '中文9');
        total = total + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

/*================ 测试语句 ================*/
SELECT *
FROM pgbench_accounts
LIMIT 900000 OFFSET 10;

TRUNCATE test_table_uuid;

-- 百万数据插入耗时，主键使用gen_random_uuid()函数，耗时：10 s 289 ms
SELECT insert_foo_data();

-- 重置自增计数
SELECT SETVAL('test_table_uuid_row_num_seq', 1, FALSE);

SELECT COUNT(*)
FROM test_table_uuid;
