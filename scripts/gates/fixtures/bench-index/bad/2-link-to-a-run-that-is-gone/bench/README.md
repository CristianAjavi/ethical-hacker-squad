# The evaluation bench

[alpha](runs/alpha/) is here.

The reference below is deliberately NOT markdown link syntax. The checker under
test matches a `runs/<name>` path anywhere in the text, and writing it as a link
would also make this fixture a genuinely broken link in a tracked .md file,
which `gate-plugin-integrity.sh` forbids across the whole repository. Two gates
would then disagree about the same file, and the fixture would be the one that
is wrong: it needs a REFERENCE to a run that is gone, not a link to one.

Superseded and removed: runs/ghost/
