#!/bin/bash
# Install git hooks for DelamainNetworking

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook: Run SwiftLint on staged files

if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"
    exit 0
fi

# Get staged Swift files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$")

if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

echo "🔍 Running SwiftLint..."

# Run SwiftLint on staged files
echo "$STAGED_FILES" | xargs swiftlint lint --quiet --strict

RESULT=$?

if [ $RESULT -ne 0 ]; then
    echo ""
    echo "❌ SwiftLint found issues. Please fix them before committing."
    echo "   Run 'swiftlint lint' to see all issues."
    echo "   Run 'swiftlint --fix' to auto-fix some issues."
    exit 1
fi

echo "✅ SwiftLint passed"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Git hooks installed successfully!"
echo "   Pre-commit hook will run SwiftLint on staged Swift files."
