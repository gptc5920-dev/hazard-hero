PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS "user_accounts" (
  "id" TEXT NOT NULL,
  "email" TEXT NOT NULL UNIQUE,
  "display_name" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "password_hash" TEXT NOT NULL,
  "password_salt" TEXT NOT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)),
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "auth_session_rows" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)),
  "created_at" INTEGER NOT NULL,
  "last_authenticated_at" INTEGER NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "resource_rows" (
  "id" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "metadata_json" TEXT NOT NULL DEFAULT '{}',
  "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)),
  "version" INTEGER NOT NULL DEFAULT 1,
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  "deleted_at" INTEGER NULL,
  "sync_state" TEXT NOT NULL DEFAULT 'pending',
  "image_url" TEXT NULL,
  "video_url" TEXT NULL,
  "reference_url" TEXT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "sync_outbox" (
  "id" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "entity_type" TEXT NOT NULL,
  "operation" TEXT NOT NULL,
  "payload_json" TEXT NOT NULL,
  "created_at" INTEGER NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "last_error" TEXT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "app_key_values" (
  "key" TEXT NOT NULL,
  "value" TEXT NOT NULL,
  PRIMARY KEY ("key")
);
