CREATE DATABASE IF NOT EXISTS userstory;
USE userstory;
CREATE TABLE IF NOT EXISTS projects (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255),
    description VARCHAR(255),
    PRIMARY KEY (id)
);
INSERT IGNORE INTO projects (name, description) VALUES ('Test Project', 'Description');
SELECT 'Data inserted successfully' AS message, (SELECT COUNT(*) FROM projects) AS project_count;