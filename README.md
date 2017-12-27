# Evercam Server [![Build Status][travis-image]][travis-url]

Evercam Server is the component that is responsible for talking  to the camera. Consider it as a "proxy" for all commands. Processes here request either snapshots or streams and then send them to storage, or to any of the clients (e.g. Evercam-Dashboard, Evercam-Android, Evercam-iOS).

| Name   | Evercam Server  |
| --- | --- |
| Owner   | [@azharmalik3](https://github.com/azharmalik3)   |
| Version  | 1.0 |
| Evercam API Version  | 1.0  |
| Licence | [AGPL](https://tldrlegal.com/license/gnu-affero-general-public-license-v3-%28agpl-3.0%29) |

## Features

* Request snapshots from cameras
* Request rtsp stream from cameras
* Convert rtsp stream to rtmp / hls
* store snapshots

## Come on in, the water's warm :)

To setup the development environment follow the instructions at: [evercam-devops](https://github.com/evercam/evercam-devops)

The Evercam codebase is open source, see details: https://evercam.io/blog/evercam-goes-open-source/

Documentation about Evercam can be found here: https://github.com/evercam/evercam-media/wiki

Any questions or suggestions, drop us a line: https://evercam.io/contact

[travis-url]: https://travis-ci.org/evercam/evercam-server
[travis-image]: https://travis-ci.org/evercam/evercam-server.svg?branch=master
