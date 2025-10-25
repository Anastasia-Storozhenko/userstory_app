CREATE TABLE IF NOT EXISTS projects (
  id BIGINT NOT NULL AUTO_INCREMENT,
  description VARCHAR(255),
  name VARCHAR(255),
  PRIMARY KEY (id)
);
INSERT INTO projects (name, description) VALUES ('Test Project', 'Description') ON DUPLICATE KEY UPDATE name=name;