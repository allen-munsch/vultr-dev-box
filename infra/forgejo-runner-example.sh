cd yep
mkdir -p .forgejo/workflows
# Copy the test.yml into .forgejo/workflows/test.yml

# Or create it directly:
mkdir -p .forgejo/workflows
cat > .forgejo/workflows/test.yml << 'EOF'
name: Test Runner

on:
  push:
    branches: [main, master]
  pull_request:
  workflow_dispatch:

jobs:
  test:
    runs-on: docker
    steps:
      - name: Hello
        run: echo "Hello from Forgejo Actions!"
      
      - name: System Info
        run: |
          uname -a
          whoami
          pwd
      
      - name: Checkout repo
        uses: actions/checkout@v4
      
      - name: List files
        run: ls -la
      
      - name: Done
        run: echo "✅ Runner is working!"
EOF

git add .forgejo/
git commit -m "Add CI workflow"
git push
