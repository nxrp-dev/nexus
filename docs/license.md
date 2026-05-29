# License

The target license for Nexus source code is the Mozilla Public License 2.0.

MPL 2.0 is a practical fit for Nexus because it protects the project source without trying to take over everything built with it. It is a file-level open-source license: changes to MPL-covered source files stay under the MPL, while larger works can combine those files with code under other terms.

The official license text controls:

- [Mozilla Public License 2.0](https://www.mozilla.org/MPL/2.0/)

## What That Means For Nexus

The intent is straightforward:

- Nexus source code remains open under MPL 2.0.
- Fixes and modifications to MPL-covered Nexus source files should remain available under MPL 2.0 when distributed.
- Applications, generated output, schemas, templates, assets, and project code built with Nexus do not become MPL-covered merely because they use Nexus tools.
- Third-party dependencies keep their own licenses.

That balance matters. Nexus is meant to be useful in real Pascal shops, including commercial shops, without turning every application built with it into an open-source licensing problem.

## Generated Output

NexusSchema and other Nexus tools may generate source files, database scripts, configuration files, or project artifacts.

Generated output belongs to the project that generated it unless a template, source file, or project policy says otherwise. Using a Nexus generator should not, by itself, impose the Nexus source license on the generated files.

## Third-Party Code And Libraries

Nexus uses and interoperates with external tools and libraries such as Free Pascal, Lazarus, VS Code, SDL2, Mustache-related rendering support, and SQLite-backed storage.

Those projects are not relicensed by Nexus. Their own license terms remain in effect. See [Attribution](attribution.md) for the current high-level dependency and influence map.

## License Notices

The preferred source notice is the standard MPL 2.0 source notice:

```text
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
https://mozilla.org/MPL/2.0/.
```

## Practical Summary

Use Nexus. Build applications with it. Generate files with it. Study it. Fork it if you need a different direction.

If you distribute modified Nexus source files, keep those modified files under MPL 2.0 and preserve the required notices.
