##### Deprecated

Podman Desktop has been released and can be downloaded from [https://podman-desktop.io/](https://podman-desktop.io/).

----

# Podman for macOS

<img align="left" src="https://heyvito.github.io/podman-macos/Podman-Screenshot.png" width="250">

![](https://img.shields.io/badge/-Electron--free-blue) ![](https://img.shields.io/badge/license-MIT-blue)


"Podman for macOS" is a macOS frontend for [Podman](https://github.com/containers/podman). It can be
used to start and stop both the Podman Machine and its running containers. In case a Podman Machine
is not yet setup, the application can provision and start it automatically. Additionally, users may
set it to automatically start and bring the machine up during login.

> ⚠️ **Heads up!** Support to Apple M1 is under development.

<br /><br />

## Installing

1. Install [Podman](https://github.com/containers/podman) through [Homebrew](https://brew.sh):
    ```
    brew install podman
    ```
2. Download a [Precompiled Binary](https://github.com/heyvito/podman-macos/releases), or clone this repo and
build it.
3. Move the application to your Application's folder
4. Launch it.

## Contributing
Contributions are welcome! Feel free to send a Pull-Request, or file an issue in case you run into
any problem.

## TODO

- [x] Provide Notarized binaries
- [ ] Add support to Apple M1

## Acknowledgements

- Thanks [@ofeefo](https://github.com/ofeefo) for tips regarding UI ♥️
- Thanks [@RLMD](https://github.com/RLMD) for creating the Menu Bar icon ♥️

## License

```
The MIT License (MIT)

Copyright (c) 2021 Victor Gama

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
