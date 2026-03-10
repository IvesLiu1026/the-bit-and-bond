-- Seed data aligned with default Flutter dart-defines.

INSERT INTO households (id, name, created_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'Bit & Bond Family', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO members (id, household_id, display_name, role, created_at)
VALUES
  ('00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000001', 'Mom Guardian', 'guardian', NOW()),
  ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', 'Kid Hero', 'child', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO characters (id, child_member_id, level, xp, coins, updated_at)
VALUES ('10000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000011', 1, 0, 0, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_templates (id, household_id, title, description, category, base_xp, base_coins, active, created_at)
VALUES
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Clean Desk', 'Organize desk and wipe surface.', 'chore', 20, 10, TRUE, NOW()),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Math Practice', 'Complete 15 math problems.', 'study', 30, 15, TRUE, NOW()),
  ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Spelling Review', 'Review 20 spelling words.', 'exam', 25, 12, TRUE, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_instances (id, template_id, assignee_member_id, status, due_at, created_at, updated_at)
VALUES
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000011', 'available', NOW() + INTERVAL '1 day', NOW(), NOW()),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000011', 'available', NOW() + INTERVAL '1 day', NOW(), NOW()),
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000011', 'rejected', NOW() + INTERVAL '1 day', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;
