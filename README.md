# Zest config management tool
Zest is a simple config management tool written in BSD make. It follows the UNIX philosophy with no templating engine, minimal dependencies, and straightforward configuration management.

## Why Zest?
After working with SaltStack, Ansible, and Puppet, I found them overly complex with unnecessary server/client architectures, UI layers, and steep learning curves. Zest takes a different approach:
- **Minimal overhead**: No servers, agents, or complex infrastructure required
- **Fast execution**: Built on BSD make, designed for speed (see benchmarks below)
- **No templating**: Plain configuration files — what you see is what you get
- **Flexible distribution**: You decide how to distribute configs, store them, and control execution
- **Easy to extend**: Simple modular design based on familiar Makefile syntax
- **UNIX-way**: Leverage existing tools and keep it simple

## Performance

It follows the UNIX philosophy with no templating engine, minimal dependencies, and straightforward configuration management.

```
# time make
0.000u 0.079s 0:00.01 700.0%    43+40k 0+0io 0pf+0w
```

What happend here: zest checks that every file is present and matches the source in your config tree. This is exactly what `make` was designed to do.

## Installation

1. Clone or download Zest to a known location (e.g., `/usr/local/share/zest`)
1. To generate a root Makefile for your config tree run this:
```
make -C /usr/local/share/zest > Makefile
```

## Quick start
Take a look at `example`, you can copy whole directories from there and replace contents with your config files.

### Top level directory
A number of files can be here:
- **_default.mk** — lists modules enabled under `root` user
```
# _default.mk
SUBDIR+= sshd nginx postgres
```
- **_config.mk** — allow to override local variables from base `_config.mk` when needed
- **_hostname.mk** — extra `root` modules to enable for specific host
```
# _web01.mk
SUBDIR+= nginx newsyslog
```
- **Mk** — place for your module overrides or new local modules

### Applying configuration
```
make
```
If you need to manually test one single module you can target that module or any list of modules:
```
make nginx newsyslog
```

## Module types
### Standard modules
Standard modules manage files within their own directory. Examples:
- `sshd` - SSH daemon configuration
- `postgres` - PostgreSQL configuration
- `postfix` - Postfix mail server configuration
- `nginx` - Nginx web server configuration

### Cross-Dependent modules
Some modules operate on files from other services and are configured through global module variables (`*.var.mk`):
- `syslog` - Centralized logging configuration
- `newsyslog` - Log rotation configuration
- `command` - Meta-module for executing commands, thin wrapper to ensure service is restarted only once if any relevant file was changed

**Important**: For a service to have its logs configured properly, both the service module (e.g., `nginx`) and the log rotation module (e.g., `newsyslog`) must be activated.

Example - to enable `nginx` log rotation:
```
# _default.mk
SUBDIR+= nginx newsyslog
```

## Available Modules
Zest includes pre-built modules for common services:

|Module|Purpose|
|---|---|
|user|User home directory configurations (.bashrc, .profile, etc.)|
|sshd|SSH daemon configuration|
|nginx|Nginx web server|
|postgres|PostgreSQL database|
|postfix|Postfix mail server|
|cyrus|Cyrus IMAP server|
|named|BIND DNS server|
|dhcpd|ISC DHCP server|
|dhcpcd|DHCPC client daemon|
|syslog|System logging configuration|
|newsyslog|Log rotation|
|cron|Cron jobs|
|opendkim|OpenDKIM mail signing|
|node_exporter|Prometheus node exporter|
|prometheus|Prometheus monitoring|
|spamd|SpamD configuration|
|etc|General /etc configuration files|
|command|Execute custom commands during deployment|

## Selectors
Currently, Zest supports one primary selector:
```
${MYHOST} - Expands to hostname -s (short hostname)
```
This allows host-specific configuration. Future versions may support additional selectors for more complex deployments.

## Extending Zest
Adding new modules is straightforward:
1. Create a mymodule.mk file in the Zest directory with your module logic
1. Create a mymodule.var.mk file to hint cross-dependent modules on your requirements
1. Enable the module in _default.mk or _hostname.mk

Take a look at `cyrus.mk` for good starting example:
```
# cyrus.mk
CYRUS_ETC=/usr/local/etc

CYRUS_FILES:=   imapd.conf cyrus.conf

cyrus: ${IMAPD_COMMAND}

${IMAPD_COMMAND}: \
        ${CYRUS_FILES:%=${CYRUS_ETC}/%}
        service imapd restart

FILES:= ${CYRUS_FILES}
DEST:=  ${CYRUS_ETC}
.include "${ZEST}/_copy_files.mk"
```

What happens here:
1. We define directory and files that should be placed there.
2. `cyrus` module target (name should match module name) actually depends on service update command
3. Service update command depends on files, variable macro is used to add correct prefix to them
4. We are calling a separate make macros file, it receives a list of files and destination, or just a list full path to files, checks module directory for those files, making preference for custom files under `hostname` subdirectory, and generates all required rules.

`${MODULE_COMMAND}` target should actually be defined before processing the module, `module.var.mk` file is a place to define commands needed.

## Limitations and Future Improvements
- **Single selector**: Currently limited to ${MYHOST}. Future versions may support multiple selectors (e.g., role-based, environment-based)
- **Documentation**: Module-specific documentation is still being developed
