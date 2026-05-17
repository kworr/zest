Zest is a simple config management tool written in BSD make. I guess my main reasons for it was - to be fast, no templating, contained configuration, parallel and easy to expand.

# About
I worked a lot with SaltStack, I saw Ansible and Puppet. And sincerely, I don't see a UNIX way in it. Any of them is a huge complex with server, clients, UI, modules. You also need to learn a lot about how they actually work: syntax, structure, how to propagate, how to force stuff, how to update. It becomes a separate issue for your stack. But what if you are not happy about something? Can you change how they work? Ditch Git? Want to push changes to nodes, so they would not have any access to your repos? Want it work fast? Want it actually be static, without yearly update process just for the sake of it working? First that started as a way to manage some configs fast, automatically lay them out on different hosts they way they need to be. Then it became Zest. Why Zest? You don't need as much Zest as Salt.

Zest doesn't make any assumptions about how you distribute configs, how you store them, or how you want to control execution. Zest only takes care of placing correct files in correct places and making sure services are working with updated configuration.

How fast it really is? Well…

```
# time make
0.000u 0.079s 0:00.01 700.0%    43+40k 0+0io 0pf+0w
```

It didn't do anything but checked any single file is present and is same as in config tree. For `make` this stuff is easy, it was made to do exactly that.

# Usage
Just run `make`. The output will serve a root `Makefile` for your config tree. And in your config tree just organize files according to modules - and check which modules whould be active for which host. There's even an example directory that will NOT work right away, just to make sure it wouldn't replace any files on your system.

By default the only module active is `user`. For `root` you can enable more modules via `_default.mk` in config tree root, plus you can add some modules for specific hosts via `_hostname.mk` in config tree root. Anyways, you can manually run any list of modules by directly specifying them: `make DIR1 DIR2`.

Actually not all modules are looking only into they own directory and operate on files in the same dir. Exceptions are modules that are configured through global module variables (`*.var.mk`):
- syslog;
- newsyslog;
- command (this one is meta and part of zest).

So for a syslog config for some service to be installed both that service module and syslog module should be activated.

For more details look inside source files. Not all of them have good comments, but I'll be working on that.

# Things that would change eventually
It's not like I already want to break something, but there's stuff I don't like, for example I have only one selector: `${MYHOST}` which equals `hostname -s`. This is pretty much fine, but for bigger setups you'd want to target bigger groups of hosts. I'll see how to do it when I will be there.
