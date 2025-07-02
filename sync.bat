@echo off
setlocal enabledelayedexpansion

:: This script maintains a media-focused Git repository with only a single commit.
:: It stages all local changes (including deletions), overwrites the previous commit,
:: and force-pushes it to GitHub. It also ensures the local repository is kept in sync
:: with the latest remote state, even if no local changes are detected.
::
::   - Minimizes upload bandwidth by reusing existing Git blobs
::   - Remove commit history (always keep just one commit)
::   - Handle additions, modifications, and deletions efficiently

:: === CONFIGURATION ===
set REPO_NAME=test-media
set GITHUB_USERNAME=Kisara-k

:: === SET VALUES ===
set REMOTE_URL=https://github.com/%GITHUB_USERNAME%/%REPO_NAME%.git
set BRANCH=main
set COMMIT_MESSAGE=Media snapshot: %date% %time%

:: === Initialize if not a git repo ===
if not exist ".git" (
    echo [INIT] Initializing new repository...
    git init
    git remote add origin %REMOTE_URL%
)

:: === Ensure we're on the correct branch ===
echo.
echo [SYNC] Checking out %BRANCH%...
git checkout %BRANCH% 2>nul || git checkout -b %BRANCH%

:: === Fetch latest from remote ===
echo [FETCH] Fetching latest from %REMOTE_URL%...
git fetch origin %BRANCH%

:: === Reset local branch to remote if needed ===
echo [SYNC] Resetting local branch to match remote...
git reset --soft origin/%BRANCH%

:: === Stage all local changes ===
echo [ADD] Staging new/modified/deleted files...
git add -A

:: === Check if there are changes to commit ===
git diff --cached --quiet
if %errorlevel%==0 (
    echo [OK] No changes to commit...
    :: Check if remote is ahead
    git status -uno | findstr /C:"Your branch is behind" >nul
    if %errorlevel%==0 (
        echo [PULL] Fast-forwarding to remote...
        git reset --hard origin/%BRANCH%
    ) else (
        echo [DONE] Local branch is up-to-date with remote.
    )
    goto :eof
)

:: === Commit changes ===
git rev-parse --verify HEAD >nul 2>&1
if %errorlevel%==0 (
    echo [COMMIT] Amending previous commit...
    git commit --amend -m "%COMMIT_MESSAGE%"
) else (
    echo [COMMIT] Creating initial commit...
    git commit -m "%COMMIT_MESSAGE%"
)

:: === Push and overwrite remote ===
echo [PUSH] Force pushing to %REMOTE_URL%...
git push --force-with-lease origin %BRANCH%

echo [DONE] Commit synced to remote.
