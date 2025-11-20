# Docker Setup for Expense Tracker

## Important Note

This iOS app **cannot run in Docker** as it requires:
- macOS operating system
- Xcode development environment
- iOS Simulator or physical iOS device

However, this Docker Compose setup provides useful **development tools** for code quality, documentation, and CI/CD purposes.

## Available Services

### 1. SwiftLint (Code Quality)

Run SwiftLint to check code quality:

```bash
docker-compose run --rm swiftlint
```

Or use the lint profile:

```bash
docker-compose --profile lint run swiftlint
```

### 2. Code Statistics

Get code statistics:

```bash
docker-compose --profile stats run code-stats
```

Or use the stats profile:

```bash
docker-compose --profile stats run code-stats
```

### 3. Development Helper

Get help information:

```bash
docker-compose run --rm dev-helper
```

## Prerequisites

- Docker Desktop installed on your machine
- Docker Compose (usually included with Docker Desktop)

## Usage Examples

### Check Code Quality

```bash
# Run SwiftLint
docker-compose run --rm swiftlint
```

### Get Project Statistics

```bash
# Get code statistics
docker-compose --profile stats run code-stats
```

### View All Available Commands

```bash
# Show help
docker-compose run --rm dev-helper
```

## Limitations

- **Cannot build iOS apps** - Requires Xcode on macOS
- **Cannot run iOS simulators** - Requires macOS
- **Cannot test the app** - Requires iOS environment

## Why Docker?

While Docker can't run iOS apps, it's useful for:
- ✅ Code quality checks (SwiftLint)
- ✅ Automated CI/CD pipelines
- ✅ Code statistics and analysis
- ✅ Consistent development tooling across team

## Building and Running the App

To actually build and run this app, you still need:

1. **macOS** (macOS 11.0 or later)
2. **Xcode** (11.4 or later)
3. Open `ExpenseTracker.xcodeproj` in Xcode
4. Build and Run (⌘R)

See the main [README.md](README.md) for full development instructions.

