CREATE DATABASE IF NOT EXISTS userstory;
USE userstory;
CREATE TABLE IF NOT EXISTS projects (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255),
    description VARCHAR(255),
    PRIMARY KEY (id)
);
INSERT INTO projects (name, description) VALUES ('Test Project', 'Description');
SELECT 'Data inserted successfully' AS message;