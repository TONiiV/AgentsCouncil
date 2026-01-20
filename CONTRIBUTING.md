# Contributing to AgentsCouncil

Thank you for your interest in contributing to AgentsCouncil! This document provides guidelines and best practices for contributing to the project.

## Getting Started

1. **Fork the repository** and clone your fork locally
2. **Set up the development environment** (see README.md)
3. **Create a feature branch** from `main`

## Development Workflow

### Branch Naming

Use descriptive branch names:

- `feature/add-new-provider` - New features
- `fix/debate-timeout-error` - Bug fixes
- `refactor/simplify-debate-engine` - Code improvements
- `docs/api-documentation` - Documentation updates
- `test/add-provider-tests` - Test additions

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat(backend): add Gemini provider support
fix(frontend): resolve WebSocket reconnection issue
docs(api): update debate endpoint documentation
test(providers): add unit tests for OpenAI provider
```

## Code Standards

### Python (Backend)

- **Python 3.11+** required
- Use **type hints** for all function signatures
- Write **docstrings** for public functions and classes
- Run linting before committing:
  ```bash
  cd backend
  ruff check app/
  black app/
  ```

### Dart (Frontend)

- **Flutter 3.x** required
- Use **const constructors** where possible
- Prefer **Riverpod** for state management
- Run analysis before committing:
  ```bash
  cd frontend
  flutter analyze
  ```

## Testing

### Backend Tests

```bash
cd backend
source venv/bin/activate
pytest tests/ -v
```

### Frontend Tests

```bash
cd frontend
flutter test
```

### Requirements

- All new features must include tests
- All bug fixes should include a regression test
- Maintain or improve code coverage

## Pull Request Process

1. **Update documentation** if adding new features
2. **Add tests** for your changes
3. **Run all tests** locally before submitting
4. **Create a clear PR description** explaining:
   - What the change does
   - Why it's needed
   - How it was tested
5. **Request review** from maintainers

## Code Review Checklist

- [ ] Code follows project style guidelines
- [ ] Tests pass locally
- [ ] New code has appropriate test coverage
- [ ] Documentation is updated if needed
- [ ] No hardcoded secrets or API keys
- [ ] Error handling is appropriate
- [ ] Type hints are present (Python)
- [ ] Const constructors used where possible (Dart)

## Questions?

Open an issue for any questions or concerns about contributing.
