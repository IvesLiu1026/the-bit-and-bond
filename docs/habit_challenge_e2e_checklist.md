# The Bit and Bond Habit Challenge E2E Checklist

## Scope
This checklist validates the family habit loop end-to-end:

1. Parent creates habit challenge
2. Child submits proof (photo/note)
3. Parent reviews (approve/reject)
4. XP/coins/streak/progress update correctly

## Test Environment
- Client: iOS Simulator (recommended: 390x844 and 844x390)
- Server running on `http://127.0.0.1:18080`
- Demo data can be prepared with `./scripts/seed_demo_accounts.sh`
- Database seeded with at least:
  - 1 guild master account
  - 1 member account (assigned target)
  - Optional 2nd member for assignment guard tests

## Accounts
- Parent (guild master): can create/review habits
- Child (member): can submit proof

## A. Parent Creates Habit
1. Login as parent.
2. Open `選單 -> Habits`.
3. Create a new habit with:
   - title
   - cadence (`Daily` or `Weekly`)
   - assign to child
4. Expected:
   - Habit card appears in Active Habits.
   - Child can see assigned habit.

## B. Child Submits Proof
1. Login as child.
2. Open `選單 -> Habits`.
3. For a `Pending` or `Missed` habit, tap:
   - `提交完成證明` (pending) or
   - `補交完成證明` (missed)
4. In proof dialog:
   - verify both `拍照` and `從相簿選擇` actions exist.
   - attach photo OR enter note.
   - tap `送審`.
5. Expected:
   - Submit success snackbar appears.
   - Habit moves to review state (`待審`).
   - Dialog closes on success; remains open on failure.

## C. Parent Reviews
1. Login as parent.
2. Open `選單 -> Habits`.
3. In `待審核證明`, verify newest submissions appear first.
4. Tap `核准` for one habit.
5. Expected (approve):
   - Habit returns to `Available` if category is habit.
   - `streak_count`, `best_streak`, `completions_count` update.
   - Child XP/coins increase.
6. Tap `退回` for another habit.
7. Expected (reject):
   - No XP/coins reward granted.
   - Habit returns to `Available`.
   - Review note updates.

## D. Assignment Guard
1. Have a habit assigned to Child A.
2. Login as Child B (same guild).
3. Try submitting Child A's assigned habit.
4. Expected:
   - Request is rejected with forbidden behavior.
   - Habit status remains `Available`.

## E. Session / Error UX
1. Let auth token expire (or simulate 401/403).
2. Trigger habit submit or review action.
3. Expected:
   - User sees friendly message: session expired / re-login required.
   - Client logs out cleanly (no repeated red error spam).

## F. Media/Upload Stability
1. Submit proof with:
   - JPG
   - PNG
   - HEIC (if available)
2. Expected:
   - Upload accepted (<=8MB).
   - No `Broken pipe` regression on retry path.

## G. Regression Gates
Before merge, run:

```bash
cd apps/client_flutter
flutter analyze
flutter test

cd ../server
cargo test
```

## Pass Criteria
- All sections A-G pass.
- No overflow/render exceptions in phone portrait/landscape.
- No unauthorized loop / repeated 401 error spam.
