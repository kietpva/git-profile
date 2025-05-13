## Documentation

- [Documentation](#documentation)
- [Install](#install)
- [Re-install](#re-install)
- [Upgrade](#upgrade)

## Install

```
brew tap kietpva/gittools
brew install gitprofile
```

## Re-install

```
brew uninstall gitprofile
brew untap kietpva/gittools
rm -f ~/Library/Caches/Homebrew/downloads/*git-profile*
brew tap kietpva/gittools
brew install gitprofile
gitprofile version
```

## Upgrade

```
git tag v1.0.1 -d
git tag v1.0.1
git push origin
git push origin v1.0.1 -f
```