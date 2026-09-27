<p align="center">
  <img src="Resources/AppIcon.png" width="160" alt="HiddenBar">
</p>

<h1 align="center">HiddenBar</h1>

<p align="center">Hide menu bar icons in one click. Native Swift, works on macOS 27.</p>

## Install

```sh
brew install --cask noahsmo/tap/hiddenbar
```

Or download the zip from [Releases](https://github.com/NoahSmo/HiddenBar/releases) and move `HiddenBar.app` to `/Applications`.

## Usage

- <kbd>⌘</kbd>-drag icons to the left of the `|` separator to hide them.
- Click the chevron to show / hide them.
- Right-click the chevron for *Launch at login* and *Quit*.

Keep the app in `/Applications`: macOS 27 remembers icon positions per app location.

## Build

```sh
./build.sh            # build, install to /Applications, launch
./build.sh --release  # build zip + sha256 for a release
```

Requires Xcode 15+, macOS 13+.

## License

[MIT](LICENSE)
