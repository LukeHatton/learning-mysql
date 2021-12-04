USE test_database;

/*================ 测试查询速度 ================*/
SELECT COUNT(*)
FROM test_table;

EXPLAIN
SELECT *
FROM test_table
    # LIMIT 900000,100;
WHERE id BETWEEN 900000 AND 900100;

EXPLAIN
SELECT *
FROM test_table
WHERE id = 99271;


/*================ 主键为UUID的大量数据 ================*/
DROP TABLE test_table_uuid;
CREATE TABLE test_table_uuid
(
    id       VARCHAR(36) NOT NULL,
    column_2 VARCHAR(64) NULL,
    column_3 VARCHAR(64) NULL,
    column_4 VARCHAR(64) NULL,
    column_5 VARCHAR(64) NULL,
    column_6 VARCHAR(64) NULL,
    column_7 VARCHAR(64) NULL,
    column_8 VARCHAR(64) NULL,
    column_9 VARCHAR(64) NULL,
    CONSTRAINT test_table_uuid_pk
        PRIMARY KEY (id)
)
    COMMENT '主键为uuid的表';

CREATE UNIQUE INDEX test_table_uuid_id_uindex
    ON test_table_uuid (id);

ALTER TABLE test_table_uuid_2
    ADD row_num INT NULL;

CREATE UNIQUE INDEX test_table_uuid_2_row_num_uindex
    ON test_table_uuid_2 (row_num);


/*---------------- 插入测试数据 ----------------*/
# UUID(),中文2,中文3,中文4,中文5,中文6,中文7,中文8,中文9
# 在insert中使用函数果然很慢，每秒平均插入量在一万左右，一百万数据插入花费两分钟
DROP PROCEDURE IF EXISTS procedure_insert_foo_data;
DELIMITER %
CREATE PROCEDURE procedure_insert_foo_data()
BEGIN
    DECLARE loop_index INTEGER DEFAULT 0;
    loop_label: LOOP
        IF loop_index >= 1000000 THEN
            LEAVE loop_label ;
        END IF;
        INSERT INTO test_table_uuid (id, column_2, column_3, column_4, column_5, column_6, column_7, column_8, column_9)
        VALUES (UUID(), '中文2', '中文3', '中文4', '中文5', '中文6', '中文7', '中文8', '中文9');
        SET loop_index = loop_index + 1;
    END LOOP loop_label;
END %
DELIMITER ;

CALL procedure_insert_foo_data;

SELECT LAST_INSERT_ID();


/*================ 寻找加快数据分页的方法 ================*/
# 全表扫描花费4.6s，平均每秒查询量在20万左右
EXPLAIN
SELECT *
FROM test_table_uuid;

# 分页查询优化
# 耗时：713ms, execution 501ms, fetching 212ms
EXPLAIN
SELECT *
FROM test_table_uuid
LIMIT 900000,30000;

SELECT *
FROM (
    SELECT *, ROW_NUMBER() OVER (ORDER BY column_2) r
    FROM test_table_uuid
    LIMIT 100
     ) t
WHERE r BETWEEN 10 AND 20;

# 虽然使用row_number()函数貌似很慢，但如果其时间复杂度是O(logn)，那么也是可用的
# 取100，1000，10000条数据的row_number()并没有明显差别
# 确定了，该函数执行时间只和表总数据量有关
SELECT id, ROW_NUMBER() OVER () AS 'row_number'
FROM test_table_uuid
LIMIT 1000000;

# 耗时：340ms, execution 166ms, fetching 174ms
EXPLAIN
SELECT *
FROM test_table_uuid t
    INNER JOIN
(
    SELECT id
    FROM test_table_uuid
    LIMIT 900000,30000
)                    t2 ON t.id = t2.id;

#
SELECT id, ROW_NUMBER() OVER () AS 'row_number'
FROM test_table_uuid;
