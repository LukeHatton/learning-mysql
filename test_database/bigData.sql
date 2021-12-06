CREATE DATABASE test_database;

USE test_database;

/* ================ 建表语句 ================= */
-- auto-generated definition
CREATE TABLE test_table
(
    id       INT AUTO_INCREMENT
        PRIMARY KEY,
    column_2 VARCHAR(64) NULL,
    column_3 VARCHAR(64) NULL,
    column_4 VARCHAR(64) NULL,
    column_5 VARCHAR(64) NULL,
    column_6 VARCHAR(64) NULL,
    column_7 VARCHAR(64) NULL,
    column_8 VARCHAR(64) NULL,
    column_9 VARCHAR(64) NULL,
    CONSTRAINT test_table_id_uindex
        UNIQUE (id)
)
    COMMENT '测试表' ENGINE = MyISAM;

CREATE TABLE test_table_uuid
(
    id       VARCHAR(36) NOT NULL
        PRIMARY KEY,
    column_2 VARCHAR(64) NULL,
    column_3 VARCHAR(64) NULL,
    column_4 VARCHAR(64) NULL,
    column_5 VARCHAR(64) NULL,
    column_6 VARCHAR(64) NULL,
    column_7 VARCHAR(64) NULL,
    column_8 VARCHAR(64) NULL,
    column_9 VARCHAR(64) NULL,
    row_num  INT         NULL
)
    COMMENT '主键为uuid的表';


/*================ 测试查询速度 ================*/
SELECT COUNT(*)
FROM test_table;

EXPLAIN
SELECT *
FROM test_table
LIMIT 900000,100;
# WHERE id BETWEEN 900000 AND 900100;

EXPLAIN
SELECT *
FROM test_table
WHERE id = 99271;


/*================ 主键为UUID的大量数据 ================*/
DROP TABLE IF EXISTS test_table_uuid;
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
    ON test_table_uuid_2 (id);

ALTER TABLE test_table_uuid
    ADD row_num INT NULL;

CREATE UNIQUE INDEX test_table_uuid_row_num_uindex
    ON test_table_uuid_2 (row_num);

/* ================ 存储过程 ================= */
CREATE PROCEDURE proc_insertFooData()
BEGIN
    DECLARE count INT DEFAULT 0;
    loop_label: LOOP
        IF count > 1000 * 1000 THEN
            LEAVE loop_label;
            ELSE
                INSERT INTO test_table(column_2, column_3, column_4, column_5, column_6, column_7, column_8, column_9)
                VALUES ('中文2', '中文3', '中文4', '中文5', '中文6', '中文7', '中文8', '中文9');
                SET count = count + 1;
        END IF;
    END LOOP;
END;

# UUID(),中文2,中文3,中文4,中文5,中文6,中文7,中文8,中文9
# 在insert中使用函数果然很慢，每秒平均插入量在一万左右，一百万数据插入花费两分钟
DROP PROCEDURE IF EXISTS procedure_insert_foo_data;
DELIMITER %
CREATE PROCEDURE procedure_insert_foo_data()
BEGIN
    DECLARE loop_index INTEGER DEFAULT 0;
    DECLARE max_row_num INT DEFAULT 0;
    loop_label: LOOP
        IF loop_index >= 100000 THEN
            LEAVE loop_label ;
        END IF;
        SELECT MAX(row_num) INTO max_row_num FROM test_table_uuid;
        INSERT INTO test_table_uuid (id, column_2, column_3, column_4, column_5, column_6, column_7, column_8, column_9,
                                     row_num)
        VALUES (UUID(), '中文2', '中文3', '中文4', '中文5', '中文6', '中文7', '中文8', '中文9', max_row_num + 1);
        SET loop_index = loop_index + 1;
    END LOOP loop_label;
END %
DELIMITER ;

/*---------------- 插入测试数据 ----------------*/
# windows平台mariadb居然花了20秒..每秒才五万插入
CALL proc_insertFooData;

# windows 10万主键UUID写入，花费两分钟
# 相比之前的一万数据写入要花费40s，已经提升很大，但还是很慢，mac上写入百万只需要两分钟
# 会不会是mysql底层使用系统调用来生成UUID，然后mac系统的UUID生成算法非常高效？
# 但这也无法解释win平台无UUID直插也很慢，会不会是mac巨大的内存带宽的影响？但这只应影响传输速度
# 如果是带宽差距乘上UUID生成算法上的差距，win比mac插入慢上十倍是有可能的
# mac insert不调用任何函数耗时：12s
# mac insert时加入调用get_max_row_num计算最大行数，耗时：12s
# mac insert时加入调用预置函数max()计算最大行数，耗时：11.584s，其实差不多
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

/* ---------------- 解决使用UUID插入数据非常慢的问题 ----------------- */
SELECT *
FROM test_table_uuid;
# 查看一下存储引擎，看是不是存储引擎的问题
SHOW CREATE TABLE test_table_uuid;
# 会不会是UUID()函数执行太慢了？但是在mac上也用了这个函数，也是mariadb，速度就很快
# 只是在mac上执行快而已，不是函数的问题
SELECT UUID();

SELECT RAND() * 100;

SELECT *
FROM test_table;

SELECT COUNT(*)
FROM test_table_uuid;

SHOW CREATE TABLE test_table_uuid;

/* ================ 使用mysqlslap进行基准性能测试 ================= */
# 创建测试表
CREATE TABLE people
(
    id   INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NULL,
    age  INT         NULL
);

SELECT *
FROM test_table_uuid_2
LIMIT 10;

SHOW TABLES;

SHOW CREATE TABLE test_table_uuid_2;

/*================ 更新自增列的存储过程 ================*/
DROP PROCEDURE IF EXISTS update_row_num;
DELIMITER %
CREATE PROCEDURE update_row_num()
BEGIN
    DECLARE row_index INT DEFAULT 0; # 行索引
    DECLARE no_more INT DEFAULT 0;
    DECLARE uuid VARCHAR(36) DEFAULT '';
    DECLARE my_cursor CURSOR FOR SELECT id FROM test_table_uuid WHERE row_num IS NULL; # 游标循环每一行数据
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more = 1;
    OPEN my_cursor;
    SELECT get_max_row_num() + 1 INTO row_index;
    loop_label: LOOP
        FETCH my_cursor INTO uuid;
        IF no_more THEN
            LEAVE loop_label;
        END IF;
        UPDATE test_table_uuid SET row_num = row_index WHERE id = uuid;
        SET row_index = row_index + 1;
    END LOOP loop_label;
    CLOSE my_cursor;
END
%
DELIMITER ;

# 140s完成百万数据更新
# 12.451s完成十万数据更新
CALL update_row_num();

/*---------------- 新增数据 ----------------*/
# 读取数字索引列中最大的数字
SELECT row_num
FROM test_table_uuid
ORDER BY row_num DESC
LIMIT 1;
# 读取最大索引列数字的函数
DROP FUNCTION IF EXISTS get_max_row_num;
DELIMITER %
CREATE FUNCTION get_max_row_num() RETURNS INT
BEGIN
    DECLARE max_row_num INT DEFAULT 0;
    SELECT row_num
    INTO max_row_num
    FROM test_table_uuid
    ORDER BY row_num DESC
    LIMIT 1;
    RETURN (max_row_num);
END %
DELIMITER ;