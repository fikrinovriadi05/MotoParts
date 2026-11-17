-- Skema database MotoPart (MySQL 5.7+ / MariaDB 10.3+).
-- Dijalankan oleh `php tool/setup.php` (atau impor lewat phpMyAdmin setelah
-- membuat database `motopart` dengan collation utf8mb4_unicode_ci).

CREATE TABLE IF NOT EXISTS users (
  id                 VARCHAR(32)  NOT NULL,
  name               VARCHAR(120) NOT NULL,
  email              VARCHAR(190) NOT NULL,
  phone              VARCHAR(40)  NOT NULL,
  role               ENUM('user','admin') NOT NULL DEFAULT 'user',
  password_hash      VARCHAR(255) NOT NULL,
  motor_name         VARCHAR(120) NOT NULL DEFAULT '',
  motor_type         VARCHAR(120) NOT NULL DEFAULT '',
  motor_year         SMALLINT     NULL,
  preferred_payment  VARCHAR(60)  NULL,
  default_address_id VARCHAR(32)  NULL,
  created_at         DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sessions (
  token      CHAR(64)    NOT NULL,
  user_id    VARCHAR(32) NOT NULL,
  expires_at DATETIME    NOT NULL,
  created_at DATETIME    NOT NULL,
  PRIMARY KEY (token),
  KEY idx_sessions_user (user_id),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS addresses (
  id          VARCHAR(32)   NOT NULL,
  user_id     VARCHAR(32)   NOT NULL,
  label       VARCHAR(60)   NOT NULL,
  recipient   VARCHAR(120)  NOT NULL,
  phone       VARCHAR(40)   NOT NULL,
  street      VARCHAR(255)  NOT NULL,
  city        VARCHAR(120)  NOT NULL,
  postal_code VARCHAR(5)    NOT NULL DEFAULT '',
  note        VARCHAR(255)  NOT NULL DEFAULT '',
  latitude    DECIMAL(9,6)  NULL,
  longitude   DECIMAL(9,6)  NULL,
  created_at  DATETIME      NOT NULL,
  PRIMARY KEY (id),
  KEY idx_addresses_user (user_id),
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS products (
  id          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name        VARCHAR(160)  NOT NULL,
  category    VARCHAR(60)   NOT NULL,
  type        VARCHAR(255)  NOT NULL DEFAULT 'Universal',
  price       INT UNSIGNED  NOT NULL,
  stock       INT UNSIGNED  NOT NULL DEFAULT 0,
  icon        VARCHAR(30)   NOT NULL DEFAULT 'build',
  description TEXT          NOT NULL,
  image_path  MEDIUMTEXT    NULL,
  created_at  DATETIME      NOT NULL,
  updated_at  DATETIME      NOT NULL,
  PRIMARY KEY (id),
  KEY idx_products_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS categories (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name       VARCHAR(40)  NOT NULL,
  icon       VARCHAR(30)  NOT NULL DEFAULT 'build',
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS orders (
  code           VARCHAR(40)  NOT NULL,
  user_id        VARCHAR(32)  NULL,
  customer       VARCHAR(120) NOT NULL,
  total          INT UNSIGNED NOT NULL,
  status         VARCHAR(30)  NOT NULL,
  address        TEXT         NULL,
  payment_method VARCHAR(60)  NULL,
  payment_json   MEDIUMTEXT   NULL,
  created_at     DATETIME     NOT NULL,
  updated_at     DATETIME     NOT NULL,
  PRIMARY KEY (code),
  KEY idx_orders_user (user_id),
  KEY idx_orders_status (status),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tanpa foreign key ke products: baris pesanan tetap ada walau produknya dihapus.
CREATE TABLE IF NOT EXISTS order_items (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_code VARCHAR(40)  NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  name       VARCHAR(160) NOT NULL,
  qty        INT UNSIGNED NOT NULL,
  price      INT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY idx_items_order (order_code),
  CONSTRAINT fk_items_order FOREIGN KEY (order_code) REFERENCES orders (code) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reviews (
  product_id  INT UNSIGNED  NOT NULL,
  user_id     VARCHAR(32)   NOT NULL,
  author_name VARCHAR(120)  NOT NULL,
  rating      TINYINT UNSIGNED NOT NULL,
  comment     VARCHAR(300)  NOT NULL DEFAULT '',
  created_at  DATETIME      NOT NULL,
  PRIMARY KEY (product_id, user_id),
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
  CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS wishlists (
  user_id    VARCHAR(32)  NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  created_at DATETIME     NOT NULL,
  PRIMARY KEY (user_id, product_id),
  CONSTRAINT fk_wishlists_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_wishlists_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
