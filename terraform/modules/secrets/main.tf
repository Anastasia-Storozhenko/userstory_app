# Используем random провайдер для генерации сложного пароля
resource "random_password" "db_password" {
  length           = var.db_password_length
  special          = true
  override_special = "!#$%&*()_-+="
  upper            = true
  lower            = true
  numeric          = true
}

# Создаем сам секрет в AWS Secrets Manager
data "aws_secretsmanager_secret" "db_secret" {
  name        = var.secret_name
  #description = "Credentials for the UserStory database."
  #lifecycle {
  #  prevent_destroy = true                  # не даст удалить
  #  ignore_changes  = [name, description]   # не будет пытаться обновлять
  #}
}

# Записываем сгенерированные учетные данные в секрет в формате JSON
data "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id

  # Создаем JSON-строку для хранения всех учетных данных
  #secret_string = jsonencode({
  #  username = var.db_username
  #  password = random_password.db_password.result
  #  # Мы добавим hostname позже, когда у нас будет приватный IP DB-инстанса
  #  # hostname = "..." 
  #})
}