# Week 1

## Pull the updated `UVM_Training` and keep your local changes in `introduction`

Run from the root of your cloned repository:

```bash
git stash
git pull origin main
git stash pop
```

Or, to pull only the `UVM_Training` folder:

```bash
git fetch origin
git checkout origin/main -- UVM_Training
```
