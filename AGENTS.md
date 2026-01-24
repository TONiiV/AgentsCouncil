# AGENTS SOP (OpenCode CLI)

## Purpose
This SOP defines how to develop in AgentsCouncil with OpenCode CLI. It standardizes branching, testing, and PR completion so changes stay isolated, test-driven, and verifiable across backend and frontend work.

## Repo orientation
- Backend: `backend/` (FastAPI server)
- Frontend: `frontend/` (Flutter app)
- Docs: `docs/`

## Work size and branching rules
Use this decision rule to choose your workspace strategy:

- **Small feature**: single area, limited risk, 1-2 days of work. Edit on a local branch in the main repo.
- **Big feature**: multi-area changes, cross-service impact, or longer effort. Use a git worktree.

If unsure, treat it as **big** and use a worktree.

**Worktree pattern** (big feature):
- Branch name: `feature/<short-topic>`
- Worktree dir: `../AgentsCouncil-<short-topic>`

## Test-driven development (mandatory)
Always follow TDD:
1. Write a failing test for the behavior.
2. Implement the smallest change to pass it.
3. Refactor while keeping tests green.

Tests must be executed before PR creation and again before completion.

## Development checklist
Use this for both backend and frontend tasks:

1. Decide work size (small vs big) and choose branch or worktree.
2. Write a failing test first.
3. Implement and refactor until tests pass.
4. Run focused tests for the touched area.
5. Run broader tests if the change is cross-cutting.

**Backend tests**
- Primary: `pytest`

**Frontend tests**
- Primary: `flutter test`

## PR wrap-up (required)
1. Ensure all tests pass locally.
2. Push the branch and open a PR.
3. Use GitHub MCP to check the PR status checks for the head commit.
4. Only mark work complete if all checks are passing.

## Hygiene
- Keep changes scoped to one topic per branch/worktree.
- Do not commit secrets or `.env` files.
- Avoid amending commits unless explicitly requested.
