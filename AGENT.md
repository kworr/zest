# AGENT.md — Zest working notes

Zest is a configuration-management tool written entirely in BSD make
(`bmake`). A user keeps a *config tree* (their modules + plain config
files); a generated `Makefile` includes `_zest.mk` from this repository.
There is no templating: files are copied verbatim with `install(1)`, and
`make`'s dependency graph is used as the "what changed?" engine.

This document records how the thing is put together, which bmake
behaviours it relies on, and the traps found while adding per-file and
per-directory `mode:owner:group` support.

- Verified on FreeBSD, `MAKE_VERSION 20251111`, against Fossil checkout
  `79a51e66` (2026-11-17). Line numbers will drift; re-read the files
  before trusting them.
- Requires BSD make semantics. It is **not** GNU make compatible (uses
  `!=` instead of `$(shell)`, plus `.MAIN`, `.ORDER`, `:U`, `.for` text
  substitution, etc.).
- Do not commit unless explicitly asked.

## Rules of thumb (read these first)

1. **A directory must never be a prerequisite of a file target.** Use
   `.ORDER: dir file` (order-only). A real dependency on a directory
   causes deadlocks in parallel mode, installs the directory as the
   payload, and makes files permanently out of date. See
   [Directories as dependencies](#directories-as-dependencies-the-big-trap).
2. The **first prerequisite** of a `_text_file` / `_link_file` target
   must be the real payload. `${>:[1]}` is the first element of
   `.ALLSRC`, not "the first out-of-date source".
3. **Never assign to a `.for` loop variable.** bmake substitutes loop
   variables textually as `${:Uvalue}`; an assignment to the same name
   creates a global variable and changes nothing. Use a fresh name.
   The one exception is deliberately propagating the loop value to
   `.include`d files (`MOD:= ${MOD}` in `_zest.mk`): the substitution
   makes the assignment `${MOD:= ${:U<value>}}`, so it does set the
   global that includes will see.
4. **`+=` does not expand its right-hand side.** It appends the raw text,
   and `${...}` in it is expanded when the variable is *read*. Static
   lists are fine, but this is wrong inside a loop when you append an
   *ordinary* variable: `V:= ${loopvar}; ACC+= ${V}` stores the literal
   `${V}`, and every entry reads the final `V`. Appending the loop
   variable directly (`ACC+= ${loopvar}`) is safe because bmake first
   substitutes it to a self-contained `${:Uvalue}`. When in doubt,
   accumulate immediately: `ACC:= ${ACC} ${V}`. See
   [Deferred `+=`](#deferred--is-not-expanded).
5. `:S` and `:C` replace only the **first** occurrence in each word
   unless the `g` flag is appended (`:C|:| |g`).
6. Every destination directory must be declared in `NEW_DIRS`. A plain
   `make` builds them through `.MAIN`; a targeted `make <module>` only
   builds the ones that module (or its service target) depends on, so
   wire them explicitly. `_copy_files.mk` only emits `.ORDER`; it never
   creates directories.
7. `install -C` does **not** touch the target's mtime when the content is
   unchanged. Service restarts depend on that mtime, so identical
   content never restarts a service.
8. `.USE` / `.USEBEFORE` are **command-and-source templates, not graph
   nodes**. A target that names a template as a source inherits that
   template's commands and sources (one level: the inheritance is not
   passed on again to *its* dependents). `.USE` appends the template's
   commands after the target's own commands; `.USEBEFORE` prepends them.
   They do not order targets and the template itself is never built.
   See [Special targets and operators](#special-targets-and-operators).
9. Do not run `example/` — its `Makefile` intentionally errors and its
   modules are illustrations, not working configs.

## Repository and workflow

- Useful commands: `fossil status`, `fossil diff`, `fossil timeline -n 30`,
  `fossil diff --from <rev> --to <rev>`.
- Licence: 0BSD (`LICENSE.0BSD`). Contributions also go through Fossil;
  GitHub is only a mirror.
- The `Makefile` in the repository root is not a build system. It prints
  a small Makefile for a user's config tree:

  ```sh
  make -C /usr/local/share/zest > /path/to/config/Makefile
  ```

  The generated line contains an absolute path to `_zest.mk`, so
  regenerate it if Zest moves.
- `obj.${USER}` directories are created inside config trees (not in this
  repository). They are runtime state; delete them freely.

## File map

| File | Role |
|---|---|
| `_zest.mk` | Engine: config loading, module pipeline, `NEW_DIRS`, `.MAIN`, cleanup |
| `_config.mk` | Defaults (`FILE_MODE`, `DIR_MODE`, `INSTALL`), OS/user detection |
| `_copy_files.mk` | Generates install rules from `FILES`/`DEST`/`MOD` |
| `service.mk` | Turns `SERVICES` entries into service marker targets |
| `systemd.mk` | Alternative systemd service handling (`SYSTEMD_SERVICES`) |
| `<module>.mk` | Built-in module implementation |
| `<module>.var.mk` | Cross-module declarations (services, shared file lists) |
| `README.md` | User-facing docs (module list, selectors, extending) |
| `example/` | Illustrative config tree; intentionally non-functional |

## How a run is assembled

`_zest.mk` is parsed top to bottom. The order matters.

1. **Locate the engine.** `ZEST:= ${.PARSEDIR}` (the directory of
   `_zest.mk`). Everything later refers to `${ZEST}/<file>`.
2. **Load defaults + local overrides.** Include `${ZEST}/_config.mk`,
   later `.sinclude "${.CURDIR}/_config.mk"` for the config tree. The
   local file is optional and can override `FILE_MODE`, `DIR_MODE`,
   `INSTALL`, module knobs, etc.
3. **Validate host and mode.** `MYHOST != hostname -s`; only
   `[a-zA-Z0-9-]` is accepted (despite the error text mentioning FQDN,
   dots are *not* allowed). `compat` mode is rejected. `.MAKE.JOBS` is
   set in `_config.mk` from `nproc` / `sysctl -n hw.ncpu`; the `?=1`
   later in `_zest.mk` is a fallback that never applies on a supported
   OS.
4. **Create the object dir.** `MAKEOBJDIR:= ${.CURDIR}/obj.${USER}`,
   pre-created with `!=` only when it is missing (`.if
   !exists(${MAKEOBJDIR})`). Then `.OBJDIR:` changes the working
   directory. Recipes execute in the object dir; `.CURDIR` stays the
   config-tree root.
5. **Force marker.** `LAST_UPDATE:= ${.OBJDIR}/last.update` is defined
   with the `!` operator (`${LAST_UPDATE}!`), so it is re-created on
   every run. `_text_file`, `_link_file`, and `_make_dir` inherit it as
   an appended prerequisite, which makes their recipes run every time
   (see [Install semantics](#install-semantics-and-mtime)). In
   particular, directory attributes are re-applied on every run.
6. **Seed `SUBDIR`.**
   - `make <names...>`: `SUBDIR+= ${.TARGETS}` — explicit make goals are
     treated as module names.
   - plain `make`: `SUBDIR+= user` (the per-user dotfiles module).
7. **Root-only global config** (only when `USER` is `root` *and* no
   explicit goals):
   - `NEW_DIRS+= ${NEWSYSLOG_DIR} ${SYSLOG_DIR}`;
   - include `${.CURDIR}/_default.mk` (default module list);
   - parse `TAGS` into `MYTAGS` for this host;
   - include `${.CURDIR}/_${MYHOST}.mk` and each `${.CURDIR}/@${TAG}.mk`.
8. **First module pass**: for each module in `${UNORDERED_SUBDIR:O:u}`
   (sorted, deduplicated):
   - include `Mk/<mod>.var.mk` if present, else `${ZEST}/<mod>.var.mk`;
   - include optional config-tree files `<mod>/_default.mk`,
     `<mod>/_${MYHOST}.mk`, `<mod>/@${TAG}.mk`;
   - append the module to `SUBDIR`.
9. **Second module pass**: iterate `SUBDIR` in the order produced above;
   skip duplicates (`INCLUDED`); include `Mk/<mod>.mk` (config-tree
   override) else `${ZEST}/<mod>.mk`; append loaded names to `TARGETS`;
   warn (do not fail) for unknown modules.
10. **`NEW_DIRS` pass**: process `${NEW_DIRS:O:u}`, define a `_make_dir`
    target per deduplicated declaration, and accumulate `TARGET_DIRS`
    immediately (`TARGET_DIRS:= ${TARGET_DIRS} ${THIS}`). Reject the same
    path declared with conflicting attrs.
11. **Wire defaults and cleanup.** `.PHONY: ${TARGETS}` and
    `.MAIN: ${TARGETS} ${TARGET_DIRS}`. `clean_stale` removes
    `STALE_FILES` / `STALE_DIRS`; modules opt in by depending on it.

Consequences worth remembering:

- The second-pass order is **not** the order in `_default.mk`. It is
  emergent: sorted first-pass order plus any `SUBDIR+=` done by
  `.var.mk` files. The usual convention is that `service.mk` gets
  inserted before its consumers because every module using
  `SERVICES` adds `SUBDIR+= service` in its `.var.mk`. Do not rely on
  hand-written ordering; wire real dependencies.
- Modules added indirectly by a `.var.mk` file (e.g. `service`) do not
  get their own `.var.mk`/config-tree includes in the first pass. Keep
  such indirect additions to modules like `service` that do not need
  them.
- `.MAIN` only applies when no target was given. `make <module>` ignores
  it, so only directories reachable from that module's target are built
  in a targeted run.
- `TARGET_DIRS` must be accumulated with `:=` (immediate assignment),
  because `+=` would defer `${THIS}` to read time and `THIS` is undefined
  by then. See [Deferred `+=`](#deferred--is-not-expanded).

## Module layout

A config tree looks like this (all relative to `.CURDIR`, the config
tree root):

```
Makefile                    # generated: .include "/path/to/zest/_zest.mk"
_config.mk                  # optional local overrides
_default.mk                 # root default module list / TAGS
_web01.mk                   # root host-specific additions
@tag1.mk                    # root tag-specific additions
Mk/                         # local overrides, takes precedence over Zest
  nginx.mk                  # replaces ${ZEST}/nginx.mk entirely
  nginx.var.mk              # replaces ${ZEST}/nginx.var.mk entirely
  mymodule.mk               # new local module
nginx/                      # module data directory
  nginx.conf                # base variant
  @tag1/nginx.conf          # tag variant
  web01/nginx.conf          # host variant
  _default.mk               # module config (variables) for all hosts
  _web01.mk                 # module config for this host
  @tag1.mk                  # module config for this tag
user/
  .cshrc
  ...
```

Selector/source precedence for a file named `<name>` in module `<mod>`:

1. `<mod>/${MYHOST}/<name>` (host-specific)
2. `<mod>/@<tag>/<name>` for each tag in `MYTAGS`, in declaration order
3. `<mod>/<name>` (base)

The first path that exists wins. `MYHOST` comes from `hostname -s`;
`MYTAGS` is populated from lines in the root `_default.mk`:

```make
TAGS:= \
    tag1=host1,host2 \
    tag2=host1,host3
```

Format is `tag=host[,host...]`; the host list is comma-separated with no
spaces. Tags are matched with bmake's `:M` (glob), which is safe because
`MYHOST` is restricted to alphanumerics and `-`.

Module config files are plain make snippets loaded in the first pass, so
they can only sensibly set variables used later by `<mod>.mk` (e.g.
`NGINX_SITES`, `SSHD_ETC`, `PODMAN_CONTAINERS`). They are not part of the
module implementation.

## Key variables

| Variable | Meaning |
|---|---|
| `ZEST` | Directory containing `_zest.mk` |
| `MYHOST` | `hostname -s` (short host name) |
| `MYTAGS` | Tags that apply to this host |
| `USER` | `whoami`; `root` selects the privileged configuration branch |
| `OS` | `uname`; only `FreeBSD` and `Linux` are supported |
| `SUBDIR` / `UNORDERED_SUBDIR` | Module names collected from config |
| `TARGETS` | Modules actually loaded (Zest's own list; not bmake `.TARGETS`) |
| `TARGET_DIRS` | Directories declared via `NEW_DIRS` |
| `NEW_DIRS` | Directory declarations, `path[=mode[:owner[:group]]]` |
| `SERVICES` | `<name>:<cmd>[:<cmd>...]` service declarations |
| `SYSTEMD_SERVICES` | systemd tuple syntax (see `systemd.mk`) |
| `STALE_FILES` / `STALE_DIRS` | Obsolete paths removed by `clean_stale` |
| `NEWSYSLOG_FILES` / `NEWSYSLOG_DIR` | Cross-module newsyslog inputs / destination |
| `SYSLOG_FILES` / `SYSLOG_DIR` | Cross-module syslog inputs / destination |
| `PAM_DIR` | PAM directory (`/etc/pam.d`) |
| `FILE_MODE` / `FILE_OWNER` / `FILE_GROUP` | Defaults for installed files (`644`, empty, empty) |
| `DIR_MODE` / `DIR_OWNER` / `DIR_GROUP` | Defaults for created dirs (`755`, empty, empty) |
| `INSTALL` | `install -C`, plus `-U` on FreeBSD when not root |
| `LAST_UPDATE` | Forced-per-run marker in `.OBJDIR` |
| `MOD` | Current module name; set by the loader, sticky across `_copy_files.mk` |
| `FILES` / `DEST` | Inputs to `_copy_files.mk` |

`NEWSYSLOG_DIR` and `SYSLOG_DIR` are FreeBSD-specific and set to empty
on Linux. Do not enable `newsyslog`/`syslog` on Linux without providing
them, otherwise destinations expand to `/...`.

## Installing files: `FILES`, `DEST`, attributes

A module normally ends with:

```make
NEW_DIRS+=   ${MY_ETC}
FILES:=      my.conf other.conf
DEST:=       ${MY_ETC}
MOD:=        mymodule        # normally already set by the loader
.include "${ZEST}/_copy_files.mk"
```

`FILES` is a whitespace-separated list of specs:

```
path[=mode[:owner[:group]]]
```

- The first `=` separates path from attributes. Paths therefore cannot
  contain `=` (unsupported).
- Attributes are positional: `mode`, then `owner`, then `group`.
- Omitted **trailing** fields inherit `FILE_MODE`, `FILE_OWNER`,
  `FILE_GROUP`.
- Empty **leading** fields (`=:root:wheel` for "default mode, root
  owner") are still not representable: word splitting drops them, so
  `=:root:wheel` parses `root` as the mode and `wheel` as the owner.
  Trailing empties (`700:root:` / `700::wheel`) are fine because
  `:C|:| |g` keeps the cursor at the last field. See
  [Known issues and design traps](#known-issues-and-design-traps).
- No spaces inside a spec (bmake splits `FILES` on whitespace).
- With `DEST` unset, the destination is the file's own path: `FILES:=
  /etc/foo` installs to `/etc/foo` and uses the basename for source
  lookup. With `DEST` set, `FILES:= foo.conf` installs to
  `${DEST}/foo.conf` (a path inside `FILES` is kept: `sub/foo` →
  `${DEST}/sub/foo`; remember to declare `${DEST}/sub` too).

`_copy_files.mk` generates, per file:

```make
${THIS}: INST_MODE=<attr-or-empty> ${FILE_MODE}
${THIS}: INST_OWNER=<attr-or-empty> ${FILE_OWNER}
${THIS}: INST_GROUP=<attr-or-empty> ${FILE_GROUP}
${THIS}: <source> _text_file
.ORDER: <destdir> ${THIS}
```

`${THIS}` is the destination. The local variables are consumed by
`_text_file` as `${INST_MODE:[1]}` etc. This is a bmake idiom worth
remembering:

```make
VAR=   <value> <fallback>
${VAR:[1]}      # value when non-empty, otherwise the fallback word
```

It avoids `${VAR:U...}`, which does **not** fall back for a variable that
is defined but empty.

The macro can be included more than once per module (e.g.
`opendkim.mk`); it resets `FILES`, `DEST`, `FOUND`, `ITEM_LIST`,
`MYDEST`, `MYFILE`, `FILE_SPEC`, `THIS`, `FILE_ARGS`, but **not**
`MOD`. Set `MOD` again only when installing files that belong to a
different module (as `systemd.mk` does).

The loop variable is `FSPEC`; the parsed value goes into `FILE_SPEC`
(`FILE_SPEC:= ${FSPEC:C|=| |}`), and the attrs are split with
`:C|:| |g`. Never assign back to the loop variable — see
[.for is textual substitution](#for-is-textual-substitution).

Source lookup is done with parse-time `exists()` checks and produces a
hard error if no variant is found:

```
make: .../_copy_files.mk:45: No variants found for foo.conf in <tree>/<mod>
```

### Manual file rules

For one-off files, modules sometimes bypass `_copy_files.mk`:

```make
${MY_ETC}/foo.conf: mymodule/foo.conf _text_file
.ORDER: ${MY_ETC} ${MY_ETC}/foo.conf
```

Rules:

- The payload source must be **first**; `${>:[1]}` is `.ALLSRC:[1]`.
- Use `.ORDER` for the destination dir, never a real prerequisite.
- `INST_MODE`/`INST_OWNER`/`INST_GROUP` may be set target-locally. If
  they are not, `_text_file` falls back to
  `FILE_MODE`/`FILE_OWNER`/`FILE_GROUP` via `${INST_MODE:[1]:U${FILE_MODE}:...}`.
  Note the subtlety: `:U` fires only when the variable is entirely
  undefined. An explicit `INST_MODE=` target-local assignment defines it
  as *empty*, so `${INST_MODE:[1]:U644}` still yields empty and
  `install` uses its own default `0755`. Do not emit an empty local
  assignment unless you mean "no `-m`".
- Keep the rule next to its `.ORDER` so the ordering is obvious.

## Directories: `NEW_DIRS`

Every directory that Zest should create is declared explicitly, from any
module or config file:

```make
NEW_DIRS+=  /usr/local/etc/nginx /var/ca
NEW_DIRS+=  ${MY_ETC}=750:root:wheel
```

Directories are processed **after** module aggregation, so declarations
can happen anywhere. Syntax is `path[=mode[:owner[:group]]]`, with
`DIR_MODE`/`DIR_OWNER`/`DIR_GROUP` as defaults.

What the pass does (`_zest.mk`):

```make
.for DSPEC in ${NEW_DIRS:O:u}
    DIRSPEC:= ${DSPEC:C|=| |}
    THIS:= ${DIRSPEC:[1]}
    DIR_INST:= ${DIRSPEC:[2]:C|:| |g}
    TARGET_DIRS:= ${TARGET_DIRS} ${THIS}    # immediate, not +=
    ... define ${THIS}: INST_MODE=... _make_dir
.endfor
.undef _ZEST_SEEN_DIRS THIS DIRSPEC
```

and `.MAIN: ${TARGETS} ${TARGET_DIRS}`. Every declared directory is a
top-level goal on a plain `make`, and the `.ORDER` edges emitted by
`_copy_files.mk` (`dir` before `file`) are enforced because both nodes
are in the graph.

Properties and traps:

- `NEW_DIRS` is sorted and deduplicated by `:O:u`. Declaration order is
  lost; the order presented to make is lexicographic, not guaranteed
  under `-j`.
- The duplicate check runs over `${NEW_DIRS:O:u}`, i.e. **after**
  deduplication, so identical duplicates are silently merged. It *does*
  catch the same path declared with different attributes: `:O:u` keeps
  both strings (`path=700`, `path=755`) and the loop body compares the
  path part against previously seen paths and raises
  `duplicate dir <path>`.
- `_make_dir: .USEBEFORE ${LAST_UPDATE}` inherits the forced marker, so
  the rule runs on **every** invocation and `install -d -m/-o/-g`
  re-applies the declared attributes. The `if [ ! -d $@ ]` in the recipe
  only controls the "new dir" log line. Directories are therefore
  convergent, not create-only.
- `install -d` creates missing parents. Creating `/a/b` can pre-create a
  declared parent `/a` with default attrs, but `install -d` does not
  chmod an *existing* parent and the declared parent's rule is forced, so
  it is corrected in the same run. Only undeclared intermediate
  directories keep their default attrs.
- On FreeBSD non-root runs `INSTALL` contains `-U`; `install(1)` ignores
  owner, group and file flags and (see source) does **not** chmod
  directories in that mode. Directory modes/owners therefore take effect
  only for root on FreeBSD. (Linux does not add `-U`.)
- A targeted run (`make mymodule`) does not build `TARGET_DIRS` unless
  the module makes them reachable. Recommended shape (see `opendkim`
  for a full example):

  ```make
  mymodule: ${SERVICE_MYMODULE} ${MY_DIRS}   # dirs reachable ...
  ${SERVICE_MYMODULE}: ${MY_FILES}           # ... files installed by the service
  ```

  with `.ORDER: ${MY_DIRS} <each-file>` from `_copy_files.mk`. Do not
  put dirs in the *file* rule. Prefer putting them on the phony module
  target rather than on `${SERVICE_*}`, because a directory's mtime
  changes whenever an entry is added/removed and would then restart the
  service.

## Services and restart suppression

`<module>.var.mk` files declare services:

```make
# nginx.var.mk
SERVICES+=  nginx:_nginx_reload
SUBDIR+=    service
```

`service.mk` turns each declaration into a marker target:

```make
SERVICE_<NAME:tu>:=  ${.OBJDIR}/<name>.service
${SERVICE_<NAME:tu>}: _mark_command <underscore-commands>
        service <name> <command>        # for each non-underscore command
```

- `SERVICE_<NAME>` (uppercase) is the path variable modules depend on.
  Hyphens are legal in variable names (`SERVICE_MILTER-OPENDKIM`).
- `_mark_command` is a `.USE` macro whose command is `touch $@`; `$@`
  is the consumer marker, so a successful run records the marker's
  mtime.
- A command beginning with `_` is a reference to a `.USE` macro in the
  module (e.g. `_nginx_reload`), not something passed to `service(1)`.
  That macro's commands are attached to the marker target.
- Services restart only when a prerequisite's mtime is newer than the
  marker. `install -C` keeps the installed file's mtime when content is
  unchanged, so converged runs do not restart anything.

The standard graph is:

```
module target (phony)
  └── ${SERVICE_X} (marker file in .OBJDIR)
        └── installed files ── _text_file (prepended install recipe)
              └── LAST_UPDATE (forced every run)
```

Command order **within** the marker's recipe (`.USE` only appends or
prepends commands; it never orders targets):

1. the target's own commands — the plain `service <name> <cmd>` lines;
2. `_mark_command`'s `touch $@`, because `_mark_command` is a `.USE`
   source and `.USE` appends after the consumer's own commands, in source
   order;
3. any `_`-macro commands (`${SERVICE_CMDS:M_*}`), appended after
   `_mark_command`.

Because `_mark_command` is a `.USE` source, its `touch` lands *after*
the plain commands but *before* the `_`-macros. A failing plain
`service ...` command aborts before the marker is touched and is retried
on the next run; a failing `_`-macro runs after `touch`, leaves a fresh
marker, and is not retried until something else changes. Keep
`_`-macros idempotent, or move them before `_mark_command` if
retry-on-failure matters.

`systemd.mk` is a second, tuple-based mechanism:

```
SYSTEMD_SERVICES+= name:restart=module:/etc/systemd/system/x.service,/other/file
```

It sets `MOD` to the named module so `_copy_files.mk` can install files
owned by another module, and uses `${.OBJDIR}/systemd.reloaded` to run
`systemctl daemon-reload` once.

## Install semantics and mtime

`_config.mk` sets `INSTALL= install -C`; on FreeBSD as non-root it also
adds `-U` ("unprivileged": do not change owner/group/flags).

`_text_file` (a `.USEBEFORE` macro used as a source of the destination
target):

```make
if [ -f $@ ]; then diff -u $@ ${>:[1]} || true; else echo '# new file $@'; fi
install -C \
    ${INST_MODE:[1]:U${FILE_MODE}:@x@-m ${x}@} \
    ${INST_OWNER:[1]:U${FILE_OWNER}:@x@-o ${x}@} \
    ${INST_GROUP:[1]:U${FILE_GROUP}:@x@-g ${x}@} \
    ${>:[1]} $@
```

`_link_file` uses `install -lsa` (absolute symbolic link).

`_make_dir` (a `.USEBEFORE` macro with the same forced source):

```make
if [ ! -d $@ ]; then echo "# new dir $@"; fi
${INSTALL} -d \
    ${INST_MODE:[1]:U${DIR_MODE}:@x@-m ${x}@} \
    ${INST_OWNER:[1]:U${DIR_OWNER}:@x@-o ${x}@} \
    ${INST_GROUP:[1]:U${DIR_GROUP}:@x@-g ${x}@} \
    $@
```

Because it inherits `${LAST_UPDATE}`, every directory rule is out of date
on every run and the recipe (re-)applies mode/owner/group to existing
directories. The `if [ ! -d ]` only gates the log line.

- `LAST_UPDATE` is forced (`!`) on every invocation. Because
  `_text_file`, `_link_file` and `_make_dir` contribute it as an
  additional source, every managed file and directory recipe is
  considered out of date every run. This is deliberate: the config tree
  is the source of truth, so manual edits to the target
  must be overwritten even if the target has a newer mtime.
- `install -C` compares content:
  - identical content → **no mtime change** (and no ctime change if
    mode/flags also match);
  - different content → replace, new mtime;
  - same content but different mode → mode is applied **without**
    changing mtime.
- Service markers compare mtimes, so content changes trigger restarts,
  while chmod/chown-only changes do not.
- `-U` (non-root) skips owner, group and file flags for all installs.
  For directories it also skips `chmod` (the FreeBSD source has an
  explicit `if (!dounpriv)` around the directory chmod). Regular files
  are still chmodded even with `-U`.
- `install(1)` without `-m` defaults to `0755`; it does **not** preserve
  the source mode. `_copy_files.mk` and `NEW_DIRS` always inject the
  defaults, and `_text_file`/`_make_dir` fall back to
  `FILE_MODE`/`DIR_MODE` when `INST_MODE` is entirely undefined, so
  manual rules also get `0644`/`0755` rather than `install`'s `0755` for
  files. A defined-but-empty `INST_MODE=` still slips through and
  produces `-m ''`; see
  [Known issues and design traps](#known-issues-and-design-traps).
- mtime resolution is one second on this filesystem. Tests that touch a
  directory and a file in the same second can look "up to date" even
  though the order was wrong; `sleep 1` between steps when reproducing.

## bmake details that bit us

### Directories as dependencies (the big trap)

Making destination directories prerequisites of the installed files (as
some modules and the old `example/Mk/user.mk` still do) fails in several
independent ways:

1. **Parallel deadlock with `.ORDER`.** If `file` depends on `dir` *and*
   `dir` is the predecessor of `file` in `.ORDER`, bmake defers `file`
   because its order predecessor is unmade, and never schedules `dir`
   because `file` is the only node that can reach it. `.ORDER` does not
   add targets to the graph (man page: *"This ordering does not add
   targets to the list of targets to be made"*). The run ends with
   messages like:

   ```
   `.../dest' was not built (unmade, type OP_DEPENDS|...|OP_MARK,
   flags REMAKE|DONE_WAIT|DONECYCLE)!
   ```

   The man page documents exactly this:
   `.ORDER: b a` + `b: a` is a dependency loop unless `a` is reachable
   through another branch. A plain `make` has such a branch (every
   `NEW_DIRS` entry is a `.MAIN` goal); `make <module>` does not, unless
   the module target depends on the directory.
2. **The directory becomes the payload.** `${>}` is `.ALLSRC`, not
   `.OODATE`. If the dir is listed first (`file: dir src`), the recipe
   runs `install -C <dir> <file>` → `install: invalid file mode: <dir>`.
   Ordering the dir last avoids this particular symptom but not the
   next one.
3. **Permanent out-of-date state.** A directory's mtime changes whenever
   an entry is added or removed. Because `install -C` refuses to update
   a file whose content is unchanged, an installed file can never catch
   up to a dir that gained a sibling. The file recipe then runs forever.
   (`LAST_UPDATE` already runs it every time, but any timestamp consumer
   — service markers, custom rules — is exposed.)

Correct pattern: an order-only edge plus reachability.

```make
NEW_DIRS+= ${MY_ETC}
${MY_ETC}/foo.conf: module/foo.conf _text_file
.ORDER: ${MY_ETC} ${MY_ETC}/foo.conf
```

`dir` is built when it is a `.MAIN` goal (plain `make` lists every
`NEW_DIRS` entry there) or when the module/service target depends on it
(targeted `make`), and `.ORDER` keeps the sequence deterministic.

### `${>}` vs `${?}`

- `${>}` / `${.ALLSRC}` — all sources, in dependency order. This is what
  the install helpers use (`${>:[1]}`).
- `${?}` / `${.OODATE}` — only sources considered out of date.
- `.USEBEFORE`/`.USE` sources contribute their own sources to the
  consumer. `_text_file: .USEBEFORE ${LAST_UPDATE}` means every
  consumed target gets `${LAST_UPDATE}` appended to its `.ALLSRC`.
  Therefore the real payload must be the first declared prerequisite,
  and the source must never be an empty variable that expands to
  nothing (that would shift `${>:[1]}` to the wrong entry).

### `.for` is textual substitution

`.for VAR in ${LIST}` is not a runtime loop. bmake substitutes every
`${VAR}`/`${VAR:modifier}` in the body with `${:U<value>}` /
`${:U<value>:modifier}` before parsing it. Consequently:

```make
.for FILE_SPEC in ${FILES}
FILE_SPEC:= ${FILE_SPEC:C|=| |}    # NO-OP for this iteration
...
```

sets a *global* `FILE_SPEC`; the `${FILE_SPEC...}` occurrences later in
the body still expand to the substituted `${:Uvalue}`. Use a different
name:

```make
.for FILE_SPEC in ${FILES}
SPEC:= ${FILE_SPEC:C|=| |}
...
.endfor
```

To read the substituted value into a global, `${FILE_SPEC}` (without
modifiers) is fine; the assignment itself must be to another name.
When you need two-stage parsing, assign the raw loop value first, then
apply modifiers to the new variable.

The deliberate exception is propagating a loop value into `.include`d
files: `MOD:= ${MOD}` becomes `${MOD:= ${:U<value>}}`, so it *does* set
the global the included file will read. That is why `_zest.mk` uses
`MOD:= ${MOD}` rather than a fresh name.

### Deferred `+=` is not expanded

`+=` stores its right-hand side **unexpanded**; the `${...}` inside is
expanded when the variable is later read. `:=` expands immediately.
Verified: after `X:= a; L+= ${X}; X:= b`, `L` reads `b`, not `a`.

Inside `.for` there are two different cases, and only one is broken:

```make
ACC:=
.for x in a b c
ACC+= ${x}      # SAFE: bmake substitutes x -> ${:Ua}/${:Ub}/${:Uc}
.endfor         # result: " a b c"
```

```make
ACC:=
.for x in a b c
V:=   ${x}      # ordinary variable, overwritten each iteration
ACC+= ${V}      # stores the literal text ${V} ...
.endfor        # ... read after the loop -> " c c c"
```

The loop variable itself is substituted textually, so `${x}` becomes a
self-contained `${:U<value>}` before parsing and each appended word keeps
its own value. An *ordinary* variable assigned inside the loop does not:
`+=` stores `${V}` and all copies read the final value. Accumulate
immediately instead:

```make
ACC:= ${ACC} ${V}   # expands ${V} now
```

Rule: `+= ${loop_var}` is fine; `+= ${ordinary_var}` is deferred. Use
`:=` whenever the value must be captured at that point. This is why the
`NEW_DIRS` pass accumulates `TARGET_DIRS` with `:=`.

Colons inside a `.for` item are escaped by bmake when it builds the
`:U` expression, so `foo=600:root:wheel` passes through a loop intact.
Word splitting happens on whitespace, so do not rely on `:[n]` splitting
a colon-containing value before you have replaced colons with spaces.

### `:S` / `:C` need `g`

Both replace the **first** occurrence in each word by default. To split
`600:root:wheel` into three words:

```make
FILE_ARGS:= ${SPEC:[2]:C|:| |g}     # not :C|:| |
```

`systemd.mk` already uses `:S|:| |g`; follow that precedent.

### Conditionals and functions

- `exists()` is a real function; `exist()` is not. A bare `exist(...)`
  is treated as `.ifdef exist` (false), so `!exist(...)` is always true
  and any `mkdir -p` guarded by it runs on every invocation. Always write
  `exists()`. Likewise `empty(...)` is a function; other bare words in
  `.if` are `.ifdef`.
- Bare words in `.if` are evaluated like `.ifdef` (the "default
  function"), so a typo usually becomes a silently false condition, not
  an error.
- `empty(VAR:Mpattern)` / `:N` use bmake **glob** patterns, not regex.
  `:C`/`:S` are the regex/string tools.
- `!=` executes a shell command at parse time (not recipe time). This
  happens even with `make -n` / `make -V`, so dry runs are not
  side-effect-free.

### Special targets and operators

- `target!` (no colon) : always re-create the target. Used for
  `LAST_UPDATE`.
- `.MAIN:` : default goals, used only when no target is given.
- `.PHONY:` : targets are never files and are always out of date;
  module targets are phony so their prerequisites are checked each run.
- `.USE` : **command-and-source template, not a graph node.** A target
  that names it as a source inherits the template's commands and sources.
  `.USE` appends the template's commands *after* the target's own
  commands, in source order.
- `.USEBEFORE` : same inheritance, but the template's commands are
  *prepended* before the target's own commands (multiple
  `.USEBEFORE` sources prepend in reverse source order). The install
  helpers use this.
- Inheritance is **one level only**: if `obj: mac` and `mac: .USE`, then
  `obj` gets `mac`'s commands, but a later `top: obj` gets only `obj`'s
  own commands (plus any templates `top` names itself). Verified.
- Neither one affects target ordering. `.USE`/`.USEBEFORE` change
  *recipes and source lists*, not the graph order; if you need
  ordering, use `.ORDER` or `.WAIT`.
- `.WAIT` : in a dependency list, preceding siblings are made before
  following siblings; unlike `.ORDER` it participates in the graph as a
  barrier. `user: clean_stale .WAIT ${USER_FILES}` uses it to sequence
  deletion before installation in parallel mode.
- `.ORDER: a b c` : ordering only, a → b → c, no graph membership. If a
  predecessor is not otherwise reachable, the edge has no effect and the
  successor is built without it (this is why a targeted run does not
  create `NEW_DIRS`). See above.

Verified details of `.USE` inheritance:

- Sources are appended to the consumer's `.ALLSRC` *after* its own
  sources; `${>:[1]}` stays the first real prerequisite.
- Missing inherited sources are fatal (`don't know how to make ...`).
- A `.USE` command may use `$@`/`$>` and sees the consumer's values.
- Commands from `.USE` run after own commands; from `.USEBEFORE` before.
  Multiple `.USEBEFORE` sources run in reverse order; multiple `.USE`
  sources run in declaration order.

### `.OBJDIR`, `.CURDIR`, `.PARSEDIR`

- `.CURDIR` is the config-tree root (where the user's Makefile lives)
  and remains the base for make's relative include/source lookup.
- `.OBJDIR` is `${.CURDIR}/obj.${USER}`. After the `.OBJDIR:` special
  target, **recipes run with that directory as their cwd**. A recipe
  that creates a relative file writes it into the object dir; use
  `${.CURDIR}/...` or an absolute path in shell commands.
- `.PARSEDIR` is the directory of the makefile currently being parsed;
  `ZEST` is set from it inside `_zest.mk`.

### `:U` and empty target-local variables

`${VAR:Ufallback}` applies only when `VAR` is undefined. A target-local
assignment such as `${THIS}: INST_MODE=` defines it as empty, so `:U`
does not kick in. That is why the code writes

```make
${THIS}: INST_MODE=${ATTR} ${FILE_MODE}
...
${INSTALL} ${INST_MODE:[1]:@x@-m ${x}@}
```

and picks the first word instead of using `:U`. Do not "simplify" this
back to `${INST_MODE:U${FILE_MODE}}` unless you also stop emitting the
empty local assignment.

The helpers add a `:U` fallback *inside* the macro:

```make
${INSTALL} ${INST_MODE:[1]:U${FILE_MODE}:@x@-m ${x}@} ...
```

This helps only for targets where `INST_MODE` is **undefined** (manual
`_text_file` rules that do not set it). It does **not** help for
`${THIS}: INST_MODE=` (defined-but-empty), where `${INST_MODE:[1]}` is
empty and `:U` is skipped. Verified:

| case | `${INST_MODE:[1]:U644}` |
|---|---|
| variable never defined | `644` |
| `INST_MODE=<attr> 644` (from `_copy_files.mk`) | `<attr>` if present, else `644` |
| target-local `INST_MODE=` | `` (empty → `install -m ''` fails) |

Also note that the value in a target-local assignment is expanded when
the dependency line is read (the rest of the line already has globals
expanded, which is why `:=` is documented as redundant), and the stored
value is then used when the target's commands are expanded — including
commands inherited from `.USE`/`.USEBEFORE` sources.

### `install(1)` behaviours relied on

- `-C` : copy only if content differs; don't touch mtime otherwise.
- `-U` : unprivileged; no chown, no flags, no directory chmod.
- `-lsa` : create an absolute symlink (used by `_link_file`).
- `-d` : create directories, including missing parents.
- Default mode is `0755`; always pass `-m` if mode matters.

## Known issues and design traps

Current checkout: `79a51e66` (2026-11-17). Line numbers will drift;
re-read the files. These are behaviours to design around, not a bug list.

1. **Empty leading attribute fields are lost.**
   `foo.conf=:root:wheel` becomes words `root wheel`; `root` is taken as
   the mode and `wheel` as the owner. There is no placeholder for an
   omitted leading field, so make the mode explicit whenever owner/group
   are used, or introduce a sentinel. Trailing empties (`700:root:` and
   `700::wheel`) work.
2. **Directory attrs are re-applied every run.** `_make_dir` inherits
   the forced `LAST_UPDATE`, so every declared directory's rule runs on
   each invocation and `install -d -m/-o/-g` (re-)applies the attrs. A
   declared directory converges to its `NEW_DIRS` spec — but only where
   it can actually chmod/chown (see "Directory attrs need privilege").
3. **`install -d` creates missing parents.** Creating `/a/b` can
   pre-create `/a` with default attrs, but `install -d` does not chmod an
   *existing* parent and the declared `/a`'s rule is forced and runs in
   the same invocation, so the end state is correct. Only *undeclared*
   intermediate directories keep default attrs — declare them in
   `NEW_DIRS` to control them.
4. **Targeted runs and directories.** `make <module>` ignores `.MAIN`,
   and `.ORDER` does not add nodes, so only directories reachable from
   that module (or its service target) are built. Put them on the module
   target, never on a *file* rule. See
   [Directories as dependencies](#directories-as-dependencies-the-big-trap).
5. **`INST_MODE=` (empty) defeats `:U`.** `${VAR:U...}` does nothing
   when `VAR` is defined-but-empty. `_copy_files.mk` emits
   `INST_MODE=<attr> ${FILE_MODE}` precisely so the first word is a real
   value; do not "simplify" it to an empty local assignment plus `:U`.
6. **Directory attrs need privilege.** The directory rule is forced, but
   on non-root FreeBSD runs `INSTALL` includes `-U`, which skips chown
   and directory chmod (file chmod still happens). Directory
   mode/owner/group therefore converge only for root (or on Linux, which
   does not add `-U`).
7. **Service `_`-macros run after the marker.** The marker target runs
   its plain `service ...` commands first, then `_mark_command`'s
   `touch $@`, then the `_`-macros. A failed plain command is retried; a
   failed `_`-macro leaves a fresh marker and is not retried until
   something else changes.
8. **`example/` is stale.** `example/Mk/user.mk` still makes directories
   prerequisites of files and uses `dir: _make_dir` directly;
   `example/Makefile` intentionally errors. Historical illustration
   only.
9. **Last-update forcing and directory mtimes.** `LAST_UPDATE` makes
   every managed file's recipe run each time; `install -C` then leaves
   unchanged files' mtimes alone. Never add a directory as a *file*
   prerequisite: a directory's mtime changes whenever entries are
   added/removed, and `install -C` cannot "catch up", so the file looks
   permanently out of date to any timestamp consumer.

## Testing and debugging

There is no test suite in this repository. The practical workflow is:

1. **Dry-run first.** `make -n` shows the fully expanded recipes,
   including the exact `install` command. Remember that `!=` shell
   commands still execute during `-n`.
2. **Inspect variables after parsing.**
   `make -V .CURDIR -V .OBJDIR -V TARGETS -V TARGET_DIRS -V NEW_DIRS`.
   `make -V .TARGETS` shows bmake's explicit goals. `-V` still parses
   the whole tree, so a missing source file can make it fail. Confirm
   that `TARGET_DIRS` lists every declared directory before blaming the
   directory rules.
3. **Sandbox.** Copy the engine and a tiny config tree under
   `/tmp/opencode/...`; do not experiment in the real tree. Minimal
   fixture:

   ```
   Makefile: .include "/path/to/zest/_zest.mk"
   Mk/testmod.mk:
       T_ETC:= ${.CURDIR}/dest
       NEW_DIRS+= ${T_ETC}
       FILES:= foo.conf
       DEST:= ${T_ETC}
       MOD:= testmod
       .include "${ZEST}/_copy_files.mk"
       testmod: ${T_ETC} ${T_ETC}/foo.conf
   testmod/foo.conf: <content>
   ```

   Then `make testmod` twice and inspect with
   `stat -f '%N %Sp %Su:%Sg %m' dest dest/foo.conf`.
4. **Explicit module target** exercises the targeted path without the
   root `_default.mk` / host / tag machinery. It also loads a module even
   if it is not listed in `_default.mk`. Root config is only loaded when
   `USER` is `root` **and** no explicit target is given.
5. **Root-path testing.** `make -n USER=root ...` is safe for inspecting
   expansion. A real run with `USER=root` as a non-root user omits `-U`
   (because `USER` looks like root) and will fail on chown; use a
   sandbox path and only when you really mean it.
6. **Graph debugging.** `make -dA` produces a lot; filter for
   `not built`, `Graph cycles`, `DONECYCLE`, `Order`, `.ORDER`. Useful
   when a target is skipped or `.ORDER` seems ineffective.
7. **Read bmake source** if something is surprising:
   `/usr/src/contrib/bmake` (scheduler in `make.c`, parsing and `.ORDER`
   in `parse.c`, modifiers in `var.c`, `.for` in `for.c`). The man page
   (`man 1 make`) documents the `.ORDER`/dependency-loop warning
   verbatim.

## Adding or changing a module

1. Create `<module>.mk` in Zest (or `Mk/<module>.mk` to override
   locally). The module target name must equal the module name; the
   loader makes it `.PHONY`.
2. Put cross-module declarations in `<module>.var.mk`: `SERVICES+=`,
   `SUBDIR+= service` (if you reference `SERVICE_*`), shared file lists
   such as `NEWSYSLOG_FILES+=`, etc.
3. Declare every destination directory with `NEW_DIRS+=`. Plain `make`
   builds all of them; targeted `make <module>` only builds the ones the
   module depends on, so put them on the module target. Never put a
   directory on a *file* rule; `_copy_files.mk` only adds `.ORDER`.
4. Wire the graph top-down:
   - `module: ${SERVICE_X} ${DIRS}`
   - `${SERVICE_X}: ${INSTALLED_FILES}`
   - per file: `<dst>: <src> _text_file` plus `.ORDER: <dir> <dst>`
   - or use `_copy_files.mk` for the last two.
5. Use `?=` for user-tunable paths (`NGINX_ETC?= ...`) and `+=` for
   accumulating lists. Remember `+=` is deferred: inside `.for` loops
   accumulate with `X:= ${X} ${loop_var}` instead.
6. Add obsolete paths to `STALE_FILES`/`STALE_DIRS` and depend on
   `clean_stale` if the module should remove them.
7. Prefer real files/markers over `.PHONY` for anything that should
   restart a service only once; `.PHONY` defeats timestamp comparison.
8. Keep recipes POSIX `sh`; use `${.CURDIR}` for config-tree paths
   because recipes run in `.OBJDIR`.
9. If a command is a `.USE` macro, it runs *after* the target's own
   commands (`.USEBEFORE` = before). Do not use `.USE` expecting target
   ordering.
10. Run `make -n <module>` against a fixture, then twice for real to
    confirm idempotence and no unexpected restarts.

## Style notes

- Recipes are tab-indented; `.for`/`.if` bodies use a tab after the dot
  directive (`.	if`, `.	for`).
- Comments use `#`; command output is prefixed with `#` by convention
  (`echo "# new file ..."`), because `.SILENT` suppresses command echo.
- Keep `.ORDER` lines immediately after the rule they belong to.
- Avoid GNU make constructs and shell loops where a bmake target will do.
- The engine assumes bmake; do not try to make it portable to GNU make.
