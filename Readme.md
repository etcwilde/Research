# Commit Profiles

This repository contains the scripts and parts of the initial write-up
of what I was seeing as I was doing the experiments. I would include the
databases I worked with, but they are unfortunately too big to be
uploaded to GitHub. 171Mb compressed, but GitHub only allows files up
to 100Mb.

My Linux database is based on commit
7876320f88802b22d4e2daf7eb027dd14175a0f8, and the LLVM database is based
on commit a2434c2657e24263fab58e864aea7fb0049daefd.

To generate a database, just run the `git-reader.py` script.

```
Usage: git-reader.py [-o output.db] input
```

The input is the path to the root of a git repository. That git
repository should be at the latest commit you want included. It will
include everything that has been integrated back into the project.

The output is a sqlite database containing two tables:

| Commits       |                |                             |
|---------------+----------------+-----------------------------|
| cid           | CHARACTER (40) | Commit hash                 |
| created_at    | DATE           | When the commit was created |
| files_touched | INTEGER        | Number of files modified    |
| lines_added   | INTEGER        | Number of lines added       |
| lines_removed | INTEGER        | Number of lines removed     |
|               |                |                             |
| PRIMARY KEY   | cid            |                             |


| Files       |                 |                                                      |
|-------------+-----------------+------------------------------------------------------|
| cid         | CHARACTER (40)  | Commit hash                                          |
| filename    | TEXT            | Name of the file                                     |
| added       | INTEGER         | Number of lines added to the file in this commit     |
| removed     | INTEGER         | Number of lines removed from the file in this commit |
|             |                 |                                                      |
| PRIMARY KEY | (cid, filename) |                                                      |
