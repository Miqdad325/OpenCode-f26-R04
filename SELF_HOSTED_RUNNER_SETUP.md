# Fixing the GitHub Actions VM SSH Timeout

This repo's workflow failed because GitHub-hosted runners cannot reach the CMU VM from outside the CMU network.

The failing job showed this error:

```text
dial tcp ***:22: i/o timeout
```

That means the runner attempted to connect to port 22 on your VM but the network blocked the connection.

## Why this happens

Your VM is behind CMU network restrictions. The GitHub-hosted runner is running on a public GitHub-hosted machine, and it is not allowed to connect to your CMU VM over SSH.

Because of that, this workflow will fail every time:

```yaml
- name: Create test file on VM
  uses: appleboy/ssh-action@v1.2.1
  with:
    host: ${{ secrets.SERVER_IP }}
    username: ${{ secrets.SERVER_ADMIN }}
    password: ${{ secrets.ADMIN_PASSWORD }}
```

The problem is not your script. The problem is the network path.

---

# Recommended Fix: Use a Self-Hosted GitHub Runner

The best solution is to run GitHub Actions on a machine that is inside the CMU network.

That machine can be:

- your CMU VM itself, or
- another machine reachable from inside CMU.

Once the runner is running inside CMU, the workflow does not need to SSH from the public GitHub runner.

---

## Step 1: Add a self-hosted runner in GitHub

Go to your repository and do this:

1. Open GitHub
2. Go to your repository
3. Click Settings
4. Click Actions
5. Click Runners
6. Click Add runner
7. Pick Linux and follow the instructions GitHub gives you

GitHub will provide commands like these:

```bash
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.303.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.303.0/actions-runner-linux-x64-2.303.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.303.0.tar.gz
```

Then configure the runner using the URL and token GitHub gives you:

```bash
./config.sh --url https://github.com/Miqdad325/OpenCode-f26-R04 --token <TOKEN_FROM_GITHUB>
```

Then install it as a service:

```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

If your runner is running on the CMU VM itself, this is the correct solution.

---

## Step 2: Replace the workflow

Your current workflow file is:

```yaml
name: Test VM SSH and File Creation

on:
  workflow_dispatch:

jobs:
  test-ssh:
    runs-on: ubuntu-latest

    steps:
      - name: Create test file on VM
        uses: appleboy/ssh-action@v1.2.1
        with:
          host: ${{ secrets.SERVER_IP }}
          username: ${{ secrets.SERVER_ADMIN }}
          password: ${{ secrets.ADMIN_PASSWORD }}
          debug: true
          script: |
            set -ex
            cd "$HOME/OpenCode-f26-R04"
            printf 'hello\n' > github.log
            echo "File created at: $(pwd)/github.log"
            cat github.log
```

This is the wrong architecture for your network setup.

Use a self-hosted runner instead.

### New workflow

Create or replace `.github/workflows/test-vm-file.yml` with this:

```yaml
name: Test VM local file creation

on:
  workflow_dispatch:

jobs:
  test-local:
    runs-on: [self-hosted, linux, cmu]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create test file on runner/VM
        run: |
          set -euxo pipefail
          cd "$GITHUB_WORKSPACE"
          printf 'hello\n' > github.log
          echo "File created at: $(pwd)/github.log"
          cat github.log
```

This works because the job is running on the runner machine inside CMU, not on GitHub’s public infrastructure.

---

## Step 3: If the runner is on the same VM, use local commands

If the self-hosted runner is installed directly on the CMU VM, then you do not even need to SSH.

You can just do:

```bash
cd "$HOME/OpenCode-f26-R04"
printf 'hello\n' > github.log
cat github.log
```

That is simpler and more reliable than SSHing from GitHub.

---

## Step 4: Optional: push the generated file back to GitHub

If you specifically want GitHub Actions to create a file on the runner and store it in the repo, use this pattern:

```yaml
name: Test VM local file creation

on:
  workflow_dispatch:

jobs:
  test-local:
    runs-on: [self-hosted, linux, cmu]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create test file
        run: |
          set -euxo pipefail
          printf 'hello\n' > github.log
          echo "File created at: $(pwd)/github.log"
          cat github.log

      - name: Commit generated file
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add github.log
          git commit -m "Add generated test file" || echo "No changes to commit"
          git push
```

---

## Important: Why not keep using SSH?

This would only work if the GitHub runner could reach your VM over the network.

Your VM is inside CMU, and GitHub-hosted runners are outside CMU. The firewall blocks the connection.

That is exactly why this line failed:

```text
 dial tcp ***:22: i/o timeout
```

The fix is not to change the port or password. The fix is to move the action runner into the CMU network.

---

# Troubleshooting Checklist

Use this list if something still fails.

## 1. Check that the self-hosted runner is online

In GitHub:

- Settings
- Actions
- Runners

Make sure the runner is shown as online.

## 2. Check the runner is inside CMU network

On the machine where the runner is installed, run:

```bash
hostname
whoami
uname -a
```

If this machine is the CMU VM, then it has the required network access.

## 3. Verify the runner is connected to GitHub

On the runner machine, check the service status:

```bash
sudo ./svc.sh status
```

If needed, restart:

```bash
sudo ./svc.sh restart
```

## 4. Check repository workspace path

If you use `cd "$HOME/OpenCode-f26-R04"`, make sure that directory exists on the runner.

Check:

```bash
ls -la "$HOME"
ls -la "$HOME/OpenCode-f26-R04"
```

If not, use the GitHub workspace path instead:

```bash
cd "$GITHUB_WORKSPACE"
```

---

# Final Recommendation

Use a self-hosted GitHub Action runner installed inside CMU, and do not rely on SSH from GitHub-hosted runners.

This is the correct design for your environment.

If you want the simplest option:

- install the self-hosted runner on the CMU VM itself
- remove the SSH step
- run the file creation locally in the workflow

That will work reliably.

---

# Summary

- The failure is a networking issue, not a script issue
- CMU firewall blocks connections from outside CMU
- GitHub-hosted runners cannot connect to your VM over SSH
- The fix is a self-hosted runner inside CMU
- Replace the SSH workflow with a local workflow on the runner

---

# Example final workflow

```yaml
name: Test VM local file creation

on:
  workflow_dispatch:

jobs:
  test-local:
    runs-on: [self-hosted, linux, cmu]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create test file
        run: |
          set -euxo pipefail
          cd "$GITHUB_WORKSPACE"
          printf 'hello\n' > github.log
          echo "File created at: $(pwd)/github.log"
          cat github.log
```

This is the most direct and reliable solution for your setup.
