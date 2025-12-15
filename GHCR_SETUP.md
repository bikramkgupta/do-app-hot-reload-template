# Making GHCR Packages Public

After the GitHub Actions workflow builds and pushes your Docker images to GitHub Container Registry (GHCR), you need to manually make them public and link them to this repository.

## Step 1: Access Your Packages

1. Go to your GitHub profile: https://github.com/bikramkgupta
2. Click on **"Packages"** in the top navigation
3. You should see all the hot-reload images that were pushed:
   - `hot-reload-node`
   - `hot-reload-python`
   - `hot-reload-go`
   - `hot-reload-ruby`
   - `hot-reload-node-python`
   - `hot-reload-full`

## Step 2: Make Each Package Public

For **each** package, follow these steps:

1. Click on the package name
2. Click **"Package settings"** (on the right sidebar)
3. Scroll down to the **"Danger Zone"** section
4. Find **"Change package visibility"**
5. Click **"Change visibility"**
6. Select **"Public"**
7. Type the package name to confirm
8. Click **"I understand the consequences, change package visibility"**

## Step 3: Link Package to Repository

While in the package settings:

1. Scroll to **"Connect repository"** section
2. Click **"Connect repository"**
3. Search for and select: `bikramkgupta/do-app-hot-reload-template`
4. Click **"Connect"**

This will:
- Display the package on your repository's main page
- Show the package in the repository's "Packages" section
- Make it easier for users to discover

## Step 4: Verify

After making the changes:

1. Visit your repository: https://github.com/bikramkgupta/do-app-hot-reload-template
2. The packages should appear on the right sidebar under "Packages"
3. Anyone can now pull these images without authentication:
   ```bash
   docker pull ghcr.io/bikramkgupta/hot-reload-node:latest
   ```

## Quick Links

Direct links to your packages (after they're published):

- https://github.com/bikramkgupta/packages/container/hot-reload-node
- https://github.com/bikramkgupta/packages/container/hot-reload-python
- https://github.com/bikramkgupta/packages/container/hot-reload-go
- https://github.com/bikramkgupta/packages/container/hot-reload-ruby
- https://github.com/bikramkgupta/packages/container/hot-reload-node-python
- https://github.com/bikramkgupta/packages/container/hot-reload-full

## Troubleshooting

**Can't see the packages?**
- Wait a few minutes after the workflow completes
- Check https://github.com/bikramkgupta?tab=packages
- Ensure the workflow completed successfully

**Packages still private after changing visibility?**
- Refresh the page
- Clear browser cache
- Try accessing in incognito mode

**Need to automate this?**
Unfortunately, GitHub doesn't support setting GHCR package visibility via workflow actions. You must manually make each package public once after the first push.
