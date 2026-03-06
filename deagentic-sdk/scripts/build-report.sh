#!/bin/bash

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║          SDK BUILD REPORT                          ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Package info
echo "📦 PACKAGE INFO:"
PKG_NAME=$(node -p "require('./package.json').name")
PKG_VERSION=$(node -p "require('./package.json').version")
echo "   Name: $PKG_NAME"
echo "   Version: $PKG_VERSION"
echo ""

# TypeScript compilation
echo "🔨 COMPILATION:"
if [ -d "dist" ]; then
  JS_FILES=$(find dist -name "*.js" 2>/dev/null | wc -l)
  DTS_FILES=$(find dist -name "*.d.ts" 2>/dev/null | wc -l)
  DIST_SIZE=$(du -sh dist 2>/dev/null | cut -f1)
  
  echo "   ✅ Compiled successfully"
  echo "   JavaScript files: $JS_FILES"
  echo "   Type declarations: $DTS_FILES"
  echo "   Total size: $DIST_SIZE"
else
  echo "   ❌ No dist/ directory found"
fi
echo ""

# Source code
echo "📝 SOURCE CODE:"
TS_FILES=$(find src -name "*.ts" 2>/dev/null | wc -l)
TS_LINES=$(find src -name "*.ts" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
echo "   TypeScript files: $TS_FILES"
echo "   Lines of code: ~$TS_LINES"
echo ""

# Tests
echo "🧪 TESTS:"
TEST_FILES=$(find test -name "*.test.ts" 2>/dev/null | wc -l)
echo "   Test files: $TEST_FILES"
echo ""

# Final status
echo "═══════════════════════════════════════════════════"
if [ -d "dist" ] && [ $JS_FILES -gt 0 ]; then
  echo "✅ BUILD SUCCESSFUL"
else
  echo "❌ BUILD INCOMPLETE"
fi
echo "═══════════════════════════════════════════════════"
