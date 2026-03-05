ALTER TABLE pipeline_definitions ADD COLUMN executor TEXT NOT NULL DEFAULT '{"kind":"local"}';
