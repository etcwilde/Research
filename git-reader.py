#!/usr/bin/env python3
# Evan Wilde (c) 2018

# General
import argparse
import asyncio
import os
import sys
import re
from datetime import datetime

# database support
import sqlite3

# interface with git
import subprocess

###########
#  Regex  #
###########

commit_line_expr_pat = r"^([0-9a-f]{40})\s"
commit_expr = re.compile(commit_line_expr_pat)
file_line_expr_pat = r"^(-|[0-9]*)\s+(-|[0-9]*)\s+(.*)"
file_line_expr = re.compile(file_line_expr_pat)

######################
#  Helper Functions  #
######################


def decodeLine(bline):
    try:
        return bline.decode('utf-8').rstrip()
    except UnicodeDecodeError:
        return bline.decode('latin1').rstrip()


class absolutePathFormatArgumentAction(argparse.Action):
    """pathFormatArgumentAction

    Extend input filepaths to use absolute naming
    """
    def __call__(self, parser, args, values, option_string=None):
        setattr(args, self.dest, os.path.abspath(values))


########################
#  Database functions  #
########################

# commits
# cid | created_at | files_touched | lines_added | lines_removed
# ----+------------+---------------+-------------+---------------

# files
# cid | filename | lines_added | lines_removed
# ----+----------+-------------+---------------

# We want to store the number of files, the number of changes in the
# patch, the date
def createTables(dbcon):
    query = """
DROP TABLE IF EXISTS commits;
DROP TABLE IF EXISTS files;

CREATE TABLE commits
(
    cid CHARACTER (40) PRIMARY KEY, -- commit hash
    created_at DATE, -- When the commit was created
    files_touched INTEGER, -- number of files touched
    lines_added INTEGER,  -- number of lines added
    lines_removed INTEGER -- number of lines removed
);

CREATE TABLE files
(
    cid CHARACTER (40), -- Commit hash
    filename TEXT, -- Name of the file
    added INTEGER, -- number of lines added to a file
    removed INTEGER, -- number of lines removed from a file
    PRIMARY KEY(cid, filename)
);
"""
    dbcon.executescript(query)
    dbcon.commit()


async def insertCommitsRows(dbcon, rows):
    query = """
INSERT INTO commits (cid, created_at, files_touched, lines_added, lines_removed) VALUES
(?, ?, ?, ?, ?);
"""
    dbcon.executemany(query, rows)


async def insertFilesRows(dbcon, rows):
    query = """
INSERT INTO files (cid, filename, added, removed) VALUES (?, ?, ?, ?);
"""
    dbcon.executemany(query, rows)


##########################
#  Repository functions  #
##########################

def queryGit(repodir, gitargs=["log"]):
    """
    Query the git repository

    :repodir: Repository directory
    :gitargs: Arguments to pass to git
    :returns: generator of commit data
    """

    if not os.path.isdir(repodir):
        raise FileNotFoundError(f"Repository directory {repodir} does not exist")

    args = ['git', '-C', repodir] + gitargs

    git_ret = subprocess.run(args,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    if git_ret.returncode:
        print("Command failed")
        print(git_ret.stderr.split(b'\n'))
    return (decodeLine(line) for line in git_ret.stdout.split(b'\n'))


async def getCommitFiles(repodir, cid):
    """
    Get the list of files with information about the number of lines
    added to and removed from each.

    [(fname, lines added, lines removed),...]

    :repodir: Repository directory
    :cid:

    :returns: list of tuples
    """

    args = ['show', cid, '--numstat', '--format=%H %ad']
    lines = queryGit(repodir, args)

    items = []
    for line in lines:
        m = file_line_expr.match(line)
        if m:
            added, removed, fname = m.groups()
            try:
                added = int(added) if added[0] != '-' else 0
                removed = int(removed) if removed[0] != '-' else 0
            except ValueError:
                print(f"Error: Failed to read {cid}: ++ {added}, -- {removed}", file=sys.stderr)
            items.append((fname, added, removed))
    return items


async def getCommitDates(repodir):
    """
    Get the date that the commit was created

    :repodir: Repository directory

    :returns: datetime object with the author date
    """
    for line in queryGit(repodir, ['log', '--no-merges', '--format=%H %ad']):
        try:
            if not line:
                continue
            yield (line[:40], datetime.strptime(line[41:].strip(), '%c %z'))
        except ValueError:
            print(f"Error: failed to parse date {line[:40]}: {line[41:]}")


def getRepoData(repodir):
    """
    Collects all of the commits from the repository

    :repodir: repository directory
    :returns: generator of commits
    """

    args = ['log', '--no-merges',
            '--format=%H %ad',
            '--numstat']

    print("Getting repo data")

    return queryGit(repodir, args)


##########
#  Main  #
##########


async def async_main(repodir, output, dbcon):

    dates = getCommitDates(repodir)

    async for cid, date in dates:
        files = await getCommitFiles(repodir, cid)
        total_added = 0
        total_removed = 0
        await insertFilesRows(dbcon, ((cid, *data) for data in files))
        for _, added, removed in files:
            total_added += added
            total_removed += removed
        total_files = len(files)
        await insertCommitsRows(dbcon, [(cid, date, total_files, total_added, total_removed)])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=str, help="Input git repository directory", action=absolutePathFormatArgumentAction)
    ap.add_argument("-o", "--out", type=str, help="Output filename",
                    default="output.db",
                    action=absolutePathFormatArgumentAction)
    args = ap.parse_args()
    # Ensure that the database is up before we do stuff
    with sqlite3.connect(args.out) as dbcon:
        # Build the tables for the db
        createTables(dbcon)
        loop = asyncio.get_event_loop()
        loop.run_until_complete(async_main(args.input, args.out, dbcon))
        loop.close()


if __name__ == "__main__":
    main()
