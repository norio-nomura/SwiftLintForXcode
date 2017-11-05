# SwiftLint for Xcode
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

SwiftLint for Xcode is a Xcode Extension that was created to run [SwiftLint](https://github.com/realm/SwiftLint).

## Requirements
- Xcode 9.1
- [SwiftLint](https://github.com/realm/SwiftLint)

## Install

1. Install Xcode 9.1
2. If you are using OS X 10.11, running `sudo /usr/libexec/xpccachectl` and rebooting are required for using Xcode Extension.
3. Clone this repository.
4. Open `SwiftLintForXcode.xcodeproj` double clicking on it.
5. Configure signing with your own developer ID on all three targets (SwiftLintForXcode, SwiftLint and SwiftLintHelper).
6. Quit Xcode.
7. Open a terminal, change to the directory where you cloned and run `xcodebuild -scheme SwiftLintForXcode install DSTROOT=~` to compile the extension.
8. Run `~/Applications/SwiftLintForXcode.app` and quit.
9. Go to System Preferences -> Extensions -> Xcode Source Editor and enable the extension.
10. Open Xcode and the extension should be found in Editor -> SwiftLint.

## Author

Norio Nomura

## License

SwiftLint for Xcode is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
