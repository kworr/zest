# Zest config management tool

Zest is a simple config management tool written in BSD make. It follows the
UNIX philosophy: no templating engine, minimal dependencies, plain files,
and `make` doing the work of deciding what needs to change.

## Why Zest?

After working with SaltStack, Ansible, and Puppet, I found them overly complex
with unnecessary server/client architectures, UI layers, and steep learning
curves. Zest takes a different approach:

- **Minimal overhead**: no servers, agents, or complex infrastructure
- **Fast execution**: built on BSD make (see the benchmark below)
- **No templating**: plain configuration files — what you see is what you get
- **Flexible distribution**: you decide how to distribute configs and when to run
- **Easy to extend**: simple modular design based on familiar Makefile syntax
- **UNIX-way**: leverage existing tools and keep it simple

## Performance

```
# time make
0.000u 0.079s 0:00.01 700.0%    43+40k 0+0io 0pf+0w
```

Zest checks that every managed file is present and matches the source in your
config tree. That is exactly what `make` was designed to do.

## Requirements

- BSD make (`bmake`). Zest uses `.MAIN`, `.ORDER`, `.USE`, `:U`, and other
  BSD-specific features; GNU make is not supported.
- FreeBSD or Linux.

## Installation

1. Clone or download Zest to a known location, e.g. `/usr/local/share/zest`.
2. Generate a `Makefile` for your config tree:

```
make -C /usr/local/share/zest > /path/to/config/Makefile
```

The generated file contains an absolute include path, so regenerate it if
you move Zest.

## Quick start

Take a look at `example/`. Its modules are illustrations of layout and
selector usage; the tree is not a complete working configuration and
`example/Makefile` intentionally errors.

### Top-level files

- **`_default.mk`** — modules enabled under `root`:
  ```make
  SUBDIR+= sshd nginx postgres
  ```
- **`_config.mk`** — local overrides for `_config.mk` defaults:
  ```make
  FILE_MODE?=     644
  FILE_OWNER?=    root
  FILE_GROUP?=    wheel
  DIR_MODE?=      755
  DIR_OWNER?=     root
  DIR_GROUP?=     wheel
  ```
- **`_<hostname>.mk`** — extra `root` modules for one host (`hostname -s`):
  ```make
  # _web01.mk
  SUBDIR+= nginx newsyslog
  ```
- **`@<tag>.mk`** — extra `root` modules for a tag (see [Selectors](#selectors)):
  ```make
  # @web.mk
  SUBDIR+= nginx
  ```
- **`Mk/`** — local module overrides or new modules; anything here takes
  precedence over the same-named file shipped with Zest.

### Applying configuration

```
make
```

To test one module, or a list of modules:

```
make nginx newsyslog
```

A targeted run only builds what that module depends on. In particular, only
directories that the module (or its service target) lists are created; the
rest of `NEW_DIRS` is built by a plain `make` through `.MAIN`.

## Selectors

Zest supports host and tag selectors. For a file named `<name>` in module
`<module>`, the first existing variant wins:

1. `<module>/<hostname>/<name>` — host-specific
2. `<module>/@<tag>/<name>` — for each tag that applies to this host, in
   declaration order
3. `<module>/<name>` — base variant

`<hostname>` is `hostname -s` and may contain only letters, digits, and `-`.

Tags are declared in the root `_default.mk`:

```make
TAGS:= \
    web=web01,web02 \
    db=db01
```

Format: `tag=host[,host...]`. The host list is comma-separated with no
spaces. `MYTAGS` receives every tag whose list contains this host.

Targeted runs, such as `make nginx`, do not read the root `_default.mk`.
`MYTAGS` stays empty for these runs. Tag-specific module snippets are not
loaded, and tag file variants may not be selected.

Module configuration snippets follow the same pattern:

- `<module>/_default.mk` — settings for all hosts
- `<module>/_<hostname>.mk` — settings for this host
- `<module>/@<tag>.mk` — settings for a tag

They are plain make snippets loaded before `<module>.mk`, so they can set
variables used by the module (e.g. `NGINX_SITES`, `USER_FILES`).

## Files and permissions

A module installs files by setting `FILES` (and usually `DEST`) and including
`_copy_files.mk`:

```make
CYRUS_ETC?= /usr/local/etc
CYRUS_FILES+= imapd.conf cyrus.conf

NEW_DIRS+=  ${CYRUS_ETC}
FILES:=     ${CYRUS_FILES}
DEST:=      ${CYRUS_ETC}
.include "${ZEST}/_copy_files.mk"
```

- With `DEST` set, each entry in `FILES` is installed to `${DEST}/<path>`.
- Without `DEST`, each entry is a full destination path and its basename is
  used to find the source in the module directory.

Each `FILES` entry may carry permissions:

```
path[=mode[:owner[:group]]]
```

Examples:

```make
FILES:= nginx.conf=644 \
        private.key=600:root:wheel \
        helper.sh=755
```

Omitted trailing fields inherit `FILE_MODE`, `FILE_OWNER`, `FILE_GROUP`
(defaults: `644`, empty, empty). The mode must be explicit when you specify
owner or group; an empty leading field (`=:root:wheel`) is not supported.
Paths cannot contain `=`.

`_copy_files.mk` looks up the source using the selector order above, emits the
install rule (through the `_text_file` helper), and adds an `.ORDER` edge from
the destination directory to the file. It does **not** create directories:
declare them in `NEW_DIRS`.

### Directories

```make
NEW_DIRS+= /usr/local/etc/nginx
NEW_DIRS+= ${MY_ETC}=750:root:wheel
```

Syntax is `path[=mode[:owner[:group]]]`, with `DIR_MODE`, `DIR_OWNER`, and
`DIR_GROUP` as defaults (default mode `755`).

Every destination directory must be declared. A plain `make` creates all of
them; a targeted `make <module>` creates only the ones that module depends on,
so list them on the module target:

```make
nginx: ${SERVICE_NGINX} ${NGINX_DIRS}
```

Directory attributes are re-applied on every run: the directory rule is
forced, so `install -d` (re-)sets the declared mode/owner/group even on
existing directories. `install -d` also creates missing parents (and does
not touch an existing parent's mode), so an undeclared intermediate
directory keeps default attrs — declare every directory whose attrs matter.
On FreeBSD, non-root runs add `install -U`, which skips chown and directory
chmod, so directory attrs only converge for root there.

### Install behavior

- `install -C` is used: identical content leaves the destination and its mtime
  untouched; changed content gets a new mtime; a mode-only change is applied
  without changing the mtime.
- Service restarts are based on mtimes, so content changes restart services
  while chmod/chown-only changes do not.
- `_text_file`, `_link_file`, and the directory rule add a forced
  `last.update` prerequisite, so every managed path is checked on every run.
  `-C` prevents unnecessary writes.

## Services

Services are declared in `<module>.var.mk`, which is loaded before the module
implementation:

```make
# nginx.var.mk
SERVICES+=  nginx:_nginx_reload
SUBDIR+=    service
```

- The name before the first `:` is the service name passed to `service(1)`.
- `restart`, `reload`, `stop`, etc. are run as `service <name> <command>`.
- A command starting with `_` names a `.USE` macro in the module instead of a
  `service(1)` argument. The macro's commands are attached to the marker.
- The declaration creates `SERVICE_<NAME>` (uppercase; hyphens are allowed),
  which expands to the marker path `${.OBJDIR}/<name>.service`.

The service macro:

```make
_nginx_reload: .USE
	nginx -t && nginx -s reload
```

Wire it into the module target:

```make
nginx: ${SERVICE_NGINX} ${NGINX_DIRS} clean_stale
${SERVICE_NGINX}: ${NGINX_FILES}
```

The marker's mtime suppresses repeat restarts. The plain `service ...`
commands run before the marker is touched, so a failed command is retried;
`_`-macros run after the marker, so keep them idempotent.

`systemd.mk` provides a tuple-based alternative for Linux:

```
SYSTEMD_SERVICES+= name:restart=module:/etc/systemd/system/x.service,/other/file
```

## Module types

### Standard modules

Manage files within their own directory. Examples: `sshd`, `nginx`,
`postgres`, `postfix`.

### Cross-dependent modules

Operate on files from other services and are configured through global
variables in `*.var.mk`: `syslog`, `newsyslog`.

For a service's logs to be configured properly, both the service module
(e.g. `nginx`) and the log module (e.g. `newsyslog`) must be enabled:

```make
# _default.mk
SUBDIR+= nginx newsyslog
```

## Available modules

|Module|Purpose|
|---|---|
|user|User home directory configurations (`.bashrc`, `.cshrc`, etc.)|
|sshd|SSH daemon configuration|
|nginx|Nginx web server|
|postgres|PostgreSQL database|
|postfix|Postfix mail server|
|cyrus|Cyrus IMAP server|
|named|BIND DNS server|
|dhcpd|ISC DHCP server|
|dhcpcd|DHCP client daemon|
|syslog|System logging configuration|
|newsyslog|Log rotation|
|cron|Cron jobs|
|opendkim|OpenDKIM mail signing|
|node_exporter|Prometheus node exporter|
|prometheus|Prometheus monitoring|
|spamd|SpamD configuration|
|podman|Podman containers|
|transmission|Transmission daemon|
|systemd|systemd service handling (Linux)|
|etc|General `/etc` configuration files|

## Extending Zest

1. Create `<module>.mk` in the Zest directory, or `Mk/<module>.mk` in your
   config tree to override it locally.
2. Create `<module>.var.mk` for cross-module declarations (`SERVICES+=`,
   `SUBDIR+= service`, shared `*_FILES` lists).
3. Declare destination directories in `NEW_DIRS`.
4. Wire the graph top-down: module target → service marker → files.
5. Enable the module in `_default.mk`, `_<hostname>.mk`, or `@<tag>.mk`.

A current example is `cyrus.mk`:

```make
CYRUS_ETC?= /usr/local/etc

CYRUS_FILES+= imapd.conf cyrus.conf

cyrus: ${SERVICE_IMAPD}

${SERVICE_IMAPD}: ${CYRUS_FILES:%=${CYRUS_ETC}/%}

NEW_DIRS+=  ${CYRUS_ETC}
FILES:=     ${CYRUS_FILES}
DEST:=      ${CYRUS_ETC}
.include "${ZEST}/_copy_files.mk"
```

and `cyrus.var.mk`:

```make
SYSLOG_FILES+=     cyrus/news.syslog
NEWSYSLOG_FILES+=  cyrus/news.newsyslog
SERVICES+=         imapd:restart
SUBDIR+=           service
```

What happens:

1. The module declares its destination directory and file list.
2. The module target (`cyrus`, matching the module name) depends on the
   service marker.
3. The marker depends on the installed files.
4. `_copy_files.mk` looks up each source variant (host, tags, base), emits
   install rules, and adds `.ORDER` from the destination directory to each
   file.
5. The service marker is compared against the installed files by mtime, so
   `imapd` restarts only when configuration content actually changed.

Use `?=` for user-tunable paths and `+=` for accumulating lists. Remember
that `+=` defers expansion: inside `.for` loops accumulate with
`X:= ${X} ${loop_var}` instead.

## Limitations and future improvements

- **No templating.** Configuration files are copied verbatim; per-host or
  per-tag differences are expressed with selector directories, not variables
  inside files.
- **Directory attributes need privilege.** Directory attrs are re-applied
  every run, but on non-root FreeBSD runs `install -U` skips chown and
  directory chmod, so they only take effect for root there.
- **Targeted runs need explicit directory dependencies.** `make nginx` only
  creates directories named on `nginx`'s target (or its prerequisites); a
  plain `make` creates all declared ones.
- **Documentation.** Module-specific documentation is still being developed;
  the module sources are the reference.
